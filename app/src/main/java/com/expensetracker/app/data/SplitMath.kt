package com.expensetracker.app.data

import java.math.BigDecimal
import java.math.RoundingMode

const val ME_ID = "me"

data class SplitItemInput(val price: BigDecimal, val sharedBy: Set<String>)

/** [discount] is positive and subtracts from the total. [rounding] is signed. */
data class SplitCharges(
    val serviceCharge: BigDecimal = BigDecimal.ZERO,
    val tax: BigDecimal = BigDecimal.ZERO,
    val discount: BigDecimal = BigDecimal.ZERO,
    val rounding: BigDecimal = BigDecimal.ZERO,
)

object SplitMath {
    private const val PRECISION = 10

    private fun money(value: BigDecimal): BigDecimal = value.setScale(2, RoundingMode.HALF_UP)

    private fun netCharges(c: SplitCharges): BigDecimal =
        c.serviceCharge + c.tax - c.discount + c.rounding

    fun computedTotal(items: List<SplitItemInput>, charges: SplitCharges): BigDecimal =
        money(items.fold(BigDecimal.ZERO) { sum, item -> sum + item.price } + netCharges(charges))

    fun shares(items: List<SplitItemInput>, charges: SplitCharges): Map<String, BigDecimal> {
        require(unassignedItemIndexes(items).isEmpty()) { "Every item needs at least one person" }

        val subtotals = linkedMapOf(ME_ID to BigDecimal.ZERO)
        for (item in items) {
            val part = item.price.divide(BigDecimal(item.sharedBy.size), PRECISION, RoundingMode.HALF_UP)
            for (person in item.sharedBy) subtotals.merge(person, part, BigDecimal::add)
        }

        val extra = netCharges(charges)
        val subtotalSum = subtotals.values.fold(BigDecimal.ZERO, BigDecimal::add)
        val exact: Map<String, BigDecimal> = if (subtotalSum.signum() > 0) {
            subtotals.mapValues { (_, sub) ->
                sub + extra.multiply(sub).divide(subtotalSum, PRECISION, RoundingMode.HALF_UP)
            }
        } else {
            val people = items.flatMap { it.sharedBy }.toSet().ifEmpty { setOf(ME_ID) }
            val each = extra.divide(BigDecimal(people.size), PRECISION, RoundingMode.HALF_UP)
            subtotals.mapValues { (person, sub) -> if (person in people) sub + each else sub }
        }

        val result = linkedMapOf<String, BigDecimal>()
        var othersTotal = BigDecimal.ZERO
        for ((person, value) in exact) {
            if (person == ME_ID) continue
            result[person] = money(value)
            othersTotal += result.getValue(person)
        }
        result[ME_ID] = computedTotal(items, charges) - othersTotal
        return result
    }

    fun unassignedItemIndexes(items: List<SplitItemInput>): List<Int> =
        items.indices.filter { items[it].sharedBy.isEmpty() }

    fun ownerSpending(linkedAmount: BigDecimal, othersOwe: BigDecimal): BigDecimal =
        money((linkedAmount - othersOwe).max(BigDecimal.ZERO))
}
