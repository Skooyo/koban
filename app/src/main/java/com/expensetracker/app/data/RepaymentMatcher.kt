package com.expensetracker.app.data

import java.math.BigDecimal

/** One open debt of a person. Callers pass the list oldest first. */
data class OpenDebtRef(
    val debtId: String,
    val personId: String,
    val personName: String,
    val amount: BigDecimal,
)

object RepaymentMatcher {
    // ponytail: 2^12 subsets per person; switch to DP if people keep more open debts.
    private const val MAX_DEBTS_PER_PERSON = 12

    /** Returns the debt ids to close, in input order, or an empty list when no single person fits. */
    fun match(amount: BigDecimal, senderName: String?, openDebts: List<OpenDebtRef>): List<String> {
        val hits = openDebts.groupBy { it.personId }.values.mapNotNull { debts ->
            bestSubset(amount, debts.take(MAX_DEBTS_PER_PERSON))?.let { debts.first() to it }
        }
        val chosen = when {
            hits.size <= 1 -> hits
            else -> {
                val senderWords = words(senderName.orEmpty())
                hits.filter { (person, _) -> words(person.personName).any { it in senderWords } }
            }
        }
        return chosen.singleOrNull()?.second?.map { it.debtId } ?: emptyList()
    }

    /** Fewest debts wins; ties go to the subset with the earliest debts. */
    private fun bestSubset(amount: BigDecimal, debts: List<OpenDebtRef>): List<OpenDebtRef>? {
        var best: List<Int>? = null
        for (mask in 1 until (1 shl debts.size)) {
            val picked = debts.indices.filter { mask shr it and 1 == 1 }
            val sum = picked.fold(BigDecimal.ZERO) { acc, i -> acc + debts[i].amount }
            if (sum.compareTo(amount) != 0) continue
            val current = best
            if (current == null || isBetter(picked, current)) best = picked
        }
        return best?.map { debts[it] }
    }

    private fun isBetter(a: List<Int>, b: List<Int>): Boolean {
        if (a.size != b.size) return a.size < b.size
        return a.zip(b).firstOrNull { (x, y) -> x != y }?.let { (x, y) -> x < y } ?: false
    }

    internal fun words(text: String): Set<String> =
        text.lowercase().split(Regex("[^\\p{L}]+")).filter { it.length >= 3 }.toSet()
}
