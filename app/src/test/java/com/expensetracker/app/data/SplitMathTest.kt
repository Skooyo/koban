package com.expensetracker.app.data

import java.math.BigDecimal
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class SplitMathTest {
    private fun item(price: String, vararg who: String) =
        SplitItemInput(BigDecimal(price), who.toSet())

    private val example = listOf(
        item("12.00", "me"),
        item("3.00", "a"),
        item("10.00", "me", "a", "b"),
    )
    private val exampleCharges =
        SplitCharges(serviceCharge = BigDecimal("2.50"), tax = BigDecimal("1.65"))

    @Test
    fun computedTotal_example() =
        assertEquals(BigDecimal("29.15"), SplitMath.computedTotal(example, exampleCharges))

    @Test
    fun shares_example() = assertEquals(
        mapOf("me" to BigDecimal("17.88"), "a" to BigDecimal("7.38"), "b" to BigDecimal("3.89")),
        SplitMath.shares(example, exampleCharges),
    )

    @Test
    fun shares_leftoverCentGoesToMe() = assertEquals(
        mapOf("me" to BigDecimal("3.34"), "a" to BigDecimal("3.33"), "b" to BigDecimal("3.33")),
        SplitMath.shares(listOf(item("10.00", "me", "a", "b")), SplitCharges()),
    )

    @Test
    fun shares_discountAndRoundingInProportion() {
        val result = SplitMath.shares(
            listOf(item("20.00", "me"), item("10.00", "a")),
            SplitCharges(discount = BigDecimal("3.00"), rounding = BigDecimal("-0.02")),
        )
        assertEquals(BigDecimal("8.99"), result["a"])
        assertEquals(BigDecimal("17.99"), result["me"])
    }

    @Test
    fun shares_zeroSubtotal_splitsChargesEvenly() {
        val result = SplitMath.shares(
            listOf(item("0.00", "me", "a")),
            SplitCharges(serviceCharge = BigDecimal("2.00")),
        )
        assertEquals(BigDecimal("1.00"), result["me"])
        assertEquals(BigDecimal("1.00"), result["a"])
    }

    @Test
    fun shares_rejectsUnassignedItem() {
        assertThrows(IllegalArgumentException::class.java) {
            SplitMath.shares(listOf(item("5.00", "me"), item("4.00")), SplitCharges())
        }
    }

    @Test
    fun unassignedItemIndexes_findsEmptyItems() =
        assertEquals(listOf(1), SplitMath.unassignedItemIndexes(listOf(item("5.00", "me"), item("4.00"))))

    @Test
    fun ownerSpending_subtractsFriends() =
        assertEquals(BigDecimal("40.00"), SplitMath.ownerSpending(BigDecimal("120.00"), BigDecimal("80.00")))

    @Test
    fun ownerSpending_neverNegative() =
        assertEquals(BigDecimal("0.00"), SplitMath.ownerSpending(BigDecimal("50.00"), BigDecimal("80.00")))
}
