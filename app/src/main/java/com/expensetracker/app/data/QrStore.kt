package com.expensetracker.app.data

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import java.io.IOException
import java.io.OutputStream
import javax.inject.Inject

/** Payment QR pictures in app storage, and copies of them in the gallery. Call from a background thread. */
class QrStore @Inject constructor(
    @ApplicationContext private val context: Context
) {
    /** Copies the picture at [uri] to `filesDir/qr/<personId>.img` and returns its absolute path. */
    fun importQr(personId: String, uri: Uri): String {
        val resolver = context.contentResolver
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw IllegalArgumentException("That file isn't an image.")

        val dir = File(context.filesDir, "qr").apply { mkdirs() }
        val target = File(dir, "$personId.img")
        // Copy to a temp file first so a failed copy keeps the old QR.
        val temp = File(dir, "$personId.tmp")
        try {
            resolver.openInputStream(uri)?.use { input -> temp.outputStream().use { input.copyTo(it) } }
                ?: throw IOException("Couldn't read that file.")
            if (!temp.renameTo(target)) {
                temp.copyTo(target, overwrite = true)
            }
        } finally {
            temp.delete()
        }
        return target.absolutePath
    }

    fun delete(path: String?) {
        path?.let { File(it).delete() }
    }

    /** Writes the QR at [path] to Pictures/Koban as a JPEG and returns its MediaStore uri. */
    fun saveToGallery(path: String, displayName: String): Uri {
        val bitmap = BitmapFactory.decodeFile(path) ?: throw IllegalArgumentException("That file isn't an image.")
        try {
            val resolver = context.contentResolver
            val collection = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.put(MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/Koban")
                values.put(MediaStore.MediaColumns.IS_PENDING, 1)
                val uri = resolver.insert(collection, values) ?: throw IOException("Couldn't save to gallery.")
                try {
                    resolver.openOutputStream(uri)?.use { writeJpeg(bitmap, it) }
                        ?: throw IOException("Couldn't save to gallery.")
                    resolver.update(uri, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
                } catch (e: Exception) {
                    resolver.delete(uri, null, null)
                    throw e
                }
                return uri
            }

            @Suppress("DEPRECATION")
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "Koban")
            dir.mkdirs()
            val file = File(dir, displayName)
            file.outputStream().use { writeJpeg(bitmap, it) }
            @Suppress("DEPRECATION")
            val dataColumn = MediaStore.MediaColumns.DATA
            // Saving again overwrites the file, so drop its old MediaStore row first.
            resolver.delete(collection, "$dataColumn = ?", arrayOf(file.absolutePath))
            values.put(dataColumn, file.absolutePath)
            return resolver.insert(collection, values) ?: throw IOException("Couldn't save to gallery.")
        } finally {
            bitmap.recycle()
        }
    }

    private fun writeJpeg(bitmap: Bitmap, out: OutputStream) {
        // JPEG has no alpha: put a transparent QR on white, or its background turns black.
        val opaque = if (bitmap.hasAlpha()) {
            Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888).also {
                Canvas(it).apply { drawColor(Color.WHITE); drawBitmap(bitmap, 0f, 0f, null) }
            }
        } else {
            bitmap
        }
        try {
            if (!opaque.compress(Bitmap.CompressFormat.JPEG, 95, out)) throw IOException("Couldn't save to gallery.")
        } finally {
            if (opaque !== bitmap) opaque.recycle()
        }
    }
}
