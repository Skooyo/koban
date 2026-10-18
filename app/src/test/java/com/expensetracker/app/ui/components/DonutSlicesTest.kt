package com.expensetracker.app.ui.components

import com.expensetracker.app.data.CategoryBreakdown
import java.math.BigDecimal
import org.junit.Assert.assertEquals
import org.junit.Test

class DonutSlicesTest {
    private fun row(id: String?, name: String, total: String) =
        CategoryBreakdown(id, name, "#000000", BigDecimal(total), 0f)

    private fun List<DonutSlice>.summary() = map { "${it.name}=${it.total}${if (it.folded) "*" else ""}" }

    @Test
    fun slices_followFixedOrderAndFoldTheRest() = assertEquals(
        listOf("Food=30.00", "Bills=10.00", "Everything else=12.00*"),
        donutSlices(
            listOf(
                row("bills", "Bills", "10.00"),
                row("food", "Food", "30.00"),
                row("c1", "Pets", "5.00"),
                row(null, "Uncategorized", "7.00"),
            )
        ).summary(),
    )

    @Test
    fun slices_singleLeftoverKeepsItsName() = assertEquals(
        listOf("Food=30.00", "Uncategorized=7.00"),
        donutSlices(listOf(row(null, "Uncategorized", "7.00"), row("food", "Food", "30.00"))).summary(),
    )

    @Test
    fun slices_capAtSixBySmallestBuiltInFolding() = assertEquals(
        listOf("Food=60", "Health=50", "Transport=40", "Entertainment=30", "Shopping=20", "Everything else=15*"),
        donutSlices(
            listOf(
                row("food", "Food", "60"),
                row("health", "Health", "50"),
                row("transport", "Transport", "40"),
                row("entertainment", "Entertainment", "30"),
                row("shopping", "Shopping", "20"),
                row("bills", "Bills", "10"),
                row("other", "Other", "5"),
            )
        ).summary(),
    )
}
