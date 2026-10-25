package com.expensetracker.app.ui.viewmodel

import org.junit.Assert.assertEquals
import org.junit.Test

class PaymentAppsRulesTest {
    private fun app(pkg: String, label: String) = InstalledApp(pkg, label, null)

    @Test
    fun preselectedAppsComeFirstThenLabelOrder() {
        val sorted = sortApps(
            listOf(app("c", "Zed"), app("tng", "Touch n Go"), app("a", "apple"), app("mb", "Maybank")),
            setOf("mb", "tng")
        )
        assertEquals(listOf("mb", "tng", "a", "c"), sorted.map { it.packageName })
    }

    @Test
    fun firstOpenTicksInstalledPreselectedOnly() {
        assertEquals(setOf("mb"), initialSelection(false, setOf("x"), setOf("mb", "x"), setOf("mb", "tng")))
    }

    @Test
    fun laterOpenTicksStoredAllowlist() {
        assertEquals(setOf("x"), initialSelection(true, setOf("x"), setOf("mb", "x"), setOf("mb", "tng")))
        assertEquals(emptySet<String>(), initialSelection(true, emptySet(), setOf("mb"), setOf("mb")))
    }
}
