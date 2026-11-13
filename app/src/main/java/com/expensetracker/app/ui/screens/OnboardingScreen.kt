package com.expensetracker.app.ui.screens

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.listener.NotificationAccessHelper
import com.expensetracker.app.listener.OemBatteryHelper
import com.expensetracker.app.ui.components.Mon
import com.expensetracker.app.ui.components.MonFace
import com.expensetracker.app.ui.theme.LocalMoneyColors
import com.expensetracker.app.ui.viewmodel.OnboardingRules
import com.expensetracker.app.ui.viewmodel.OnboardingStep
import com.expensetracker.app.ui.viewmodel.OnboardingViewModel

private val stepNames = mapOf(
    OnboardingStep.ACCESS to "Notification access",
    OnboardingStep.BLOCKED to "Notification access",
    OnboardingStep.APPS to "Payment apps",
    OnboardingStep.RUNNING to "Keep it running",
    OnboardingStep.READY to "Ready"
)

/** First-start flow: welcome, notification access, payment apps, keep-alive settings, ready. */
@Composable
fun OnboardingScreen(
    onFinished: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: OnboardingViewModel = hiltViewModel()
) {
    val step by viewModel.step.collectAsStateWithLifecycle()
    val context = LocalContext.current

    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { viewModel.onResume() }
    BackHandler {
        if (step == OnboardingStep.WELCOME) {
            viewModel.finish(onFinished)
        } else {
            viewModel.back()
        }
    }

    // The picker keeps its own top bar and Save button.
    if (step == OnboardingStep.APPS) {
        PaymentAppsScreen(onClose = viewModel::appsSaved, onBack = viewModel::back, modifier = modifier)
        return
    }

    fun openAccessSettings() {
        viewModel.openedSettings()
        NotificationAccessHelper.openNotificationAccessSettings(context)
    }

    Scaffold(
        modifier = modifier,
        contentWindowInsets = WindowInsets(0),
        bottomBar = {
            Column(
                Modifier.fillMaxWidth().padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                when (step) {
                    OnboardingStep.WELCOME -> MainButton("Get started", viewModel::next)
                    OnboardingStep.ACCESS -> {
                        MainButton("Open settings", ::openAccessSettings)
                        Text(
                            "In the list, tap Koban, then turn on Allow.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.padding(top = 8.dp)
                        )
                    }
                    OnboardingStep.BLOCKED -> {
                        MainButton("Open app info") { openAppInfo(context) }
                        OutlinedButton(
                            onClick = ::openAccessSettings,
                            modifier = Modifier.fillMaxWidth().padding(top = 8.dp).heightIn(min = 48.dp)
                        ) { Text("Try again") }
                    }
                    OnboardingStep.RUNNING -> {
                        MainButton("Next", viewModel::next)
                        TextButton(onClick = viewModel::next) { Text("Skip for now") }
                    }
                    OnboardingStep.READY -> MainButton("Go to Home") { viewModel.finish(onFinished) }
                    OnboardingStep.APPS -> Unit
                }
            }
        }
    ) { padding ->
        Column(
            Modifier
                .padding(padding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            val number = OnboardingRules.stepNumber(step)
            if (number != null) ProgressHeader(number, stepNames.getValue(step))
            when (step) {
                OnboardingStep.WELCOME -> WelcomeStep()
                OnboardingStep.ACCESS -> AccessStep()
                OnboardingStep.BLOCKED -> BlockedStep()
                OnboardingStep.RUNNING -> RunningStep()
                OnboardingStep.READY -> ReadyStep()
                OnboardingStep.APPS -> Unit
            }
        }
    }
}

@Composable
private fun MainButton(text: String, onClick: () -> Unit) {
    Button(onClick = onClick, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) { Text(text) }
}

@Composable
private fun ProgressHeader(number: Int, name: String) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            repeat(4) { index ->
                Box(
                    Modifier
                        .weight(1f)
                        .height(4.dp)
                        .background(
                            if (index < number) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.surfaceContainerHighest
                        )
                )
            }
        }
        Text("Step $number of 4 · $name", style = MaterialTheme.typography.bodySmall)
    }
}

@Composable
private fun CenteredMon(face: MonFace, size: Dp) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) { Mon(face, size) }
}

@Composable
private fun InfoRow(icon: ImageVector, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
        Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(text, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
    }
}

