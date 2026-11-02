package com.expensetracker.app.ui.viewmodel

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class CacheFileTest {
    private val cache = File("build/tmp/cachetest")

    @Test fun fileInsideCacheIsOurs() =
        assertTrue(SplitEditorViewModel.isCacheFile("file", File(cache, "mlkit/scan.jpg").path, cache))

    @Test fun contentUriIsNeverOurs() =
        assertFalse(SplitEditorViewModel.isCacheFile("content", File(cache, "scan.jpg").path, cache))

    @Test fun fileOutsideCacheIsNotOurs() =
        assertFalse(SplitEditorViewModel.isCacheFile("file", File("build/tmp/other/scan.jpg").path, cache))

    @Test fun dotDotEscapeIsNotOurs() =
        assertFalse(SplitEditorViewModel.isCacheFile("file", File(cache, "../other/scan.jpg").path, cache))

    @Test fun cacheDirItselfIsNotOurs() =
        assertFalse(SplitEditorViewModel.isCacheFile("file", cache.path, cache))
}
