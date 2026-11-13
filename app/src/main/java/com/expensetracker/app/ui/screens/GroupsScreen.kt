package com.expensetracker.app.ui.screens

import android.app.Activity
import android.content.Intent
import android.text.format.DateUtils
import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Share
import com.expensetracker.app.ui.components.DialogTextField
import com.expensetracker.app.ui.components.InitialsAvatar
import com.expensetracker.app.ui.components.CategoryDot
import com.expensetracker.app.ui.components.KobanRow
import com.expensetracker.app.ui.components.LargeTopBar
import com.expensetracker.app.ui.components.ListGroup
import com.expensetracker.app.ui.components.Mon
import com.expensetracker.app.ui.components.MonFace
import com.expensetracker.app.ui.components.MoneyText
import com.expensetracker.app.ui.components.SegmentedControl
import com.expensetracker.app.ui.components.TonalButton
import com.expensetracker.app.ui.theme.LocalMoneyColors
import com.expensetracker.app.ui.theme.categoryColor as themeCategoryColor
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.groups.GroupDetail
import com.expensetracker.app.groups.GroupRepository
import com.expensetracker.app.groups.Member
import com.expensetracker.app.groups.Period
import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.ui.viewmodel.GroupsViewModel
import kotlinx.coroutines.launch
import java.math.BigDecimal
import java.time.Instant
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

private val Edge = 16.dp
private val Block = 24.dp

private fun rm(v: BigDecimal) = "RM ${AmountFormatter.formatGrouped(v)}"

/** The app's own color for a default category name; a person's own categories use the shared "other" grey. */
@Composable
private fun categoryColor(name: String): Color =
    themeCategoryColor(
        DefaultCategories.all.firstOrNull { it.name.equals(name, ignoreCase = true) }?.id ?: "other"
    )

@Composable
private fun Messages(vm: GroupsViewModel, host: SnackbarHostState) {
    val message by vm.message.collectAsStateWithLifecycle()
    LaunchedEffect(message) {
        message?.let { host.showSnackbar(it); vm.messageShown() }
    }
}