@Composable
private fun WelcomeStep() {
    CenteredMon(MonFace.IDLE, 140.dp)
    Text(
        "Koban counts your spending for you.",
        style = MaterialTheme.typography.displaySmall,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth()
    )
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            InfoRow(Icons.Default.NotificationsActive, "Reads payment alerts from the apps you pick.")
            InfoRow(Icons.Default.TouchApp, "You check each payment before it counts.")
            InfoRow(Icons.Default.Lock, "Nothing leaves the phone. No account needed.")
        }
    }
}

@Composable
private fun AccessStep() {
    Text("Let Koban see payment alerts", style = MaterialTheme.typography.headlineSmall)
    Text(
        "When your bank or e-wallet sends a payment alert, Koban turns it into a payment for you to check.",
        style = MaterialTheme.typography.bodyLarge
    )
    InfoRow(Icons.Default.CheckCircle, "Koban reads only the apps you pick next.")
    InfoRow(Icons.Default.CheckCircle, "It ignores chats and all other alerts.")
}

@Composable
private fun BlockedStep() {
    CenteredMon(MonFace.WORRY, 64.dp)
    Text("Android blocked this", style = MaterialTheme.typography.headlineSmall)
    Text(
        "Koban was installed from a file, so Android wants one more step.",
        style = MaterialTheme.typography.bodyLarge
    )
    Text("1  Tap Open app info below", style = MaterialTheme.typography.bodyLarge)
    Text(
        "2  Tap ⋮ at the top right — Then tap Allow restricted settings",
        style = MaterialTheme.typography.bodyLarge
    )
    Text("3  Come back and tap Try again", style = MaterialTheme.typography.bodyLarge)
    Text(
        "Android shows this item only after it blocks an app once.",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
}

@Composable
private fun RunningStep() {
    val context = LocalContext.current
    // Bumped on every resume so the rows read their state again.
    var refresh by remember { mutableIntStateOf(0) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { refresh++ }

    fun alertsGranted() = ContextCompat.checkSelfPermission(
        context, Manifest.permission.POST_NOTIFICATIONS
    ) == PackageManager.PERMISSION_GRANTED

    var askedForAlerts by rememberSaveable { mutableStateOf(false) }
    val alertsLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { refresh++ }

    Text("Keep Koban running", style = MaterialTheme.typography.headlineSmall)
    Text(
        "Phones stop apps in the background to save battery. These settings keep tracking on.",
        style = MaterialTheme.typography.bodyLarge
    )
    // The key rebuilds the rows after every resume, so they read the phone state again.
    key(refresh) {
        if (Build.VERSION.SDK_INT >= 33) {
            SettingRow("Alerts", "Tell me when tracking stops", alertsGranted(), "Allow") {
                val activity = context as? Activity
                // After two denials Android shows no dialog, so send the user to the settings page.
                if (activity != null && !activity.shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS) && askedForAlerts) {
                    openAlertSettings(context)
                } else {
                    askedForAlerts = true
                    alertsLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                }
            }
        }
        SettingRow("Battery", "No restrictions", NotificationAccessHelper.isBatteryOptimizationIgnored(context), "Open settings") {
            NotificationAccessHelper.openBatteryOptimizationSettings(context)
        }
        if (OemBatteryHelper.isXiaomiFamily()) {
            SettingRow("Autostart", "Start Koban after a restart", false, "Open settings") {
                OemBatteryHelper.openManufacturerBackgroundSettings(context)
            }
        }
    }
    Text(
        "Only the settings your phone needs show here.",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
}

@Composable
private fun SettingRow(title: String, action: String, done: Boolean, buttonLabel: String, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Text(action, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        if (done) {
            Icon(
                Icons.Default.CheckCircle,
                contentDescription = "$title done",
                tint = LocalMoneyColors.current.received
            )
        } else {
            FilledTonalButton(onClick = onClick) { Text(buttonLabel) }
        }
    }
}

@Composable
private fun ReadyStep() {
    CenteredMon(MonFace.HAPPY, 140.dp)
    Text(
        "Koban is ready",
        style = MaterialTheme.typography.headlineMedium,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth()
    )
    Text(
        "Pay with a card or e-wallet. The payment shows up in Koban within a few seconds.",
        style = MaterialTheme.typography.bodyLarge,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth()
    )
}

private fun openAppInfo(context: Context) {
    try {
        context.startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    } catch (_: ActivityNotFoundException) {
        // No such settings page on this phone.
    }
}

private fun openAlertSettings(context: Context) {
    try {
        context.startActivity(
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    } catch (_: ActivityNotFoundException) {
        // No such settings page on this phone.
    }
}
