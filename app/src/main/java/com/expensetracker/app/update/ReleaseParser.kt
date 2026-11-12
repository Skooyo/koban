package com.expensetracker.app.update

import org.json.JSONObject

data class AvailableUpdate(
    val versionCode: Int,
    val versionName: String,
    val apkUrl: String,
    val apkSize: Long,
    val notes: String
)

object ReleaseParser {
    private val apkName = Regex("""^koban-(\d+)\.apk$""")

    /** Reads the GitHub "latest release" JSON. Null when nothing newer, no APK asset, or bad JSON. */
    fun parseLatest(json: String, currentVersionCode: Int): AvailableUpdate? = try {
        val root = JSONObject(json)
        val assets = root.getJSONArray("assets")
        var best: Pair<Int, JSONObject>? = null
        for (i in 0 until assets.length()) {
            val asset = assets.getJSONObject(i)
            val code = apkName.matchEntire(asset.getString("name"))?.groupValues?.get(1)?.toIntOrNull() ?: continue
            if (best == null || code > best.first) best = code to asset
        }
        best?.takeIf { it.first > currentVersionCode }?.let { (code, asset) ->
            AvailableUpdate(
                versionCode = code,
                versionName = root.getString("tag_name").removePrefix("v"),
                apkUrl = asset.getString("browser_download_url"),
                apkSize = asset.getLong("size"),
                notes = root.optString("body", "").take(500)
            )
        }
    } catch (e: Exception) {
        null
    }
}
