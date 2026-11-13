package io.github.skooyo.koban

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking

/** Reads the settings that the 0.1.1 app stored with DataStore. Plain JVM code, no Android API. */
object LegacySettingsReader {
    private val fileNames = listOf("settings.preferences_pb", "secrets.preferences_pb")

    /** A string set becomes a sorted list. A missing file adds nothing. A corrupt file throws. */
    fun read(dataStoreDir: File): Map<String, Any> {
        val result = mutableMapOf<String, Any>()
        for (name in fileNames) {
            val file = File(dataStoreDir, name)
            if (!file.exists()) continue
            val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
            try {
                val store = PreferenceDataStoreFactory.create(scope = scope, produceFile = { file })
                for ((key, value) in runBlocking { store.data.first() }.asMap()) {
                    result[key.name] = if (value is Set<*>) value.map { it as String }.sorted() else value
                }
            } finally {
                scope.cancel()
            }
        }
        return result
    }
}
