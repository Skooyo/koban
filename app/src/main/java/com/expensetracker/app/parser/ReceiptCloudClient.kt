package com.expensetracker.app.parser

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import com.expensetracker.app.data.SettingsRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.math.BigDecimal
import java.util.Calendar
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

sealed interface CloudRead {
    data class Ok(val read: ReceiptRead, val readsLeft: Int?) : CloudRead
    /** [why] completes "Read on the phone. …". [tokenRevoked]: drop the stored token. [usedRead]: Claude ran for this photo. */
    data class Failed(val why: String, val tokenRevoked: Boolean = false, val usedRead: Boolean = false) : CloudRead
}

sealed interface Registration {
    data class Ok(val deviceToken: String) : Registration
    data class Failed(val message: String) : Registration
}

/** Talks to Koban's Supabase Edge Functions. See docs/superpowers/specs/2026-11-12-receipt-claude-fallback-design.md. */
@Singleton
class ReceiptCloudClient @Inject constructor(
    @ApplicationContext private val context: Context,
    baseClient: OkHttpClient,
    private val settings: SettingsRepository
) {
    // Claude 60 s -> Edge Function 70 s -> app 90 s.
    private val client = baseClient.newBuilder()
        .readTimeout(90, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .callTimeout(90, TimeUnit.SECONDS)
        .build()

    suspend fun register(inviteCode: String): Registration = withContext(Dispatchers.IO) {
        if (!settings.onlineFeatures.first()) return@withContext Registration.Failed(ONLINE_OFF)
        val body = JSONObject().put("inviteCode", inviteCode.trim().uppercase()).toString()
            .toRequestBody("application/json".toMediaType())
        try {
            client.newCall(Request.Builder().url(BASE + "register").post(body).build()).execute().use { r ->
                when (r.code) {
                    200 -> Registration.Ok(JSONObject(r.body!!.string()).getString("deviceToken"))
                    400 -> Registration.Failed("The invite code looks like XXXX-XXXX.")
                    429 -> Registration.Failed("Too many tries. Try again in an hour.")
                    403 -> Registration.Failed("Invite code not accepted.")
                    else -> Registration.Failed("Koban's server had a problem. Try again later.")
                }
            }
        } catch (e: IOException) {
            Registration.Failed("Could not reach Koban's server. Check the internet connection.")
        }
    }

    suspend fun read(imageUri: Uri, deviceToken: String): CloudRead = withContext(Dispatchers.IO) {
        if (!settings.onlineFeatures.first()) return@withContext CloudRead.Failed(ONLINE_OFF)
        val photo = try {
            shrink(imageUri)
        } catch (e: Exception) {
            debug("shrink failed: ${e.javaClass.simpleName} ${e.message}")
            null
        } ?: return@withContext CloudRead.Failed(NOT_REACHABLE).also { debug("photo could not be opened") }
        debug("upload ${photo.size} bytes")
        val request = Request.Builder()
            .url(BASE + "read-receipt")
            .header("Authorization", "Bearer $deviceToken")
            .post(photo.toRequestBody("image/jpeg".toMediaType()))
            .build()
        try {
            client.newCall(request).execute().use { r ->
                val text = r.body?.string().orEmpty()
                debug("read-receipt answered ${r.code}")
                when (r.code) {
                    200 -> parse(text)?.let { CloudRead.Ok(it, JSONObject(text).optInt("readsLeftToday", -1).takeIf { n -> n >= 0 }) }
                        ?: CloudRead.Failed(COULD_NOT_READ, usedRead = true)
                    401 -> CloudRead.Failed("Your invite code is no longer active.", tokenRevoked = true)
                    429 -> CloudRead.Failed(
                        when (runCatching { JSONObject(text).optString("limit") }.getOrNull()) {
                            "all" -> "Koban reached today's Claude limit."
                            "code" -> "Your invite code used all its Claude reads for today."
                            else -> "You used your 10 Claude reads for today."
                        }
                    )
                    502, 504 -> CloudRead.Failed(COULD_NOT_READ, usedRead = true)
                    else -> CloudRead.Failed(NOT_REACHABLE)
                }
            }
        } catch (e: IOException) {
            debug("read-receipt failed: ${e.javaClass.simpleName} ${e.message}")
            CloudRead.Failed(NOT_REACHABLE) // offline, or the 90 s call timeout
        }
    }

    /** Longest side 1600 px, JPEG quality 85, upright. Keeps the upload well under the 2 MB limit. */
    private fun shrink(uri: Uri): ByteArray? {
        val resolver = context.contentResolver
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) } // returns null: it fills only bounds
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= MAX_SIDE) sample *= 2
        var bitmap = resolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
        } ?: return null
        val scale = MAX_SIDE.toFloat() / maxOf(bitmap.width, bitmap.height)
        val degrees = resolver.openInputStream(uri)?.use {
            when (ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
        } ?: 0f
        if (scale < 1f || degrees != 0f) {
            val m = Matrix().apply { if (scale < 1f) postScale(scale, scale); postRotate(degrees) }
            bitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, m, true)
        }
        return ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
            out.toByteArray()
        }
    }

    /** Debug builds only: status and error names, never the photo or the token (adb logcat -s KobanCloud). */
    private fun debug(msg: String) {
        if (com.expensetracker.app.BuildConfig.DEBUG) android.util.Log.d("KobanCloud", msg)
    }

    companion object {
        private const val BASE = "https://ydrlxhqdalomlkqkdjyb.supabase.co/functions/v1/"
        private const val MAX_SIDE = 1600
        private const val NOT_REACHABLE = "Claude was not reachable."
        private const val ONLINE_OFF = "Turn on online features in Settings to read with Claude."
        private const val COULD_NOT_READ = "Claude could not read this receipt. This used 1 of today's reads."

        /** The 200 reply as a read. Accepted when items and charges add up to the printed total exactly. */
        fun parse(json: String): ReceiptRead? = try {
            val j = JSONObject(json)
            val itemsJson = j.getJSONArray("items")
            val items = (0 until itemsJson.length()).map { i ->
                val o = itemsJson.getJSONObject(i)
                ReceiptItemDraft(o.getString("name"), o.optInt("quantity", 1).coerceAtLeast(1), BigDecimal(o.getString("price")))
            }.filter { it.name.isNotBlank() && it.price.signum() > 0 }
            fun money(key: String) = j.optString(key).takeIf { it.isNotBlank() && it != "null" }?.let(::BigDecimal) ?: BigDecimal.ZERO
            val total = j.optString("total").takeIf { it.isNotBlank() && it != "null" }?.let(::BigDecimal)
            val draft = ReceiptDraft(
                merchant = j.optString("merchant").takeIf { it.isNotBlank() && it != "null" },
                dateMillis = date(j.optString("date")),
                items = items,
                serviceCharge = money("serviceCharge"),
                tax = money("tax"),
                discount = money("discount"),
                rounding = money("rounding"),
                printedTotal = total
            )
            val sum = items.fold(BigDecimal.ZERO) { a, it -> a + it.price } +
                draft.serviceCharge + draft.tax - draft.discount + draft.rounding
            ReceiptRead(draft, accepted = total != null && sum.compareTo(total) == 0, calculated = emptyList())
        } catch (e: Exception) {
            null
        }

        /** "YYYY-MM-DD" to local midnight, the same as [ReceiptRules] gives. */
        private fun date(text: String): Long? {
            val m = Regex("""(\d{4})-(\d{2})-(\d{2})""").matchEntire(text) ?: return null
            val (y, mo, d) = m.destructured
            return runCatching {
                Calendar.getInstance().apply { isLenient = false; clear(); set(y.toInt(), mo.toInt() - 1, d.toInt(), 0, 0, 0) }.timeInMillis
            }.getOrNull()
        }
    }
}
