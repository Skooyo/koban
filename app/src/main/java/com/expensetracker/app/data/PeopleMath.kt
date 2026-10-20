package com.expensetracker.app.data

import com.expensetracker.app.parser.AmountFormatter
import java.math.BigDecimal

sealed interface Balance {
    data class PaysYou(val amount: BigDecimal) : Balance
    data class YouPay(val amount: BigDecimal) : Balance
    data object Even : Balance
    data object AllPaid : Balance
}

/** Pure rules for the people list and person screen. */
object PeopleMath {
    enum class Group { YOU_OWE, OWES_YOU, OTHERS }

    data class SettleCandidate(val personId: String, val name: String, val net: BigDecimal)

    fun normalizedName(name: String): String =
        name.trim().replace(Regex("\\s+"), " ").lowercase()

    fun net(owedToMe: List<BigDecimal>, iOwe: List<BigDecimal>): BigDecimal =
        AmountFormatter.toMoney(owedToMe.fold(BigDecimal.ZERO, BigDecimal::add) - iOwe.fold(BigDecimal.ZERO, BigDecimal::add))

    fun balance(owedToMe: List<BigDecimal>, iOwe: List<BigDecimal>): Balance {
        if (owedToMe.isEmpty() && iOwe.isEmpty()) return Balance.AllPaid
        val net = net(owedToMe, iOwe)
        return when (net.signum()) {
            1 -> Balance.PaysYou(net)
            -1 -> Balance.YouPay(net.negate())
            else -> Balance.Even
        }
    }

    fun statusLine(name: String, balance: Balance, hasQr: Boolean): String = when (balance) {
        is Balance.PaysYou -> "Pays you ${money(balance.amount)}"
        is Balance.YouPay -> "You pay ${money(balance.amount)}"
        Balance.Even -> "You're even"
        Balance.AllPaid -> if (hasQr) "All paid" else "No QR saved yet"
    }

    fun headline(name: String, balance: Balance): String = when (balance) {
        is Balance.PaysYou -> "$name pays you ${money(balance.amount)}"
        is Balance.YouPay -> "You pay $name ${money(balance.amount)}"
        Balance.Even -> "You're even"
        Balance.AllPaid -> "All paid"
    }

    fun group(balance: Balance): Group = when (balance) {
        is Balance.YouPay -> Group.YOU_OWE
        is Balance.PaysYou -> Group.OWES_YOU
        else -> Group.OTHERS
    }

    /** The person whose positive net equals [amount]; the sender name breaks a tie. */
    fun settleMatch(amount: BigDecimal, senderName: String?, candidates: List<SettleCandidate>): String? {
        val hits = candidates.filter { it.net.signum() > 0 && it.net.compareTo(amount) == 0 }
        if (hits.size <= 1) return hits.singleOrNull()?.personId
        val senderWords = RepaymentMatcher.words(senderName.orEmpty())
        return hits.filter { h -> RepaymentMatcher.words(h.name).any { it in senderWords } }
            .singleOrNull()?.personId
    }

    private fun money(amount: BigDecimal) = "RM ${AmountFormatter.formatGrouped(amount)}"
}
