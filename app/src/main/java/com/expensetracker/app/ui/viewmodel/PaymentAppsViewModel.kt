package com.expensetracker.app.ui.viewmodel

import android.content.Context
import android.content.Intent
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.core.graphics.drawable.toBitmap
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.SettingsRepository
import com.expensetracker.app.parser.PaymentRules
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

data class InstalledApp(val packageName: String, val label: String, val icon: ImageBitmap?)

data class PaymentAppsUiState(
    val apps: List<InstalledApp>? = null,
    val selected: Set<String> = emptySet(),
    val query: String = ""
)

/** Installed preselected apps first, then by label. */
internal fun sortApps(apps: List<InstalledApp>, preselect: Set<String>): List<InstalledApp> =
    apps.sortedWith(
        compareBy<InstalledApp> { it.packageName !in preselect }
            .thenBy(String.CASE_INSENSITIVE_ORDER) { it.label }
    )

/** First open: the installed preselected apps. Later: the stored allowlist. */
internal fun initialSelection(
    chosen: Boolean,
    allowlist: Set<String>,
    installed: Set<String>,
    preselect: Set<String>
): Set<String> = if (chosen) allowlist else preselect.intersect(installed)

@HiltViewModel
class PaymentAppsViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(PaymentAppsUiState())
    val uiState: StateFlow<PaymentAppsUiState> = _uiState

    init {
        viewModelScope.launch {
            val apps = withContext(Dispatchers.IO) { loadApps() }
            val selected = initialSelection(
                chosen = settingsRepository.paymentAppsChosen.first(),
                allowlist = settingsRepository.allowlistedPackages.first(),
                installed = apps.mapTo(HashSet()) { it.packageName },
                preselect = PaymentRules.PRESELECT_PACKAGES
            )
            _uiState.value = PaymentAppsUiState(apps = apps, selected = selected)
        }
    }

    private fun loadApps(): List<InstalledApp> {
        val pm = context.packageManager
        val iconPx = (40 * context.resources.displayMetrics.density).toInt()
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val apps = pm.queryIntentActivities(intent, 0)
            .map { it.activityInfo.packageName }
            .filter { it != context.packageName }
            .distinct()
            .mapNotNull { pkg ->
                runCatching {
                    val info = pm.getApplicationInfo(pkg, 0)
                    val icon = runCatching {
                        pm.getApplicationIcon(info).toBitmap(iconPx, iconPx).asImageBitmap()
                    }.getOrNull()
                    InstalledApp(pkg, pm.getApplicationLabel(info).toString(), icon)
                }.getOrNull()
            }
        return sortApps(apps, PaymentRules.PRESELECT_PACKAGES)
    }

    fun setQuery(query: String) = _uiState.update { it.copy(query = query) }

    fun toggle(packageName: String) = _uiState.update {
        it.copy(selected = if (packageName in it.selected) it.selected - packageName else it.selected + packageName)
    }

    fun save(onDone: () -> Unit) {
        viewModelScope.launch {
            settingsRepository.setPaymentApps(_uiState.value.selected)
            onDone()
        }
    }
}
