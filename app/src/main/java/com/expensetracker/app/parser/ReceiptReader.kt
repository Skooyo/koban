package com.expensetracker.app.parser

import android.content.Context
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import javax.inject.Inject
import javax.inject.Singleton

/** Reads a receipt photo on the device with ML Kit, then applies [ReceiptRules]. */
@Singleton
class ReceiptReader @Inject constructor(
    @ApplicationContext private val context: Context
) {
    /** Returns null if the image is unreadable or the rules find nothing. */
    suspend fun read(imageUri: Uri): ReceiptRead? = withContext(Dispatchers.IO) {
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        try {
            val text = recognizer.process(InputImage.fromFilePath(context, imageUri)).let { task ->
                suspendCancellableCoroutine { c ->
                    task.addOnSuccessListener { c.resume(it) }.addOnFailureListener { c.resumeWithException(it) }
                }
            }
            val lines = text.textBlocks.flatMap { it.lines }.mapNotNull { line ->
                val box = line.boundingBox ?: return@mapNotNull null
                // Debug only: raw OCR lines for the pairing investigation (adb logcat -s KobanOcr)
                if (com.expensetracker.app.BuildConfig.DEBUG) android.util.Log.d(
                    "KobanOcr", "${box.left},${box.top},${box.right},${box.bottom},${line.angle}\t${line.text}"
                )
                OcrLine(line.text, box.left, box.top, box.right, box.bottom, line.angle)
            }
            ReceiptRules.read(lines)
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (_: Exception) {
            null
        } finally {
            recognizer.close()
        }
    }
}