@Composable
private fun NameDialog(title: String, label: String, start: String, confirm: String, max: Int, onDismiss: () -> Unit, onConfirm: (String) -> Unit) {
    var text by rememberSaveable { mutableStateOf(start) }
    AlertDialog(
        shape = RoundedCornerShape(24.dp),
        containerColor = MaterialTheme.colorScheme.surfaceContainer,
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            DialogTextField(
                value = text,
                onValueChange = { text = it.take(max) },
                label = label,
                supportingText = "${text.trim().length} of $max"
            )
        },
        confirmButton = { TextButton(onClick = { onConfirm(text.trim()) }, enabled = text.isNotBlank()) { Text(confirm) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}

@Composable
private fun ConfirmDialog(title: String, body: String, confirm: String, onDismiss: () -> Unit, onConfirm: () -> Unit) {
    AlertDialog(
        shape = RoundedCornerShape(24.dp),
        containerColor = MaterialTheme.colorScheme.surfaceContainer,
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = { Text(body) },
        confirmButton = {
            TextButton(onClick = onConfirm) { Text(confirm, color = MaterialTheme.colorScheme.error) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}

@Composable
private fun OnlineOffState(onTurnOn: () -> Unit) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = Edge, vertical = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Mon(MonFace.IDLE, 120.dp)
        Text("Online features are off", style = MaterialTheme.typography.titleLarge, textAlign = TextAlign.Center)
        Text(
            "Groups need online features. While they are off, Koban makes no network calls.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
        Button(onClick = onTurnOn, modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp)) { Text("Turn on online features") }
    }
}

@Composable
private fun SignedOutState(busy: Boolean, onSignIn: () -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = Edge, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.surfaceContainer).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text("Compare spending with friends", style = MaterialTheme.typography.headlineSmall)
            Text(
                "Members see each other's totals per category, for each week and month.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon(Icons.Default.Check, contentDescription = null, tint = LocalMoneyColors.current.received)
                Text("Shared: category totals, week and month", style = MaterialTheme.typography.bodyMedium)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon(Icons.Default.Lock, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("Never shared: single payments, shops, times, notes, money in", style = MaterialTheme.typography.bodyMedium)
            }
        }
        Button(onClick = onSignIn, enabled = !busy, modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp)) {
            Text(if (busy) "Signing in…" else "Sign in with Google")
        }
        Text(
            "Groups use the invite code you entered in Settings.",
            Modifier.fillMaxWidth(),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
    }
}

// ---------------- The Groups tab ----------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GroupsScreen(onOpenGroup: (String) -> Unit, vm: GroupsViewModel = hiltViewModel()) {
    val state by vm.state.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val host = remember { SnackbarHostState() }
    val activity = LocalContext.current as Activity
    var dialog by rememberSaveable { mutableStateOf("") }
    var menu by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    Messages(vm, host)
    val signedIn = state.online && state.userId != null

    Scaffold(
        contentWindowInsets = WindowInsets(0),
        snackbarHost = { SnackbarHost(host) },
        topBar = {
            LargeTopBar("Groups") {
                if (signedIn) {
                    IconButton(onClick = { menu = true }) { Icon(Icons.Default.MoreVert, contentDescription = "Account") }
                    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                        DropdownMenuItem(text = { Text("Change your name") }, onClick = { menu = false; dialog = "alias" })
                        DropdownMenuItem(text = { Text("Sign out") }, onClick = { menu = false; vm.run { signOut(); null } })
                        DropdownMenuItem(text = { Text("Delete account") }, onClick = { menu = false; dialog = "delete" })
                    }
                }
            }
        }
    ) { padding ->
        Box(Modifier.padding(padding).fillMaxSize()) {
            when {
                !state.online -> OnlineOffState { vm.setOnline(true) }

                state.userId == null -> SignedOutState(busy) { vm.run { signIn(activity) } }

                else -> PullToRefreshBox(isRefreshing = state.loading, onRefresh = vm::refresh) {
                    LazyColumn(
                        Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(Edge),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        items(state.removedFrom, key = { "n${it.first}" }) { (id, name) ->
                            Surface(shape = RoundedCornerShape(12.dp), color = MaterialTheme.colorScheme.errorContainer) {
                                Row(Modifier.padding(start = 16.dp, end = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Text("The owner removed you from $name.", Modifier.weight(1f), color = MaterialTheme.colorScheme.onErrorContainer)
                                    TextButton(onClick = { vm.run(silent = true) { dismissRemoved(id); null } }) { Text("OK") }
                                }
                            }
                        }
                        if (state.groups.isEmpty() && !state.loading) item {
                            Text(
                                "You are in no groups yet. Make a group and share its code, or join a friend's group with their code.",
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        if (state.groups.isNotEmpty()) item {
                            ListGroup {
                                state.groups.forEach { g ->
                                    item(key = g.id) {
                                        val owner = if (g.ownerId == state.userId) " · you are the owner" else ""
                                        KobanRow(
                                            title = g.name,
                                            subtitle = "${g.members} ${if (g.members == 1) "member" else "members"}$owner",
                                            leading = { InitialsAvatar(g.name, tint = MaterialTheme.colorScheme.primaryContainer) },
                                            trailing = if (g.requests > 0) {
                                                {
                                                    Text(
                                                        "${g.requests} ${if (g.requests == 1) "request" else "requests"}",
                                                        style = MaterialTheme.typography.labelMedium,
                                                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                                                        modifier = Modifier.clip(CircleShape).background(MaterialTheme.colorScheme.primaryContainer)
                                                            .padding(horizontal = 10.dp, vertical = 4.dp)
                                                    )
                                                }
                                            } else null,
                                            showChevron = true,
                                            onClickLabel = "Open group",
                                            onClick = { onOpenGroup(g.id) }
                                        )
                                    }
                                }
                            }
                        }
                        item {
                            Row(Modifier.padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                Button(onClick = { dialog = "make" }, enabled = !busy, modifier = Modifier.weight(1f).defaultMinSize(minHeight = 48.dp)) {
                                    Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(18.dp))
                                    Spacer(Modifier.width(8.dp))
                                    Text("Make a group")
                                }
                                OutlinedButton(onClick = { dialog = "join" }, enabled = !busy, modifier = Modifier.weight(1f).defaultMinSize(minHeight = 48.dp)) { Text("Join a group") }
                            }
                            Text(
                                "You can be in up to 5 groups. Each group has up to 10 members.",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(top = 8.dp)
                            )
                        }
                    }
                }
            }
        }
    }

    val close = { dialog = "" }
    when (dialog) {
        "make" -> NameDialog("Make a group", "Group name", "", "Make group", 40, close) { name -> vm.run(onOk = close) { makeGroup(name) } }
        "join" -> NameDialog("Join a group", "Group code, for example GRP-7KQ2", "", "Ask to join", 8, close) { code ->
            vm.run(onOk = { close(); scope.launch { host.showSnackbar("Request sent. You join when the group owner approves it.") } }) { askToJoin(code) }
        }
        "alias" -> NameDialog("Your name in groups", "Name", state.alias, "Save", 30, close) { name -> vm.run(onOk = close) { setAlias(name) } }
        "delete" -> ConfirmDialog(
            "Delete your account?",
            "This removes you from all your groups and deletes your shared totals from Koban's server. The payments on this phone stay.",
            "Delete account", close
        ) { vm.run(onOk = close) { deleteAccount() } }
    }
}

// ---------------- One group (layout D) ----------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GroupScreen(onBack: () -> Unit, vm: GroupsViewModel = hiltViewModel()) {
    val state by vm.state.collectAsStateWithLifecycle()
    val detail by vm.detail.collectAsStateWithLifecycle()
    val period by vm.period.collectAsStateWithLifecycle()
    val exists by vm.groupExists.collectAsStateWithLifecycle()
    val host = remember { SnackbarHostState() }
    var menu by remember { mutableStateOf(false) }
    var dialog by rememberSaveable { mutableStateOf("") }
    var target by remember { mutableStateOf<Member?>(null) }
    var loadedAt by remember { mutableStateOf(Instant.now()) }
    Messages(vm, host)
    LaunchedEffect(exists) { if (!exists) onBack() }
    LaunchedEffect(detail) { loadedAt = Instant.now() }
    val d = detail
    val isOwner = d != null && d.group.ownerId == state.userId

    Scaffold(
        contentWindowInsets = WindowInsets(0),
        snackbarHost = { SnackbarHost(host) },
        topBar = {
            TopAppBar(
                windowInsets = WindowInsets(0),
                title = { Text(d?.group?.name ?: "Group") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back") }
                },
                actions = {
                    IconButton(onClick = { menu = true }) { Icon(Icons.Default.MoreVert, contentDescription = "Group actions") }
                    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                        if (isOwner) {
                            DropdownMenuItem(text = { Text("Rename group") }, onClick = { menu = false; dialog = "rename" })
                            DropdownMenuItem(text = { Text("Make a new code") }, onClick = { menu = false; dialog = "code" })
                        }
                        DropdownMenuItem(text = { Text("Leave group") }, onClick = { menu = false; dialog = "leave" })
                    }
                }
            )
        }
    ) { padding ->
        PullToRefreshBox(isRefreshing = state.loading, onRefresh = vm::refresh, modifier = Modifier.padding(padding).fillMaxSize()) {
            if (d == null) return@PullToRefreshBox
            GroupBody(d, state.userId, isOwner, period, loadedAt, vm, onRemove = { target = it; dialog = "remove" }, onHandOver = { target = it; dialog = "owner" })
        }
    }

    val close = { dialog = "" }
    val group = d?.group ?: return
    when (dialog) {
        "rename" -> NameDialog("Rename group", "Group name", group.name, "Save", 40, close) { name -> vm.run(onOk = close) { rename(group.id, name) } }
        "code" -> ConfirmDialog(
            "Make a new code?", "The old code stops working. Members stay in the group.", "Make new code", close
        ) { vm.run(onOk = close) { newCode(group.id) } }
        "leave" -> ConfirmDialog(
            "Leave ${group.name}?",
            "Members stop seeing your totals. To come back, ask the owner again with the group code.",
            "Leave group", close
        ) { vm.run(onOk = { close(); onBack() }) { leave(group.id) } }
        "remove" -> target?.let { m ->
            ConfirmDialog(
                "Remove ${m.alias}?", "${m.alias} stops seeing this group, and the members stop seeing ${m.alias}'s totals.", "Remove", close
            ) { vm.run(onOk = close) { remove(group.id, m.userId) } }
        }
        "owner" -> target?.let { m ->
            ConfirmDialog(
                "Make ${m.alias} the owner?", "${m.alias} can then approve requests and remove members. You stay a member.", "Make owner", close
            ) { vm.run(onOk = close) { handOver(group.id, m.userId) } }
        }
    }
}

