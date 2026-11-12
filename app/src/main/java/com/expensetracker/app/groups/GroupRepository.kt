package com.expensetracker.app.groups

import android.app.Activity
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import com.expensetracker.app.BuildConfig
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.data.ExpenseDao
import com.expensetracker.app.data.SettingsRepository
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import java.security.MessageDigest
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.TemporalAdjusters
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

enum class Period(val key: String) { WEEK("week"), MONTH("month") }

data class GroupSummary(val id: String, val name: String, val code: String, val ownerId: String?, val members: Int, val requests: Int)
data class JoinRequest(val groupId: String, val userId: String, val alias: String)
data class Member(
    val userId: String,
    val alias: String,
    val joinedAt: Instant,
    val updatedAt: Instant?,
    /** Category name to amount for the shown period, largest first. */
    // Budget limits (the budget_limits table) show here once personal budgets exist (map #33).
    val categories: List<Pair<String, BigDecimal>>
) {
    val total: BigDecimal get() = categories.fold(BigDecimal.ZERO) { a, (_, v) -> a + v }
}
data class GroupDetail(val group: GroupSummary, val members: List<Member>, val requests: List<JoinRequest>)

data class GroupsState(
    val online: Boolean = true,
    val userId: String? = null,
    val alias: String = "",
    val groups: List<GroupSummary> = emptyList(),
    val requests: List<JoinRequest> = emptyList(),
    val removedFrom: List<Pair<Long, String>> = emptyList(),
    val loading: Boolean = false,
    val message: String? = null
)

