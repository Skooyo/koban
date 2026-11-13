package io.github.skooyo.koban

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class LegacySettingsReaderTest {
    @get:Rule val tmp = TemporaryFolder()

    private fun copyFixtures(): File {
        val dir = tmp.newFolder("datastore")
        for (name in listOf("settings.preferences_pb", "secrets.preferences_pb")) {
            val stream = javaClass.classLoader!!.getResourceAsStream("legacy/datastore/$name")!!
            stream.use { input -> File(dir, name).outputStream().use { input.copyTo(it) } }
        }
        return dir
    }

    @Test fun readsAllEightSettingsFromRealFiles() {
        assertEquals(
            mapOf(
                "payment_app_allowlist" to listOf("com.maybank2u.life", "my.com.tngdigital.ewallet"),
                "payment_apps_chosen" to true, "onboarding_done" to true, "dark_mode" to false,
                "online_features" to false, "last_update_check" to 1762300000000L,
                "device_token" to "test-device-token-0001",
                "group_session" to """{"access_token":"test-access","refresh_token":"test-refresh-0001","expires_at":1762303600,"user_id":"00000000-0000-0000-0000-000000000001"}""",
            ),
            LegacySettingsReader.read(copyFixtures()),
        )
    }

    @Test fun returnsEmptyMapWhenNoFilesExist() {
        assertEquals(emptyMap<String, Any>(), LegacySettingsReader.read(tmp.newFolder("empty")))
    }
}
