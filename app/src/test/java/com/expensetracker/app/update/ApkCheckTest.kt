package com.expensetracker.app.update

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ApkCheckTest {
    @Test fun rightPackageAndVersion() = assertTrue(ApkCheck.matches("io.github.skooyo.koban", 7, "io.github.skooyo.koban", 7))

    @Test fun otherPackage() = assertFalse(ApkCheck.matches("com.evil.app", 7, "io.github.skooyo.koban", 7))

    @Test fun otherVersion() = assertFalse(ApkCheck.matches("io.github.skooyo.koban", 6, "io.github.skooyo.koban", 7))

    @Test fun notAnApk() = assertFalse(ApkCheck.matches(null, null, "io.github.skooyo.koban", 7))
}
