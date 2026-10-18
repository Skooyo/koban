package com.expensetracker.app.ui.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.CategoryEntity
import com.expensetracker.app.data.CategoryRepository
import com.expensetracker.app.data.SettingsRepository
import com.expensetracker.app.listener.NotificationAccessHelper
import com.expensetracker.app.listener.OemBatteryHelper
import com.expensetracker.app.listener.ReconnectResult
import com.expensetracker.app.listener.RecentNotificationsStore
import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.parser.ExpenseNotificationParser
import com.expensetracker.app.parser.ExpenseParseResult
import com.expensetracker.app.parser.ParseSource
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SettingsUiState(
    val isAccessGranted: Boolean = false,
    val isBatteryOptimizationIgnored: Boolean = true,
    val isXiaomiDevice: Boolean = false,
    val xiaomiBackgroundChecklist: List<String> = emptyList(),
    val allowlistedPackages: Set<String> = emptySet(),
    val recentPackages: List<String> = emptyList(),
    val capturedNotificationCount: Int = 0,
    val categories: List<CategoryEntity> = emptyList(),
    val regexTestInput: String = "",
    val regexTestResult: String? = null,
    val reconnectMessage: String? = null,
    val llmParsingEnabled: Boolean = true,
    val geminiKeyConfigured: Boolean = false,
    val geminiModelsLabel: String = ""
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val settingsRepository: SettingsRepository,
    private val categoryRepository: CategoryRepository,
    private val expenseNotificationParser: ExpenseNotificationParser
) : ViewModel() {

    private val accessGranted = MutableStateFlow(false)
    private val regexInput = MutableStateFlow("")
    private val regexResult = MutableStateFlow<String?>(null)
    private val recentPackages = MutableStateFlow(RecentNotificationsStore.uniquePackages())
    private val reconnectMessage = MutableStateFlow<String?>(null)

    val uiState: StateFlow<SettingsUiState> = kotlinx.coroutines.flow.combine(
        kotlinx.coroutines.flow.combine(
            accessGranted,
            settingsRepository.allowlistedPackages,
            recentPackages,
            RecentNotificationsStore.notifications
        ) { granted, allowlist, recent, captured ->
            ListenerSettingsSlice(
                isAccessGranted = granted,
                allowlistedPackages = allowlist,
                recentPackages = recent,
                capturedNotificationCount = captured.size
            )
        },
        kotlinx.coroutines.flow.combine(
            categoryRepository.observeAll(),
            regexInput,
            regexResult,
            reconnectMessage
        ) { categories, input, result, reconnect ->
            FormSettingsSlice(categories, input, result, reconnect)
        },
        settingsRepository.llmParsingEnabled
    ) { listener, form, llmEnabled ->
        SettingsUiState(
            isAccessGranted = listener.isAccessGranted,
            isBatteryOptimizationIgnored = NotificationAccessHelper.isBatteryOptimizationIgnored(context),
            isXiaomiDevice = OemBatteryHelper.isXiaomiFamily(),
            xiaomiBackgroundChecklist = if (OemBatteryHelper.isXiaomiFamily()) {
                OemBatteryHelper.xiaomiChecklist()
            } else {
                emptyList()
            },
            allowlistedPackages = listener.allowlistedPackages,
            recentPackages = listener.recentPackages,
            capturedNotificationCount = listener.capturedNotificationCount,
            categories = form.categories,
            regexTestInput = form.input,
            regexTestResult = form.result,
            reconnectMessage = form.reconnectMessage,
            llmParsingEnabled = llmEnabled,
            geminiKeyConfigured = expenseNotificationParser.isLlmConfigured,
            geminiModelsLabel = expenseNotificationParser.modelsLabel
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), SettingsUiState(
        geminiKeyConfigured = expenseNotificationParser.isLlmConfigured,
        geminiModelsLabel = expenseNotificationParser.modelsLabel
    ))

    fun refresh() {
        accessGranted.value = NotificationAccessHelper.isNotificationAccessGranted(context)
        recentPackages.value = RecentNotificationsStore.uniquePackages()
        NotificationAccessHelper.ensureListenerActive(context)
    }

    fun reconnectListener() {
        viewModelScope.launch {
            reconnectMessage.value = "Reconnecting…"
            when (NotificationAccessHelper.reconnectListener(context)) {
                ReconnectResult.ACCESS_NOT_GRANTED -> {
                    reconnectMessage.value =
                        "Notification access was removed — re-enable it in system settings. " +
                        "On Xiaomi, enable Autostart and avoid clearing the app from recents."
                    return@launch
                }
                ReconnectResult.THROTTLED -> {
                    reconnectMessage.value = "Reconnect already attempted recently — wait a moment and try again."
                    return@launch
                }
                ReconnectResult.FAILED -> {
                    reconnectMessage.value = "Reconnect failed — open notification access settings."
                    return@launch
                }
                ReconnectResult.ATTEMPTED -> Unit
            }
            delay(65_000)
            reconnectMessage.value = if (NotificationAccessHelper.isListenerConnected()) {
                "Listener connected."
            } else {
                "Still disconnected after 60s — tap the alert notification or open notification access settings."
            }
        }
    }

    fun openBatterySettings() {
        NotificationAccessHelper.openBatteryOptimizationSettings(context)
    }

    fun openManufacturerBackgroundSettings() {
        OemBatteryHelper.openManufacturerBackgroundSettings(context)
    }

    fun openNotificationSettings() {
        NotificationAccessHelper.openNotificationAccessSettings(context)
    }

    fun setLlmParsingEnabled(enabled: Boolean) {
        viewModelScope.launch {
            settingsRepository.setLlmParsingEnabled(enabled)
        }
    }

    fun addPackage(packageName: String) {
        viewModelScope.launch {
            settingsRepository.addPackage(packageName)
        }
    }

    fun removePackage(packageName: String) {
        viewModelScope.launch {
            settingsRepository.removePackage(packageName)
        }
    }

    fun updateRegexTestInput(input: String) {
        regexInput.value = input
    }

    fun runRegexTest() {
        viewModelScope.launch {
            regexResult.value = "Parsing…"
            val input = regexInput.value
            regexResult.value = when (val parsed = expenseNotificationParser.parse(input)) {
                is ExpenseParseResult.Success -> {
                    val expense = parsed.expense
                    val via = when (parsed.source) {
                        ParseSource.LLM -> "LLM"
                        ParseSource.REGEX -> "regex"
                    }
                    "Amount: ${expense.currency} ${AmountFormatter.formatDisplay(expense.amount)}\n" +
                        "Merchant: ${expense.merchant ?: "—"}\n" +
                        "Type: ${expense.transactionType.name.lowercase()}\n" +
                        "Confidence: ${expense.confidence.name.lowercase()}\n" +
                        "Parser: $via"
                }
                is ExpenseParseResult.SkippedNotTransaction -> {
                    val reason = parsed.reason?.takeIf { it.isNotBlank() } ?: "not a money transaction"
                    "Skipped — not a transaction ($reason)"
                }
                ExpenseParseResult.NoAmount -> "No payment amount found in text"
            }
        }
    }

    fun addPackageManually(packageName: String) {
        viewModelScope.launch {
            settingsRepository.addPackage(packageName)
        }
    }

    fun addCategory(name: String) {
        viewModelScope.launch {
            categoryRepository.addCategory(name, "#5C6BC0")
        }
    }

    fun deleteCategory(id: String) {
        viewModelScope.launch {
            categoryRepository.deleteCategory(id)
        }
    }
}

private data class ListenerSettingsSlice(
    val isAccessGranted: Boolean,
    val allowlistedPackages: Set<String>,
    val recentPackages: List<String>,
    val capturedNotificationCount: Int
)

private data class FormSettingsSlice(
    val categories: List<CategoryEntity>,
    val input: String,
    val result: String?,
    val reconnectMessage: String?
)