/** Groups: sign-in, actions, reads and the shared totals sync. Spec: docs/superpowers/specs/2026-11-12-group-tracker-design.md */
@Singleton
class GroupRepository @Inject constructor(
    private val supabase: SupabaseClient,
    private val settings: SettingsRepository,
    private val expenseDao: ExpenseDao
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val _state = MutableStateFlow(GroupsState())
    val state: StateFlow<GroupsState> = _state.asStateFlow()

    /** Starts the sync after payment changes. Called once from the app's first screen. */
    @OptIn(FlowPreview::class)
    fun start() {
        if (started) return
        started = true
        scope.launch {
            settings.onlineFeatures.collect { on -> _state.update { it.copy(online = on) }; if (on) refresh(); if (on) syncTotals() }
        }
        // ponytail: syncs while the app process lives (app open, or the listener service). Payments saved while
        // offline go up at the next change or app start; WorkManager would retry in the background.
        scope.launch { expenseDao.observeAllActive().drop(1).debounce(5_000).collect { syncTotals() } }
    }
    private var started = false

    private suspend fun allowed() = settings.onlineFeatures.first()

    // ---- Sign-in ----

    /** Google sign-in, then links the account to this phone's invite code. Returns an error message or null. */
    suspend fun signIn(activity: Activity): String? {
        if (!allowed()) return "Turn on online features first."
        val rawNonce = UUID.randomUUID().toString()
        val hashed = MessageDigest.getInstance("SHA-256").digest(rawNonce.toByteArray()).joinToString("") { "%02x".format(it) }
        // The button flow: Google's own sign-in screen. (The bottom-sheet chooser of GetGoogleIdOption is
        // killed at start on the owner's MIUI phone.)
        val option = GetSignInWithGoogleOption.Builder(BuildConfig.GOOGLE_WEB_CLIENT_ID)
            .setNonce(hashed)
            .build()
        val google = try {
            val cred = CredentialManager.create(activity)
                .getCredential(activity, GetCredentialRequest.Builder().addCredentialOption(option).build()).credential
            if (cred !is CustomCredential || cred.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                return "Google sign-in did not return an account."
            }
            GoogleIdTokenCredential.createFrom(cred.data)
        } catch (e: GetCredentialCancellationException) {
            return null
        } catch (e: GetCredentialException) {
            return "Google sign-in failed. Add a Google account to this phone and try again."
        }
        return try {
            supabase.signInWithGoogle(google.idToken, rawNonce)
            val linked = supabase.rpc("link_account", JSONObject()
                .put("p_device_token", settings.deviceToken.first())
                .put("p_alias", google.givenName ?: google.displayName ?: "Friend")).trim('"')
            if (linked != "ok") {
                supabase.signOut()
                return "Groups need online access. Enter your invite code in Settings first."
            }
            refresh()
            null
        } catch (e: SupabaseException) {
            supabase.signOut()
            if (e.code == 0) "Could not reach Koban's server. Check the internet connection." else "Sign-in failed. Try again."
        }
    }

    suspend fun signOut() {
        supabase.signOut()
        _state.update { GroupsState(online = it.online) }
    }

    suspend fun deleteAccount(): String? = act { supabase.deleteAccount(); _state.update { GroupsState(online = it.online) }; null }

    // ---- Reads ----

    suspend fun refresh() {
        val uid = supabase.userId()
        if (uid == null || !allowed()) { _state.update { it.copy(userId = null, groups = emptyList()) }; return }
        _state.update { it.copy(userId = uid, loading = true) }
        try {
            val alias = supabase.select("profiles?user_id=eq.$uid&select=alias").optJSONObject(0)?.optString("alias").orEmpty()
            val reqs = supabase.select("join_requests?select=group_id,user_id,profiles(alias)").objects()
                .filter { it.getString("user_id") != uid }
                .map { JoinRequest(it.getString("group_id"), it.getString("user_id"), it.optJSONObject("profiles")?.optString("alias") ?: "?") }
            val groups = supabase.select("groups?select=id,name,code,owner_id,group_members(user_id)&order=created_at").objects().map { g ->
                GroupSummary(
                    g.getString("id"), g.getString("name"), g.getString("code"), g.optString("owner_id").ifBlank { null },
                    g.optJSONArray("group_members")?.length() ?: 0,
                    reqs.count { it.groupId == g.getString("id") }
                )
            }
            val removed = supabase.select("removed_notices?select=id,group_name").objects().map { it.getLong("id") to it.getString("group_name") }
            _state.update { it.copy(alias = alias, groups = groups, requests = reqs, removedFrom = removed, loading = false, message = null) }
        } catch (e: SupabaseException) {
            _state.update { it.copy(loading = false, userId = if (e.code == 401) null else uid, message = errorText(e)) }
        }
    }

    /** One group's members with their totals and limits for the period that holds today. */
    suspend fun loadGroup(groupId: String, period: Period, currency: String): GroupDetail? {
        if (!allowed()) return null
        val summary = _state.value.groups.firstOrNull { it.id == groupId } ?: return null
        val start = periodStart(LocalDate.now(ZONE), period)
        val rows = supabase.select("group_members?group_id=eq.$groupId&select=user_id,joined_at,profiles(alias,totals_updated_at)").objects()
        val ids = rows.joinToString(",") { it.getString("user_id") }
        val totals = supabase.select("shared_totals?user_id=in.($ids)&currency=eq.$currency&period=eq.${period.key}&period_start=eq.$start&select=user_id,category,amount").objects()
        val members = rows.map { r ->
            val uid = r.getString("user_id")
            val p = r.optJSONObject("profiles")
            Member(
                userId = uid,
                alias = p?.optString("alias") ?: "?",
                joinedAt = Instant.parse(r.getString("joined_at").normalizeTs()),
                updatedAt = p?.optString("totals_updated_at")?.takeIf { it.isNotBlank() && it != "null" }?.let { Instant.parse(it.normalizeTs()) },
                categories = totals.filter { it.getString("user_id") == uid }
                    .map { it.getString("category") to BigDecimal(it.getString("amount")) }.sortedByDescending { it.second }
            )
        }.sortedByDescending { it.total }
        return GroupDetail(summary, members, _state.value.requests.filter { it.groupId == groupId })
    }

    // ---- Actions: each returns an error message, or null when it worked ----

    suspend fun makeGroup(name: String): String? = act {
        val r = JSONObject(supabase.rpc("make_group", JSONObject().put("p_name", name)))
        when (r.getString("status")) {
            "ok" -> null
            "too_many_groups" -> "You are in 5 groups, the most allowed."
            "bad_name" -> "Give the group a name of 1 to 40 characters."
            else -> "Groups need online access. Enter your invite code in Settings."
        }
    }

    suspend fun askToJoin(code: String): String? = act {
        when (supabase.rpc("ask_to_join", JSONObject().put("p_code", code)).trim('"')) {
            "ok" -> null
            "unknown" -> "No group has this code. Check it with the person who sent it."
            "already" -> "You are already in this group."
            "full" -> "This group has 10 members, the most allowed."
            "too_many_groups" -> "You are in 5 groups, the most allowed."
            "too_many_requests" -> "You have 5 open requests. Wait for an answer first."
            else -> "Groups need online access. Enter your invite code in Settings."
        }
    }

    suspend fun answer(req: JoinRequest, approve: Boolean): String? = act {
        when (supabase.rpc("answer_request", JSONObject().put("p_group", req.groupId).put("p_user", req.userId).put("p_approve", approve)).trim('"')) {
            "ok", "declined" -> null
            "expired" -> "This request is older than 7 days. Ask ${req.alias} to send it again."
            "full" -> "The group has 10 members, the most allowed."
            "too_many_groups" -> "${req.alias} is in 5 groups, the most allowed."
            else -> "Only the group owner can answer requests."
        }
    }

    suspend fun leave(groupId: String): String? = simple("leave_group", JSONObject().put("p_group", groupId))
    suspend fun remove(groupId: String, userId: String): String? = simple("remove_member", JSONObject().put("p_group", groupId).put("p_user", userId))
    suspend fun handOver(groupId: String, userId: String): String? = simple("hand_over", JSONObject().put("p_group", groupId).put("p_user", userId))
    suspend fun rename(groupId: String, name: String): String? = simple("rename_group", JSONObject().put("p_group", groupId).put("p_name", name))
    suspend fun newCode(groupId: String): String? = act {
        val r = supabase.rpc("new_group_code", JSONObject().put("p_group", groupId)).trim('"')
        if (r.startsWith("GRP-")) null else "Only the group owner can make a new code."
    }

    suspend fun setAlias(alias: String): String? = act {
        val uid = supabase.userId() ?: return@act "Sign in first."
        supabase.patch("profiles?user_id=eq.$uid", JSONObject().put("alias", alias.trim().take(30)))
        null
    }

    suspend fun dismissRemoved(id: Long) {
        runCatching { supabase.delete("removed_notices?id=eq.$id") }
        _state.update { s -> s.copy(removedFrom = s.removedFrom.filterNot { it.first == id }) }
    }

    private suspend fun simple(fn: String, args: JSONObject): String? = act {
        when (val r = supabase.rpc(fn, args).trim('"')) {
            "ok" -> null
            "bad_name" -> "Give the group a name of 1 to 40 characters."
            "use_leave" -> "Use Leave group to leave."
            else -> if (r == "not_owner") "Only the group owner can do this." else "This person is not in the group."
        }
    }

    /** Runs a server action, then refreshes. Network and session errors become one message. */
    private suspend fun act(block: suspend () -> String?): String? {
        if (!allowed()) return "Turn on online features first."
        return try {
            val msg = block()
            refresh()
            syncTotals()
            msg
        } catch (e: SupabaseException) {
            errorText(e)
        }
    }

    private fun errorText(e: SupabaseException) = when (e.code) {
        0 -> "Could not reach Koban's server. Check the internet connection."
        401 -> "Sign in again."
        else -> "Koban's server had a problem. Try again later."
    }

    // ---- Shared totals ----

    /**
     * Sends this person's shared totals: every week and month from the earliest group join until now, for each account.
     * Rows are replaced as a whole, so an edit to an earlier period or a moved category shows correctly.
     */
    suspend fun syncTotals() {
        if (!allowed()) return
        val uid = supabase.userId() ?: return
        try {
            val joins = supabase.select("group_members?user_id=eq.$uid&select=joined_at").objects()
            if (joins.isEmpty()) return
            val since = joins.minOf { Instant.parse(it.getString("joined_at").normalizeTs()) }.atZone(ZONE).toLocalDate()
            val today = LocalDate.now(ZONE)
            val rows = JSONArray()
            for (currency in listOf("MYR", "IDR")) for (period in Period.entries) {
                var start = periodStart(since, period)
                while (!start.isAfter(today)) {
                    val next = if (period == Period.WEEK) start.plusWeeks(1) else start.plusMonths(1)
                    expenseDao.groupTotals(millis(start), millis(next), currency, DefaultCategories.UNCATEGORIZED_NAME).forEach {
                        rows.put(JSONObject().put("user_id", uid).put("currency", currency).put("period", period.key)
                            .put("period_start", start.toString()).put("category", it.category.take(40))
                            .put("amount", it.total.setScale(2, java.math.RoundingMode.HALF_UP).toPlainString()))
                    }
                    start = next
                }
            }
            supabase.delete("shared_totals?user_id=eq.$uid")
            if (rows.length() > 0) supabase.insert("shared_totals", rows)
            supabase.patch("profiles?user_id=eq.$uid", JSONObject().put("totals_updated_at", Instant.now().toString()))
        } catch (e: SupabaseException) {
            // Offline or signed out: the next change or app start tries again.
        }
    }

    companion object {
        val ZONE: ZoneId = ZoneId.of("Asia/Kuala_Lumpur")

        fun periodStart(day: LocalDate, period: Period): LocalDate =
            if (period == Period.WEEK) day.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)) else day.withDayOfMonth(1)

        fun daysLeft(period: Period, today: LocalDate = LocalDate.now(ZONE)): Int {
            val start = periodStart(today, period)
            val next = if (period == Period.WEEK) start.plusWeeks(1) else start.plusMonths(1)
            return (next.toEpochDay() - today.toEpochDay()).toInt()
        }

        private fun millis(d: LocalDate) = d.atStartOfDay(ZONE).toInstant().toEpochMilli()

        /** PostgREST sends "2026-11-12T05:59:05.867657+00:00"; Instant.parse needs an offset it understands. */
        private fun String.normalizeTs(): String = java.time.OffsetDateTime.parse(this).toInstant().toString()

        private fun JSONArray.objects(): List<JSONObject> = (0 until length()).map { getJSONObject(it) }
    }
}
