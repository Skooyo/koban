package com.expensetracker.app.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.expensetracker.app.BuildConfig
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "settings")

/** Holds the Gemini key and the device token. Excluded from backup in res/xml/backup_rules.xml and data_extraction_rules.xml. */
private val Context.secretsDataStore: DataStore<Preferences> by preferencesDataStore(name = "secrets")

@Singleton
class SettingsRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val allowlistKey = stringSetPreferencesKey("payment_app_allowlist")
    private val chosenKey = booleanPreferencesKey("payment_apps_chosen")
    private val darkModeKey = booleanPreferencesKey("dark_mode")
    private val geminiPrefillKey = booleanPreferencesKey("gemini_prefill_enabled")
    private val geminiApiKeyKey = stringPreferencesKey("gemini_api_key")
    private val deviceTokenKey = stringPreferencesKey("device_token")

    val allowlistedPackages: Flow<Set<String>> = context.dataStore.data.map { prefs ->
        prefs[allowlistKey] ?: emptySet()
    }

    /** Unset means: chosen if an older version already stored a real list, else not yet. */
    val paymentAppsChosen: Flow<Boolean> = context.dataStore.data.map { prefs ->
        prefs[chosenKey] ?: !prefs[allowlistKey].isNullOrEmpty()
    }

    val darkModeEnabled: Flow<Boolean> = context.dataStore.data.map { prefs ->
        prefs[darkModeKey] ?: true
    }

    /** Off by default. When on and a key exists, Gemini pre-fills waiting payments. */
    val geminiPrefillEnabled: Flow<Boolean> = context.dataStore.data.map { prefs ->
        prefs[geminiPrefillKey] ?: false
    }

    /** The user's own key. Defaults to the build-time key from .env. Never log it. */
    val geminiApiKey: Flow<String> = context.secretsDataStore.data.map { prefs ->
        prefs[geminiApiKeyKey] ?: BuildConfig.GEMINI_API_KEY
    }

    /** Given by Koban's server for a good invite code. Blank means no online access. Never log it. */
    val deviceToken: Flow<String> = context.secretsDataStore.data.map { prefs ->
        prefs[deviceTokenKey].orEmpty()
    }

    suspend fun setDeviceToken(token: String) {
        context.secretsDataStore.edit { prefs ->
            if (token.isBlank()) prefs.remove(deviceTokenKey) else prefs[deviceTokenKey] = token
        }
    }

    suspend fun setDarkMode(enabled: Boolean) {
        context.dataStore.edit { prefs ->
            prefs[darkModeKey] = enabled
        }
    }

    suspend fun setGeminiPrefillEnabled(enabled: Boolean) {
        context.dataStore.edit { prefs ->
            prefs[geminiPrefillKey] = enabled
        }
    }

    suspend fun setGeminiApiKey(key: String) {
        context.secretsDataStore.edit { prefs ->
            prefs[geminiApiKeyKey] = key.trim()
        }
    }

    /** Writes the allowlist and marks the choice as made, so the picker stops opening by itself. */
    suspend fun setPaymentApps(packages: Set<String>) {
        context.dataStore.edit { prefs ->
            prefs[allowlistKey] = packages
            prefs[chosenKey] = true
        }
    }
}
