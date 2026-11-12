package com.expensetracker.app.update

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ReleaseParserTest {
    private fun release(tag: String, vararg assets: String, body: String? = "Fixes") = JSONObject()
        .put("tag_name", tag).put("body", body ?: JSONObject.NULL)
        .put("assets", JSONArray(assets.map { JSONObject().put("name", it)
            .put("browser_download_url", "https://example.test/$it").put("size", 65_000_000L) }))
        .toString()

    @Test fun newerApk_returnsUpdate() = assertEquals(
        AvailableUpdate(7, "0.7.0", "https://example.test/koban-7.apk", 65_000_000L, "Fixes"),
        ReleaseParser.parseLatest(release("v0.7.0", "koban-7.apk"), currentVersionCode = 6))

    @Test fun sameVersion_returnsNull() = assertNull(ReleaseParser.parseLatest(release("v0.7.0", "koban-7.apk"), 7))

    @Test fun noApkAsset_returnsNull() = assertNull(ReleaseParser.parseLatest(release("v0.7.0", "notes.txt"), 6))

    @Test fun badJson_returnsNull() = assertNull(ReleaseParser.parseLatest("{not json", 6))

    @Test fun twoApks_picksHighest() = assertEquals(8,
        ReleaseParser.parseLatest(release("v0.8.0", "koban-7.apk", "koban-8.apk"), 6)?.versionCode)

    @Test fun nullBody_givesEmptyNotes() = assertEquals("",
        ReleaseParser.parseLatest(release("v0.7.0", "koban-7.apk", body = null), 6)?.notes)
}
