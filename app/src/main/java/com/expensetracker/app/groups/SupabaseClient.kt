package com.expensetracker.app.groups

import com.expensetracker.app.BuildConfig
import com.expensetracker.app.data.SettingsRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton

/** A failed call to Supabase. [code] is the HTTP status, or 0 for no connection. */
class SupabaseException(val code: Int, message: String) : IOException(message)

/**
 * Sign-in and data calls to Koban's Supabase project over plain HTTP (GoTrue and PostgREST).
 * ponytail: a small OkHttp client instead of supabase-kt, which needs a newer Kotlin than this project.
 */
@Singleton
class SupabaseClient @Inject constructor(
    baseClient: OkHttpClient,
    private val settings: SettingsRepository
) {
    private val client = baseClient
    private val json = "application/json".toMediaType()
    private val refreshLock = Mutex()
    private val base = BuildConfig.SUPABASE_URL
    private val key = BuildConfig.SUPABASE_KEY

    /** The signed-in user's id, or null. */
    suspend fun userId(): String? = session()?.optString("user_id")?.ifBlank { null }

    private suspend fun session(): JSONObject? =
        settings.groupSession.first().takeIf { it.isNotBlank() }?.let { runCatching { JSONObject(it) }.getOrNull() }

    /** Signs in with a Google ID token. [rawNonce] is the nonce before hashing. Returns the user id. */
    suspend fun signInWithGoogle(idToken: String, rawNonce: String): String {
        val body = JSONObject().put("provider", "google").put("id_token", idToken).put("nonce", rawNonce)
        val r = call(Request.Builder().url("$base/auth/v1/token?grant_type=id_token").post(body.toString().toRequestBody(json)), null)
        return store(JSONObject(r))
    }

    suspend fun signOut() = settings.setGroupSession("")

    private suspend fun store(t: JSONObject): String {
        val userId = t.getJSONObject("user").getString("id")
        val s = JSONObject()
            .put("access_token", t.getString("access_token"))
            .put("refresh_token", t.getString("refresh_token"))
            .put("expires_at", System.currentTimeMillis() / 1000 + t.optLong("expires_in", 3600))
            .put("user_id", userId)
        settings.setGroupSession(s.toString())
        return userId
    }

    /** A valid access token, refreshed when it ends within a minute. Null when signed out. */
    private suspend fun accessToken(): String? = refreshLock.withLock {
        val s = session() ?: return null
        if (s.optLong("expires_at") - 60 > System.currentTimeMillis() / 1000) return s.getString("access_token")
        val body = JSONObject().put("refresh_token", s.getString("refresh_token"))
        return try {
            val r = call(Request.Builder().url("$base/auth/v1/token?grant_type=refresh_token").post(body.toString().toRequestBody(json)), null)
            store(JSONObject(r))
            session()?.getString("access_token")
        } catch (e: SupabaseException) {
            if (e.code in 400..499) signOut() // the refresh token is gone: sign in again
            throw e
        }
    }

    suspend fun rpc(name: String, args: JSONObject): String =
        authed(Request.Builder().url("$base/rest/v1/rpc/$name").post(args.toString().toRequestBody(json)))

    suspend fun select(pathAndQuery: String): JSONArray =
        JSONArray(authed(Request.Builder().url("$base/rest/v1/$pathAndQuery").get()))

    suspend fun insert(table: String, rows: JSONArray) {
        authed(Request.Builder().url("$base/rest/v1/$table").post(rows.toString().toRequestBody(json)))
    }

    suspend fun patch(pathAndQuery: String, values: JSONObject) {
        authed(Request.Builder().url("$base/rest/v1/$pathAndQuery").patch(values.toString().toRequestBody(json)))
    }

    suspend fun delete(pathAndQuery: String) {
        authed(Request.Builder().url("$base/rest/v1/$pathAndQuery").delete())
    }

    suspend fun deleteAccount() {
        authed(Request.Builder().url("$base/functions/v1/delete-account").post("{}".toRequestBody(json)))
        signOut()
    }

    private suspend fun authed(b: Request.Builder): String {
        val token = accessToken() ?: throw SupabaseException(401, "signed out")
        return call(b, token)
    }

    private suspend fun call(b: Request.Builder, token: String?): String = withContext(Dispatchers.IO) {
        b.header("apikey", key).header("Authorization", "Bearer ${token ?: key}")
        try {
            client.newCall(b.build()).execute().use { r ->
                val text = r.body?.string().orEmpty()
                if (!r.isSuccessful) throw SupabaseException(r.code, text.take(200))
                text
            }
        } catch (e: SupabaseException) {
            throw e
        } catch (e: IOException) {
            throw SupabaseException(0, "no connection")
        }
    }
}
