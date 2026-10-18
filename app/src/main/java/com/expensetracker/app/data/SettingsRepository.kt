package com.expensetracker.app.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "settings")

@Singleton
class SettingsRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val allowlistKey = stringSetPreferencesKey("payment_app_allowlist")
    private val darkModeKey = booleanPreferencesKey("dark_mode")
    private val llmParsingKey = booleanPreferencesKey("llm_parsing_enabled")

    val allowlistedPackages: Flow<Set<String>> = context.dataStore.data.map { prefs ->
        prefs[allowlistKey] ?: emptySet()
    }

    val darkModeEnabled: Flow<Boolean> = context.dataStore.data.map { prefs ->
        prefs[darkModeKey] ?: true
    }

    /** When true and a Gemini API key is built in, use LLM parsing with regex fallback. */
    val llmParsingEnabled: Flow<Boolean> = context.dataStore.data.map { prefs ->
        prefs[llmParsingKey] ?: true
    }

    suspend fun setDarkMode(enabled: Boolean) {
        context.dataStore.edit { prefs ->
            prefs[darkModeKey] = enabled
        }
    }

    suspend fun setLlmParsingEnabled(enabled: Boolean) {
        context.dataStore.edit { prefs ->
            prefs[llmParsingKey] = enabled
        }
    }

    suspend fun addPackage(packageName: String) {
        val normalized = packageName.trim()
        if (normalized.isEmpty()) return
        context.dataStore.edit { prefs ->
            val current = prefs[allowlistKey] ?: emptySet()
            prefs[allowlistKey] = current + normalized
        }
    }

    suspend fun removePackage(packageName: String) {
        context.dataStore.edit { prefs ->
            val current = prefs[allowlistKey] ?: emptySet()
            prefs[allowlistKey] = current - packageName
        }
    }
}
