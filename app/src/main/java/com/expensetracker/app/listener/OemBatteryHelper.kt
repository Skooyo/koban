package com.expensetracker.app.listener

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings

object OemBatteryHelper {
    fun isXiaomiFamily(): Boolean {
        val manufacturer = Build.MANUFACTURER.orEmpty().lowercase()
        val brand = Build.BRAND.orEmpty().lowercase()
        return manufacturer in XIAOMI_MANUFACTURERS || brand in XIAOMI_MANUFACTURERS
    }

    /**
     * Opens the best available OEM screen for keeping the app alive in the background.
     * On Xiaomi, Autostart is usually more important than standard battery optimization.
     */
    fun openManufacturerBackgroundSettings(context: Context): OpenResult {
        if (!isXiaomiFamily()) {
            NotificationAccessHelper.openBatteryOptimizationSettings(context)
            return OpenResult.GENERIC_BATTERY
        }

        val attempts = listOf(
            xiaomiIntent(
                packageName = "com.miui.securitycenter",
                className = "com.miui.permcenter.autostart.AutoStartManagementActivity",
                label = "Autostart"
            ),
            xiaomiIntent(
                packageName = "com.miui.securitycenter",
                className = "com.miui.appmanager.ApplicationsDetailsActivity",
                label = "App details"
            ) {
                putExtra("package_name", context.packageName)
                putExtra("package_label", context.applicationInfo.loadLabel(context.packageManager))
            },
            xiaomiIntent(
                packageName = "com.miui.powerkeeper",
                className = "com.miui.powerkeeper.ui.HiddenAppsConfigActivity",
                label = "Battery"
            ) {
                putExtra("package_name", context.packageName)
            },
            xiaomiIntent(
                packageName = "com.miui.securitycenter",
                className = "com.miui.powercenter.PowerSettings",
                label = "Power settings"
            )
        )

        for (attempt in attempts) {
            if (launch(context, attempt.intent)) {
                return attempt.result
            }
        }

        NotificationAccessHelper.openBatteryOptimizationSettings(context)
        return OpenResult.GENERIC_BATTERY
    }

    fun xiaomiChecklist(): List<String> = listOf(
        "Security app → Autostart → turn ON for Expense Tracker",
        "Settings → Apps → Expense Tracker → App permissions → Background autostart → Allow",
        "Settings → Apps → Expense Tracker → Battery saver → No restrictions",
        "Settings → Apps → Expense Tracker → turn OFF “Restrict background activity” if shown",
        "Recent apps → long-press Expense Tracker → tap the lock icon (do not “Clear all”)",
        "Keep the persistent “Tracking payment notifications” notification visible",
        "If notification access keeps turning off, disable MIUI optimizations in Developer options"
    )

    private data class LaunchAttempt(val intent: Intent, val result: OpenResult)

    private fun xiaomiIntent(
        packageName: String,
        className: String,
        label: String,
        extras: Intent.() -> Unit = {}
    ): LaunchAttempt {
        val intent = Intent().apply {
            component = ComponentName(packageName, className)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            extras()
        }
        val result = when (label) {
            "Autostart" -> OpenResult.XIAOMI_AUTOSTART
            else -> OpenResult.XIAOMI_OTHER
        }
        return LaunchAttempt(intent, result)
    }

    private fun launch(context: Context, intent: Intent): Boolean {
        return try {
            context.packageManager.resolveActivity(intent, 0) != null
        } catch (_: Exception) {
            false
        } && try {
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private val XIAOMI_MANUFACTURERS = setOf("xiaomi", "redmi", "poco", "blackshark")

    enum class OpenResult {
        XIAOMI_AUTOSTART,
        XIAOMI_OTHER,
        GENERIC_BATTERY
    }
}
