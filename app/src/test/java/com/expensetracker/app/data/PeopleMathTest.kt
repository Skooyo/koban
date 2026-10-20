package com.expensetracker.app.data

import java.math.BigDecimal
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PeopleMathTest {
    private fun m(s: String) = BigDecimal(s)

    @Test fun net_subtractsWhatIOwe() =
        assertEquals(m("5.31"), PeopleMath.net(listOf(m("23.31")), listOf(m("18.00"))))

    @Test fun balance_paysYouWhenPositive() =
        assertEquals(Balance.PaysYou(m("5.31")), PeopleMath.balance(listOf(m("23.31")), listOf(m("18.00"))))

    @Test fun balance_youPayWhenNegative() =
        assertEquals(Balance.YouPay(m("18.00")), PeopleMath.balance(emptyList(), listOf(m("18.00"))))

    @Test fun status_evenWhenNetZeroWithOpenItems() =
        assertEquals(Balance.Even, PeopleMath.balance(listOf(m("10.00")), listOf(m("10.00"))))

    @Test fun status_allPaidWhenNothingOpen() =
        assertEquals(Balance.AllPaid, PeopleMath.balance(emptyList(), emptyList()))

    @Test fun headline_namesWhoPays() {
        assertEquals("Jun Wei pays you RM 5.31", PeopleMath.headline("Jun Wei", Balance.PaysYou(m("5.31"))))
        assertEquals("You pay Jun Wei RM 18.00", PeopleMath.headline("Jun Wei", Balance.YouPay(m("18.00"))))
    }

    @Test fun statusLine_noQrOnlyWhenAllPaid() {
        assertEquals("No QR saved yet", PeopleMath.statusLine("Daniel", Balance.AllPaid, hasQr = false))
        assertEquals("All paid", PeopleMath.statusLine("Aisyah", Balance.AllPaid, hasQr = true))
        assertEquals("You pay RM 18.00", PeopleMath.statusLine("Jun Wei", Balance.YouPay(m("18.00")), hasQr = false))
    }

    @Test fun group_ordersYouOweFirst() {
        assertEquals(PeopleMath.Group.YOU_OWE, PeopleMath.group(Balance.YouPay(m("1.00"))))
        assertEquals(PeopleMath.Group.OWES_YOU, PeopleMath.group(Balance.PaysYou(m("1.00"))))
        assertEquals(PeopleMath.Group.OTHERS, PeopleMath.group(Balance.Even))
    }

    @Test fun normalizedName_matchesCaseAndSpaces() =
        assertEquals(PeopleMath.normalizedName("jun wei"), PeopleMath.normalizedName("  Jun   Wei "))

    @Test fun settleMatch_singleCandidate() = assertEquals("p1",
        PeopleMath.settleMatch(m("5.31"), "SOMEONE", listOf(PeopleMath.SettleCandidate("p1", "Jun Wei", m("5.31")))))

    @Test fun settleMatch_senderBreaksTie() = assertEquals("p2", PeopleMath.settleMatch(m("5.31"), "PRIYA DEVI",
        listOf(PeopleMath.SettleCandidate("p1", "Jun Wei", m("5.31")), PeopleMath.SettleCandidate("p2", "Priya", m("5.31")))))

    @Test fun settleMatch_ambiguousWithoutSender_returnsNull() = assertNull(PeopleMath.settleMatch(m("5.31"), null,
        listOf(PeopleMath.SettleCandidate("p1", "Jun Wei", m("5.31")), PeopleMath.SettleCandidate("p2", "Priya", m("5.31")))))

    @Test fun settleMatch_ignoresPeopleIOwe() = assertNull(PeopleMath.settleMatch(m("5.31"), null,
        listOf(PeopleMath.SettleCandidate("p1", "Jun Wei", m("-5.31")))))
}
