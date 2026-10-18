package com.expensetracker.app.data

import java.math.BigDecimal
import org.junit.Assert.assertEquals
import org.junit.Test

class RepaymentMatcherTest {
    private fun debt(id: String, personId: String, name: String, amount: String) =
        OpenDebtRef(id, personId, name, BigDecimal(amount))

    @Test
    fun match_singleDebtExact() = assertEquals(
        listOf("d1"),
        RepaymentMatcher.match(BigDecimal("7.38"), null, listOf(debt("d1", "a", "Aisyah", "7.38"))),
    )

    @Test
    fun match_severalWholeDebtsSamePerson() = assertEquals(
        listOf("d1", "d2"),
        RepaymentMatcher.match(
            BigDecimal("19.38"),
            null,
            listOf(debt("d1", "a", "Aisyah", "7.38"), debt("d2", "a", "Aisyah", "12.00")),
        ),
    )

    @Test
    fun match_neverMixesPeople() = assertEquals(
        emptyList<String>(),
        RepaymentMatcher.match(
            BigDecimal("11.27"),
            null,
            listOf(debt("d1", "a", "Aisyah", "7.38"), debt("d2", "b", "Ben", "3.89")),
        ),
    )

    private val tie = listOf(
        debt("da", "a", "Aisyah", "10.00"),
        debt("db", "b", "Ben", "10.00"),
    )

    @Test
    fun match_prefersNameMatch() = assertEquals(
        listOf("da"),
        RepaymentMatcher.match(BigDecimal("10"), "AISYAH NUR RAHMAN", tie),
    )

    @Test
    fun match_ambiguousWithoutName_returnsEmpty() = assertEquals(
        emptyList<String>(),
        RepaymentMatcher.match(BigDecimal("10.00"), null, tie),
    )

    @Test
    fun match_noSubset_returnsEmpty() = assertEquals(
        emptyList<String>(),
        RepaymentMatcher.match(
            BigDecimal("7.00"),
            null,
            listOf(debt("d1", "a", "Aisyah", "7.38")),
        ),
    )
}
