package com.expensetracker.app.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.ui.components.ListenerStatusBanner
import com.expensetracker.app.ui.viewmodel.AppViewModel
import com.expensetracker.app.ui.viewmodel.SettingsViewModel

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
    var newCategoryName by remember { mutableStateOf("") }
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
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                ListenerStatusBanner(
                    isAccessGranted = uiState.isAccessGranted,
                    onEnableClick = viewModel::openNotificationSettings
                )
            }

            item {
                Button(
                    onClick = onOpenNotificationDebug,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = if (uiState.capturedNotificationCount > 0) {
                            "View notification log (${uiState.capturedNotificationCount})"
                        } else {
                            "View notification log"
                        }
                    )
                }
                Text(
                    text = "Lists every notification the listener receives, with save/skip reasons.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }

            item {
                Button(
                    onClick = viewModel::reconnectListener,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Reconnect listener")
                }
                Text(
                    text = "Runs reconnect attempts for ~60 seconds. If an alert appears, tap it or open notification access settings.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 4.dp)
                )
                uiState.reconnectMessage?.let { message ->
                    Text(
                        text = message,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }
            }

            item {
                Text(
                    text = "Appearance",
                    style = MaterialTheme.typography.titleMedium
                )
                androidx.compose.foundation.layout.Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(text = "Dark mode", style = MaterialTheme.typography.bodyLarge)
                        Text(
                            text = "Use dark theme across the app",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    Switch(
                        checked = darkMode,
                        onCheckedChange = appViewModel::setDarkMode
                    )
                }
            }

            item {
                Text(
                    text = "Spending categories",
                    style = MaterialTheme.typography.titleMedium
                )
                Text(
                    text = "Categories and notes are saved locally on your phone (Room database).",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            items(uiState.categories, key = { it.id }) { category ->
                Card(modifier = Modifier.fillMaxWidth()) {
                    androidx.compose.foundation.layout.Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp, vertical = 4.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
                    ) {
                        Text(
                            text = category.name + if (category.isDefault) " (default)" else "",
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.weight(1f)
                        )
                        if (!category.isDefault) {
                            IconButton(onClick = { viewModel.deleteCategory(category.id) }) {
                                Icon(Icons.Default.Delete, contentDescription = "Remove category")
                            }
                        }
                    }
                }
            }

            item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = newCategoryName,
                        onValueChange = { newCategoryName = it },
                        label = { Text("New category name") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true
                    )
                    Button(
                        onClick = {
                            viewModel.addCategory(newCategoryName)
                            newCategoryName = ""
                        },
                        enabled = newCategoryName.isNotBlank()
                    ) {
                        Icon(Icons.Default.Add, contentDescription = null)
                        Text("Add category", modifier = Modifier.padding(start = 4.dp))
                    }
                }
            }

            item {
                val count = uiState.allowlistedPackages.size
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 56.dp)
                        .clickable(role = Role.Button, onClick = onOpenPaymentApps),
                    verticalArrangement = Arrangement.Center
                ) {
                    Text(text = "Payment apps", style = MaterialTheme.typography.titleMedium)
                    Text(
                        text = when (count) {
                            0 -> "None chosen. Koban listens to no app."
                            1 -> "1 app chosen"
                            else -> "$count apps chosen"
                        },
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            item {
                val online by viewModel.onlineFeatures.collectAsStateWithLifecycle()
                androidx.compose.foundation.layout.Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .toggleable(
                            value = online,
                            role = Role.Switch,
                            onValueChange = viewModel::setOnlineFeatures
                        ),
                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(text = "Online features", style = MaterialTheme.typography.titleMedium)
                        Text(
                            text = if (online) "On: groups and reading receipts with Claude can use the internet."
                            else "Off: Koban makes no network calls. Groups and reading receipts with Claude stop.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    Switch(checked = online, onCheckedChange = null)
                }
            }

            item {
                var codeInput by remember { mutableStateOf("") }
                Text(text = "Invite code", style = MaterialTheme.typography.titleMedium)
                Text(
                    text = if (uiState.onlineAccess) "Online access: on. Receipts are read by Claude on Koban's server."
                    else "Enter an invite code from Koban's owner to read receipts with Claude. " +
                        "Everything else works without one.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                if (uiState.onlineAccess) {
                    androidx.compose.material3.OutlinedButton(
                        onClick = viewModel::removeOnlineAccess,
                        modifier = Modifier.padding(top = 8.dp)
                    ) { Text("Remove online access") }
                } else {
                    OutlinedTextField(
                        value = codeInput,
                        onValueChange = { codeInput = it.uppercase() },
                        label = { Text("XXXX-XXXX") },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 8.dp),
                        singleLine = true,
                        isError = uiState.inviteMessage != null,
                        supportingText = uiState.inviteMessage?.let { { Text(it) } },
                        keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(
                            capitalization = androidx.compose.ui.text.input.KeyboardCapitalization.Characters,
                            autoCorrectEnabled = false
                        )
                    )
                    Button(
                        onClick = { viewModel.enterInviteCode(codeInput) },
                        enabled = codeInput.isNotBlank() && !uiState.inviteBusy,
                        modifier = Modifier.padding(top = 8.dp)
                    ) { Text(if (uiState.inviteBusy) "Checking…" else "Use code") }
                }
            }

            item {
                var keyInput by remember(uiState.geminiApiKey) { mutableStateOf(uiState.geminiApiKey) }
                val hasKey = uiState.geminiApiKey.isNotBlank()
                Text(
                    text = "Gemini (optional)",
                    style = MaterialTheme.typography.titleMedium
                )
                Text(
                    text = "Uses your own Google AI Studio key, kept on this phone only. " +
                        "When on, each waiting payment is sent to Google to clean the merchant name.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                androidx.compose.foundation.layout.Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
                ) {
                    Text(
                        text = "Use Gemini to pre-fill",
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.weight(1f)
                    )
                    Switch(
                        checked = uiState.geminiPrefillEnabled && hasKey,
                        onCheckedChange = viewModel::setGeminiPrefillEnabled,
                        enabled = hasKey
                    )
                }
                OutlinedTextField(
                    value = keyInput,
                    onValueChange = { keyInput = it },
                    label = { Text("Gemini API key") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp),
                    singleLine = true,
                    visualTransformation = androidx.compose.ui.text.input.PasswordVisualTransformation(),
                    keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(
                        keyboardType = androidx.compose.ui.text.input.KeyboardType.Password
                    )
                )
                Button(
                    onClick = { viewModel.saveGeminiApiKey(keyInput) },
                    enabled = keyInput.trim() != uiState.geminiApiKey,
                    modifier = Modifier.padding(top = 8.dp)
                ) {
                    Text("Save")
                }
            }

            item {
                Text(
                    text = "Parser test tool",
                    style = MaterialTheme.typography.titleMedium
                )
                Text(
                    text = "Paste a sample notification to verify amount and merchant extraction.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            item {
                OutlinedTextField(
                    value = uiState.regexTestInput,
                    onValueChange = viewModel::updateRegexTestInput,
                    label = { Text("Notification text") },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 3
                )
                Button(
                    onClick = viewModel::runRegexTest,
                    modifier = Modifier.padding(top = 8.dp)
                ) {
                    Text("Test parse")
                }
                uiState.regexTestResult?.let { result ->
                    Text(
                        text = result,
                        modifier = Modifier.padding(top = 8.dp),
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }

            item {
                Text(
                    text = "Background reliability",
                    style = MaterialTheme.typography.titleMedium
                )
                Text(
                    text = "You do not need to keep the app open on screen. After granting notification access, a small persistent notification appears so Android does not kill the listener when you swipe the app away.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                if (uiState.isXiaomiDevice) {
                    Text(
                        text = "Xiaomi / HyperOS (15T): Autostart and Background autostart are required. " +
                            "Do not use “Clear all” in recents — it can revoke notification access.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                    Button(
                        onClick = viewModel::openManufacturerBackgroundSettings,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 8.dp)
                    ) {
                        Text("Open Xiaomi autostart / battery settings")
                    }
                    uiState.xiaomiBackgroundChecklist.forEach { step ->
                        Text(
                            text = "• $step",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(top = 4.dp)
                        )
                    }
                }
                if (!uiState.isBatteryOptimizationIgnored) {
                    Text(
                        text = "Battery optimization is enabled for this app — tracking may stop in the background.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                    Button(
                        onClick = viewModel::openBatterySettings,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 8.dp)
                    ) {
                        Text("Disable battery optimization")
                    }
                } else {
                    Text(
                        text = "Battery optimization is disabled — good for background tracking.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }
            }

            item {
                Text(
                    text = "Checklist: enable Notification access, allow the persistent tracking notification, then make a payment. Check the notification log if nothing is saved.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}