@Composable
private fun GroupBody(
    d: GroupDetail,
    me: String?,
    isOwner: Boolean,
    period: Period,
    loadedAt: Instant,
    vm: GroupsViewModel,
    onRemove: (Member) -> Unit,
    onHandOver: (Member) -> Unit
) {
    var open by rememberSaveable { mutableStateOf<String?>(null) }
    var help by rememberSaveable { mutableStateOf(false) }
    val context = LocalContext.current
    val mine = d.members.firstOrNull { it.userId == me }
    val today = LocalDate.now(GroupRepository.ZONE)
    val top = d.members.maxOfOrNull { it.total.toFloat() } ?: 0f

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = Edge, end = Edge, top = 8.dp, bottom = Block),
        verticalArrangement = Arrangement.spacedBy(Block)
    ) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                SegmentedControl(
                    labels = Period.entries.map { if (it == Period.WEEK) "Week" else "Month" },
                    selectedIndex = Period.entries.indexOf(period),
                    onPick = { vm.setPeriod(Period.entries[it]) }
                )
                Text(
                    "Updated ${if (System.currentTimeMillis() - loadedAt.toEpochMilli() < 60_000) "just now"
                    else DateUtils.getRelativeTimeSpanString(loadedAt.toEpochMilli(), System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS)}. Pull down to refresh.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        if (mine != null) item {
            val place = d.members.indexOf(mine) + 1
            val days = GroupRepository.daysLeft(period, today)
            val label = if (period == Period.MONTH) "You spent in ${today.month.getDisplayName(TextStyle.FULL, Locale.ENGLISH)}" else "You spent this week"
            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.surfaceContainer)
                    .padding(16.dp).semantics(mergeDescendants = true) {},
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                MoneyText(rm(mine.total), style = MaterialTheme.typography.displayMedium, color = MaterialTheme.colorScheme.onSurface)
                Text(
                    "${ordinal(place)} of ${d.members.size} in ${d.group.name}. Resets in $days ${if (days == 1) "day" else "days"}.",
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }

        if (isOwner && d.requests.isNotEmpty()) item {
            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.surfaceContainer)
                    .border(1.dp, MaterialTheme.colorScheme.primary, RoundedCornerShape(16.dp)).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text("Join requests", style = MaterialTheme.typography.titleMedium)
                Text(
                    "Only you see these, because you own the group. Requests end after 7 days.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                d.requests.forEach { r ->
                    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically) {
                        InitialsAvatar(r.alias, size = 36.dp)
                        Text(r.alias, Modifier.padding(start = 12.dp).weight(1f), style = MaterialTheme.typography.bodyLarge)
                        TextButton(onClick = { vm.run { answer(r, false) } }, modifier = Modifier.defaultMinSize(minHeight = 48.dp)) { Text("Decline") }
                        TonalButton("Approve", onClick = { vm.run { answer(r, true) } })
                    }
                }
            }
        }

        item {
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        "Members",
                        Modifier.weight(1f).semantics { heading() }.padding(start = 4.dp),
                        style = MaterialTheme.typography.titleSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    IconButton(onClick = { help = !help }) {
                        Icon(Icons.Default.Info, contentDescription = if (help) "Hide how to read this list" else "How to read this list")
                    }
                }
                ListGroup {
                    d.members.forEach { m ->
                        item(key = m.userId) {
                            MemberRow(
                                m = m, isMe = m.userId == me, isOwner = isOwner, expanded = open == m.userId,
                                barFraction = if (top > 0f) (m.total.toFloat() / top).coerceIn(0.02f, 1f) else 1f,
                                onToggle = { open = if (open == m.userId) null else m.userId },
                                onRemove = { onRemove(m) }, onHandOver = { onHandOver(m) }
                            )
                        }
                    }
                }
                if (help) Text(
                    "Members are listed by total spending. A higher total is not a win. Tap a member to see their categories, in their own names.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(start = 4.dp, top = 8.dp)
                )
            }
        }

        item {
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.surfaceContainer).padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(Modifier.weight(1f)) {
                    Text("Group code", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(d.group.code, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold)
                }
                TonalButton("Share code", icon = Icons.Default.Share, onClick = {
                    val send = Intent(Intent.ACTION_SEND).setType("text/plain")
                        .putExtra(Intent.EXTRA_TEXT, "Join my Koban group \"${d.group.name}\" with the code ${d.group.code}.")
                    context.startActivity(Intent.createChooser(send, "Share group code"))
                })
            }
        }
    }
}

