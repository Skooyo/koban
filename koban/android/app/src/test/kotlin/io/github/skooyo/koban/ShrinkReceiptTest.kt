package io.github.skooyo.koban

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.ExifInterface
import androidx.test.core.app.ApplicationProvider
import java.io.File
import java.util.concurrent.Executor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ShrinkReceiptTest {
    private val device = "io.github.skooyo.koban/device"
    private lateinit var context: Context
    private lateinit var messenger: FakeMessenger

    @Before fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        messenger = FakeMessenger()
        KobanNativePlugin(Executor { it.run() }).register(context, messenger)
    }

    private fun jpeg(name: String, width: Int, height: Int): File {
        val file = File(context.cacheDir, name)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 80, it) }
        bitmap.recycle()
        return file
    }

    private fun shrunk(file: File): Pair<Int, Int> {
        val bytes = messenger.call(device, "shrinkReceipt", mapOf("path" to file.path)) as ByteArray
        val b = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        return b.width to b.height
    }

    @Test fun aLargePhotoBecomes1600PixelsOnTheLongSide() {
        assertEquals(1600 to 1200, shrunk(jpeg("big.jpg", 4000, 3000)))
    }

    @Test fun aPhotoWithExifRotationComesUpright() {
        val file = jpeg("turned.jpg", 4000, 3000)
        ExifInterface(file.path).apply {
            setAttribute(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_ROTATE_90.toString())
            saveAttributes()
        }
        assertEquals(1200 to 1600, shrunk(file))
    }

    @Test fun aSmallPhotoKeepsItsSize() {
        assertEquals(800 to 600, shrunk(jpeg("small.jpg", 800, 600)))
    }

    @Test fun aFileThatIsNotAnImageGivesNull() {
        val file = File(context.cacheDir, "note.jpg").also { it.writeText("not a picture") }
        assertNull(messenger.call(device, "shrinkReceipt", mapOf("path" to file.path)))
    }
}
