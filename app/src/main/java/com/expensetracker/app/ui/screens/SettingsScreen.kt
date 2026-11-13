package com.expensetracker.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ListAlt
import androidx.compose.material.icons.filled.BatteryAlert
import androidx.compose.material.icons.filled.BugReport
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.BuildConfig
import com.expensetracker.app.ui.components.CategoryDot
import com.expensetracker.app.ui.components.KobanRow
import com.expensetracker.app.ui.components.ListGroup
import com.expensetracker.app.ui.components.ListenerStatusBanner
import com.expensetracker.app.ui.components.SectionHeading
import com.expensetracker.app.ui.components.TonalButton
import com.expensetracker.app.ui.theme.categoryColor
import com.expensetracker.app.ui.viewmodel.AppViewModel
import com.expensetracker.app.ui.viewmodel.SettingsViewModel
import com.expensetracker.app.update.UpdateState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onBack: () -> Unit,
    onOpenNotificationDebug: () -> Unit,
    onOpenPaymentApps: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: SettingsViewModel = hiltViewModel(),
    appViewModel: AppViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val darkMode by appViewModel.darkModeEnabled.collectAsStateWithLifecycle()
    val online by viewModel.onlineFeatures.collectAsStateWithLifecycle()
    val updateState by viewModel.updateState.collectAsStateWithLifecycle()
    var newCategoryName by remember { mutableStateOf("") }
    var codeInput by remember { mutableStateOf("") }
    val lifecycleOwner = LocalLifecycleOwner.current

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.refresh()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    Scaffold(
        modifier = modifier,
        contentWindowInsets = WindowInsets(0),
        topBar = {
            TopAppBar(
                windowInsets = WindowInsets(0),
                title = { Text("Settings") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            item {
                Column {
                    SectionHeading("Tracking")
                    ListenerStatusBanner(
                        isAccessGranted = uiState.isAccessGranted,
                        onEnableClick = viewModel::openNotificationSettings
                    )
                    ListGroup(Modifier.padding(top = 8.dp)) {
                        item {
                            val count = uiState.allowlistedPackages.size
                            KobanRow(
                                title = "Payment apps",
                                subtitle = when (count) {
                                    0 -> "None chosen. Koban listens to no app."
                                    1 -> "1 app chosen"
                                    else -> "$count apps chosen"
                                },
                                leading = { Icon(Icons.AutoMirrored.Filled.ListAlt, contentDescription = null) },
                                showChevron = true,
                                onClick = onOpenPaymentApps
                            )
                        }
                        item {
                            KobanRow(
                                title = "Notification log",
                                subtitle = if (uiState.capturedNotificationCount > 0) {
                                    "${uiState.capturedNotificationCount} notifications captured"
                                } else {
                                    "Every notification the listener receives, with save and skip reasons"
                                },
                                leading = { Icon(Icons.Default.BugReport, contentDescription = null) },
                                showChevron = true,
                                onClick = onOpenNotificationDebug
                            )
                        }
                        item {
                            KobanRow(
                                title = "Reconnect listener",
                                subtitle = uiState.reconnectMessage
                                    ?: "Use this when payments stop showing up. It retries for about 60 seconds.",
                                subtitleColor = if (uiState.reconnectMessage != null) MaterialTheme.colorScheme.primary else Color.Unspecified,
                                leading = { Icon(Icons.Default.Sync, contentDescription = null) },
                                showChevron = true,
                                onClick = viewModel::reconnectListener
                            )
                        }
                    }
                }
            }

            item {
                Column {
                    SectionHeading("Appearance")
                    ListGroup {
                        item {
                            KobanRow(
                                title = "Dark mode",
                                subtitle = "Use the dark theme across the app",
                                leading = { Icon(Icons.Default.Palette, contentDescription = null) },
                                trailing = { Switch(checked = darkMode, onCheckedChange = null) },
                                modifier = Modifier.toggleable(
                                    value = darkMode,
                                    role = Role.Switch,
                                    onValueChange = appViewModel::setDarkMode
                                )
                            )
                        }
                    }
                }
            }

            item {
                Column {
                    SectionHeading("Categories")
                    if (uiState.categories.isNotEmpty()) {
                        ListGroup {
                            uiState.categories.forEach { category ->
                                item {
                                    KobanRow(
                                        title = category.name,
                                        subtitle = if (category.isDefault) "Built in" else "Your own",
                                        leading = { CategoryDot(categoryColor(category.id)) },
                                        trailing = if (category.isDefault) null else {
                                            {
                                                IconButton(onClick = { viewModel.deleteCategory(category.id) }) {
                                                    Icon(Icons.Default.Delete, contentDescription = "Remove category ${category.name}")
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    Row(
                        Modifier.padding(top = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedTextField(
                            value = newCategoryName,
                            onValueChange = { newCategoryName = it },
                            label = { Text("New category") },
                            modifier = Modifier.weight(1f),
                            singleLine = true
                        )
                        TonalButton(
                            text = "Add",
                            onClick = {
                                viewModel.addCategory(newCategoryName)
                                newCategoryName = ""
                            },
                            enabled = newCategoryName.isNotBlank()
                        )
                    }
                    Text(
                        text = "Categories and notes are saved on this phone only.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }
            }

            item {
                Column {
                    SectionHeading("Online")
                    ListGroup {
                        item {
                            KobanRow(
                                title = "Online features",
                                subtitle = if (online) "On: groups and reading receipts with Claude can use the internet."
                                else "Off: Koban makes no network calls. Groups and reading receipts with Claude stop.",
                                leading = { Icon(Icons.Default.Cloud, contentDescription = null) },
                                trailing = { Switch(checked = online, onCheckedChange = null) },
                                modifier = Modifier.toggleable(
                                    value = online,
                                    role = Role.Switch,
                                    onValueChange = viewModel::setOnlineFeatures
                                )
                            )
                        }
                        if (uiState.onlineAccess) {
                            item {
                                KobanRow(
                                    title = "Invite code",
                                    subtitle = "Accepted. Receipts are read by Claude on Koban's server.",
                                    leading = { Icon(Icons.Default.Lock, contentDescription = null) },
                                    trailing = {
                                        TextButton(onClick = viewModel::removeOnlineAccess) { Text("Remove") }
                                    }
                                )
                            }
                        } else {
                            item {
                                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Text("Invite code", style = MaterialTheme.typography.titleMedium)
                                    Text(
                                        text = "Enter an invite code from Koban's owner to read receipts with Claude. " +
                                            "Everything else works without one.",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    OutlinedTextField(
                                        value = codeInput,
                                        onValueChange = { codeInput = it.uppercase() },
                                        label = { Text("XXXX-XXXX") },
                                        modifier = Modifier.fillMaxWidth(),
                                        singleLine = true,
                                        isError = uiState.inviteMessage != null,
                                        supportingText = uiState.inviteMessage?.let { { Text(it) } },
                                        keyboardOptions = KeyboardOptions(
                                            capitalization = KeyboardCapitalization.Characters,
                                            autoCorrectEnabled = false
                                        )
                                    )
                                    TonalButton(
                                        text = if (uiState.inviteBusy) "Checking…" else "Use code",
                                        onClick = { viewModel.enterInviteCode(codeInput) },
                                        enabled = codeInput.isNotBlank() && !uiState.inviteBusy
                                    )
                                }
                            }
                        }
                    }
                }
            }

            item {
                Column {
                    SectionHeading("Background")
                    ListGroup {
                        item {
                            if (uiState.isBatteryOptimizationIgnored) {
                                KobanRow(
                                    title = "Battery optimization",
                                    subtitle = "Off. Good for background tracking.",
                                    leading = { Icon(Icons.Default.BatteryAlert, contentDescription = null) },
                                    trailing = {
                                        Icon(Icons.Default.Check, contentDescription = "Done", tint = MaterialTheme.colorScheme.primary)
                                    }
                                )
                            } else {
                                KobanRow(
                                    title = "Battery optimization",
                                    subtitle = "On. Tracking may stop in the background. Tap to turn it off.",
                                    subtitleColor = MaterialTheme.colorScheme.error,
                                    leading = { Icon(Icons.Default.BatteryAlert, contentDescription = null) },
                                    showChevron = true,
                                    onClick = viewModel::openBatterySettings,
                                    onClickLabel = "Disable battery optimization"
                                )
                            }
                        }
                        if (uiState.isXiaomiDevice) {
                            item {
                                KobanRow(
                                    title = "Xiaomi autostart",
                                    subtitle = "Autostart and Background autostart are required. " +
                                        "Do not use “Clear all” in recents: it can revoke notification access.",
                                    subtitleColor = MaterialTheme.colorScheme.error,
                                    leading = { Icon(Icons.Default.Settings, contentDescription = null) },
                                    showChevron = true,
                                    onClick = viewModel::openManufacturerBackgroundSettings,
                                    onClickLabel = "Open Xiaomi autostart and battery settings"
                                )
                            }
                            if (uiState.xiaomiBackgroundChecklist.isNotEmpty()) {
                                item {
                                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                        uiState.xiaomiBackgroundChecklist.forEach { step ->
                                            Text(
                                                text = "• $step",
                                                style = MaterialTheme.typography.bodyMedium,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Text(
                        text = "You do not need to keep the app open. After you grant notification access, a small " +
                            "persistent notification keeps Android from stopping the listener. " +
                            "Checklist: enable Notification access, allow that notification, then make a payment. " +
                            "Check the notification log if nothing is saved.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }
            }

            item {
                Column {
                    SectionHeading("About")
                    ListGroup {
                        item {
                            KobanRow(
                                title = "App version ${BuildConfig.VERSION_NAME}",
                                subtitle = when {
                                    !online -> "Turn on Online features to check for updates."
                                    updateState == UpdateState.UpToDate -> "Koban is up to date."
                                    else -> null
                                },
                                leading = { Icon(Icons.Default.Info, contentDescription = null) },
                                trailing = {
                                    TextButton(onClick = viewModel::checkForUpdates, enabled = online) {
                                        Text("Check for updates")
                                    }
                                }
                            )
                        }
                        item {
                            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text("Parser test tool", style = MaterialTheme.typography.titleMedium)
                                Text(
                                    text = "Paste a sample notification to check amount and shop extraction.",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                OutlinedTextField(
                                    value = uiState.regexTestInput,
                                    onValueChange = viewModel::updateRegexTestInput,
                                    label = { Text("Notification text") },
                                    modifier = Modifier.fillMaxWidth(),
                                    minLines = 3
                                )
                                TonalButton(text = "Test parse", onClick = viewModel::runRegexTest)
                                uiState.regexTestResult?.let { result ->
                                    Text(text = result, style = MaterialTheme.typography.bodyMedium)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