@Composable
private fun MemberRow(
    m: Member,
    isMe: Boolean,
    isOwner: Boolean,
    expanded: Boolean,
    barFraction: Float,
    onToggle: () -> Unit,
    onRemove: () -> Unit,
    onHandOver: () -> Unit
) {
    val stale = m.updatedAt?.isBefore(Instant.now().minusSeconds(24 * 3600)) ?: true
    val name = if (isMe) "${m.alias} (you)" else m.alias
    Column(
        Modifier
            .fillMaxWidth()
            .animateContentSize()
            .clickable(role = Role.Button, onClickLabel = if (expanded) "Hide categories" else "Show categories", onClick = onToggle)
            .semantics { stateDescription = if (expanded) "Expanded" else "Collapsed" }
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            InitialsAvatar(m.alias, size = 36.dp, tint = if (isMe) MaterialTheme.colorScheme.primaryContainer else null)
            Text(
                name,
                Modifier.padding(start = 12.dp).weight(1f),
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = if (isMe) FontWeight.SemiBold else null,
                color = if (isMe) LocalMoneyColors.current.goldText else MaterialTheme.colorScheme.onSurface
            )
            MoneyText(rm(m.total), Modifier.padding(start = 8.dp), style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurface)
        }
        if (m.categories.isNotEmpty()) {
            Row(
                Modifier.fillMaxWidth(barFraction).height(6.dp).clip(CircleShape).clearAndSetSemantics {},
                horizontalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                m.categories.forEach { (c, v) ->
                    Box(Modifier.weight(v.toFloat().coerceAtLeast(0.01f)).fillMaxSize().background(categoryColor(c)))
                }
            }
        }
        if (stale) Text(
            m.updatedAt?.let { "Updated ${DateUtils.getRelativeTimeSpanString(it.toEpochMilli())}" } ?: "No totals sent yet",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        if (expanded) {
            if (m.categories.isEmpty()) Text("No spending in this period.", style = MaterialTheme.typography.bodyMedium)
            m.categories.forEach { (c, v) ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    CategoryDot(categoryColor(c))
                    Text(c, Modifier.padding(start = 12.dp).weight(1f), style = MaterialTheme.typography.bodyMedium)
                    MoneyText(rm(v), style = MaterialTheme.typography.bodyMedium)
                }
            }
            if (isMe) Text(
                "This is what the other members see about you. Never shared: single payments, shops, times, notes and money in.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            if (isOwner && !isMe) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TextButton(onClick = onHandOver, modifier = Modifier.defaultMinSize(minHeight = 48.dp)) { Text("Make owner") }
                TextButton(onClick = onRemove, modifier = Modifier.defaultMinSize(minHeight = 48.dp)) { Text("Remove", color = MaterialTheme.colorScheme.error) }
            }
        }
    }
}

private fun ordinal(n: Int): String {
    val suffix = if (n % 100 in 11..13) "th" else when (n % 10) { 1 -> "st"; 2 -> "nd"; 3 -> "rd"; else -> "th" }
    return "$n$suffix"
}
