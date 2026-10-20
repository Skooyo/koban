package com.expensetracker.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
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
    modifier: Modifier = Modifier,
    viewModel: SettingsViewModel = hiltViewModel(),
    appViewModel: AppViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val darkMode by appViewModel.darkModeEnabled.collectAsStateWithLifecycle()
    var manualPackage by remember { mutableStateOf("") }
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
        topBar = {
            TopAppBar(
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
                Text(
                    text = "Payment app allowlist",
                    style = MaterialTheme.typography.titleMedium
                )
                Text(
                    text = "Leave empty to track all apps, or add specific packages to limit which notifications are saved.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            if (uiState.allowlistedPackages.isEmpty()) {
                item {
                    Text(
                        text = "No apps restricted — all payment notifications with an RM amount will be tracked.",
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            } else {
                items(uiState.allowlistedPackages.toList()) { pkg ->
                    Card(modifier = Modifier.fillMaxWidth()) {
                        androidx.compose.foundation.layout.Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 12.dp, vertical = 4.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
                        ) {
                            Text(text = pkg, style = MaterialTheme.typography.bodyMedium)
                            IconButton(onClick = { viewModel.removePackage(pkg) }) {
                                Icon(Icons.Default.Delete, contentDescription = "Remove")
                            }
                        }
                    }
                }
            }

            item {
                Text(
                    text = "Add package manually",
                    style = MaterialTheme.typography.titleSmall
                )
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = manualPackage,
                        onValueChange = { manualPackage = it },
                        label = { Text("Package name (e.g. com.bank.app)") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true
                    )
                    Button(
                        onClick = {
                            viewModel.addPackageManually(manualPackage)
                            manualPackage = ""
                        },
                        enabled = manualPackage.isNotBlank()
                    ) {
                        Icon(Icons.Default.Add, contentDescription = null)
                        Text("Add", modifier = Modifier.padding(start = 4.dp))
                    }
                }
            }

            if (uiState.recentPackages.isNotEmpty()) {
                item {
                    Text(
                        text = "Recent notification sources",
                        style = MaterialTheme.typography.titleSmall
                    )
                }
                items(uiState.recentPackages) { pkg ->
                    Card(modifier = Modifier.fillMaxWidth()) {
                        androidx.compose.foundation.layout.Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
                        ) {
                            Text(text = pkg, modifier = Modifier.weight(1f))
                            if (pkg !in uiState.allowlistedPackages) {
                                Button(onClick = { viewModel.addPackage(pkg) }) {
                                    Text("Add")
                                }
                            } else {
                                Text(
                                    text = "Added",
                                    color = MaterialTheme.colorScheme.primary,
                                    style = MaterialTheme.typography.labelMedium
                                )
                            }
                        }
                    }
                }
            }

            item {
                Text(
                    text = "AI parsing (Google AI Studio)",
                    style = MaterialTheme.typography.titleMedium
                )
                Text(
                    text = if (uiState.geminiKeyConfigured) {
                        "API key configured · models ${uiState.geminiModelsLabel.ifBlank { "Gemini Flash Lite" }}. " +
                            "If one model is rate-limited, the other is tried automatically. " +
                            "Falls back to regex if both fail or you are offline."
                    } else {
                        "No API key — using regex only. Copy .env.example to .env, set GEMINI_API_KEY, and rebuild."
                    },
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
                        text = "Use AI for merchant extraction",
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.weight(1f)
                    )
                    Switch(
                        checked = uiState.llmParsingEnabled && uiState.geminiKeyConfigured,
                        onCheckedChange = viewModel::setLlmParsingEnabled,
                        enabled = uiState.geminiKeyConfigured
                    )
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
