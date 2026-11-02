package com.expensetracker.app.parser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigDecimal
import java.util.Calendar

class ReceiptRulesTest {
    private fun row(y: Int, vararg parts: Pair<Int, String>) =
        parts.map { (x, text) -> OcrLine(text, x, y, x + 100, y + 20) }

    private fun items(vararg rows: String) = ReceiptRules.parse(rows.toList()).items

    private fun item(name: String, qty: Int, price: String) =
        ReceiptItemDraft(name, qty, BigDecimal(price))

    @Test
    fun nameAndPriceLinesJoinIntoOneRow() {
        val lines = row(100, 10 to "NASI LEMAK") + row(102, 300 to "8.50")
        assertEquals(listOf("NASI LEMAK 8.50"), ReceiptRules.rows(lines))
    }

    @Test
    fun amountRepair() {
        assertEquals("TEH TARIK 2 x 2.50 5.00", ReceiptRules.fixRow("TEH TARIK 2 x 2.50 5 00"))
        assertEquals("SUBTOTAL. 79.60", ReceiptRules.fixRow("SUBTOTAL. 79, 60"))
        assertEquals("Rounding Adj : -0.03", ReceiptRules.fixRow("Rounding Adj : -0. 03"))
        assertEquals("ROTI 10.50", ReceiptRules.fixRow("ROTI 1O.50"))
    }

    @Test
    fun thousandsSeparatorKept() {
        assertEquals("TOTAL 1,234.00", ReceiptRules.fixRow("TOTAL 1,234.00"))
    }

    @Test
    fun timeRowIsNotAnItem() {
        assertEquals(
            listOf(item("MEE GORENG", 1, "7.00")),
            items("Time: 12:06 00", "MEE GORENG 7.00", "TOTAL 7.00")
        )
    }

    @Test
    fun fuzzyLabels() {
        assertTrue("SUBTOTAL" in ReceiptRules.normLabel("SULTOTAL."))
        assertTrue("AMOUNT" in ReceiptRules.normLabel("Total Amnolunt :"))
        assertTrue("TOTAL" in ReceiptRules.normLabel("NLI T0TAL"))
    }

    @Test
    fun itemNameNearKeywordStaysItem() {
        assertEquals(
            listOf(item("PHONE CASE", 1, "10.00"), item("EXCHANGE TEA", 1, "3.00")),
            items("PHONE CASE 10.00", "EXCHANGE TEA 3.00", "TOTAL 13.00")
        )
    }

    @Test
    fun restaurantBill() {
        val p = ReceiptRules.parse(
            listOf(
                "TEH O AIS", "1X 2.50 2.50 SR", "NASI AYAM", "2X 9.00 18.00 SR",
                "TOTAL (EXCLUDING SST): 20.50", "SERV. CHARGE(10%): 2.05", "SST PAYABLE: 1.35",
                "TOTAL (INCLUSIVE OF SST): 23.90", "ROUNDING ADJ: 0.00", "TOTAL: 23.90",
                "CASH : 50.00", "CHANGE : 26.10"
            )
        )
        assertEquals(listOf(item("TEH O AIS", 1, "2.50"), item("NASI AYAM", 2, "18.00")), p.items)
        assertEquals(BigDecimal("20.50"), p.subtotal)
        assertEquals(BigDecimal("2.05"), p.serviceCharge)
        assertEquals(BigDecimal("1.35"), p.tax)
        assertEquals(BigDecimal("0.00"), p.rounding)
        assertEquals(listOf(BigDecimal("23.90"), BigDecimal("23.90")), p.totals)
    }

    @Test
    fun tiltedScanPairsEachPriceWithTheNameBelow() {
        val p = ReceiptRules.parse(
            listOf(
                "Qty Description Total TAX", "1 0 40.00 SR", "Fish Noodle", "D 12.00 SR", "Green Tea",
                "1 D 6.50 SR", "Plain Rice", "1 D 3.00 SR", "Soda",
                "Total (Excluding GST): 61.50", "Total: 61.50"
            )
        )
        assertEquals(
            listOf(item("Fish Noodle", 1, "40.00"), item("Green Tea", 1, "12.00"), item("Plain Rice", 1, "6.50"), item("Soda", 1, "3.00")),
            p.items
        )
    }

    @Test
    fun taxCodesAndDollar() {
        val p = ReceiptRules.parse(
            listOf("COKE", "1 X 2.10 2.10 ZRL", "MEAT + VEGE", "1 \$7.10", "\$7.10", "NETT TOTAL: \$9.20")
        )
        assertEquals(listOf(item("COKE", 1, "2.10"), item("MEAT + VEGE", 1, "7.10")), p.items)
        assertEquals(listOf(BigDecimal("9.20")), p.totals)
    }

    @Test
    fun namelessItems() {
        assertEquals(
            listOf(item("Item", 4, "14.00"), item("Item", 1, "3.00")),
            items("4 3.50 14.00 SR-", "1 3.00 3.00 SR-", "TOTAL: 17.00")
        )
    }

    @Test
    fun stopsAtSummary() {
        assertEquals(
            listOf(item("TEA", 1, "3.00")),
            items("TEA 3.00", "GST SUMMARY AMOUNT(RM) TAX(RM)", "COFFEE 4.00", "TOTAL 7.00")
        )
    }

    private fun lines(vararg rows: String) =
        rows.flatMapIndexed { i, text -> row(i * 40, 10 to text) }

    private fun read(vararg rows: String, now: Long = Long.MAX_VALUE) = ReceiptRules.read(lines(*rows), now)!!

    private fun midnight(y: Int, m: Int, d: Int) =
        Calendar.getInstance().apply { clear(); set(y, m - 1, d, 0, 0, 0) }.timeInMillis

    @Test
    fun reading1_pricesIncludeEverything() {
        val r = read("ROTI 10.00", "TEH 5.00", "SST 6% INCLUDED 0.85", "TOTAL 15.00")
        assertTrue(r.accepted)
        assertEquals(BigDecimal("0.00"), r.draft.tax)
        assertEquals(BigDecimal("0.00"), r.draft.serviceCharge)
        assertEquals(emptyList<String>(), r.calculated)
    }

    @Test
    fun reading4_chargesAdded() {
        val r = read(
            "TEH O AIS", "1X 2.50 2.50 SR", "NASI AYAM", "2X 9.00 18.00 SR",
            "TOTAL (EXCLUDING SST): 20.50", "SERV. CHARGE(10%): 2.05", "SST PAYABLE: 1.35",
            "TOTAL (INCLUSIVE OF SST): 23.90", "ROUNDING ADJ: 0.00", "TOTAL: 23.90",
            "CASH : 50.00", "CHANGE : 26.10"
        )
        assertTrue(r.accepted)
        assertEquals(BigDecimal("2.05"), r.draft.serviceCharge)
        assertEquals(BigDecimal("1.35"), r.draft.tax)
        assertEquals(BigDecimal("23.90"), r.draft.printedTotal)
        assertEquals(emptyList<String>(), r.calculated)
    }

    @Test
    fun reading5_taxAlreadyInPrices() {
        val r = read("MEE 20.00", "SERVICE CHARGE 2.00", "SST 6% 1.25", "TOTAL 22.00")
        assertTrue(r.accepted)
        assertEquals(BigDecimal("0.00"), r.draft.tax)
        assertEquals(BigDecimal("2.00"), r.draft.serviceCharge)
    }

    @Test
    fun reading6_missingServiceChargeCalculated() {
        val r = read("SET A 79.60", "DISCOUNT 30.00", "ROUNDING -0.03", "TOTAL 57.80")
        assertTrue(r.accepted)
        assertEquals(BigDecimal("4.96"), r.draft.serviceCharge)
        assertEquals(BigDecimal("3.27"), r.draft.tax)
        assertEquals(listOf("10% service charge", "6% SST"), r.calculated)
    }

    @Test
    fun fiveSenRounding() {
        val r = read("KUIH 7.72", "TOTAL 7.70")
        assertTrue(r.accepted)
        assertEquals(BigDecimal("-0.02"), r.draft.rounding)
    }

    @Test
    fun nearMatchPutsCentInRounding() {
        val r = read("ROTI 10.00", "TEH 13.90", "TOTAL 23.89")
        assertTrue(r.accepted)
        assertEquals(BigDecimal("-0.01"), r.draft.rounding)
        val d = r.draft
        val sum = d.items.fold(BigDecimal.ZERO) { a, i -> a + i.price } + d.serviceCharge + d.tax - d.discount + d.rounding
        assertEquals(0, sum.compareTo(d.printedTotal))
    }

    @Test
    fun subtotalNeverAccepts() {
        val r = read("BARANG 295.00", "SUB TOTAL 295.00", "TOTAL 350.00")
        assertFalse(r.accepted)
        assertEquals(BigDecimal("350.00"), r.draft.printedTotal)
    }

    @Test
    fun lastTotalWins() {
        val r = read("MEE 20.00", "TOTAL 20.00", "SERVICE CHARGE 2.00", "TOTAL 22.00")
        assertTrue(r.accepted)
        assertEquals(BigDecimal("22.00"), r.draft.printedTotal)
        assertEquals(BigDecimal("2.00"), r.draft.serviceCharge)
    }

    @Test
    fun noTotalNotAccepted() {
        val r = read("MEE 20.00")
        assertFalse(r.accepted)
        assertNull(r.draft.printedTotal)
    }

    @Test
    fun emptyOcrGivesNull() {
        assertNull(ReceiptRules.read(emptyList()))
        assertNull(ReceiptRules.read(lines("THANK YOU")))
    }

    @Test
    fun zeroAmountsIgnored() {
        val r = read("NASI 12.00", "FREE SAMBAL 0.00", "DISCOUNT 0.00", "TOTAL 12.00")
        assertTrue(r.accepted)
        assertEquals(1, r.draft.items.size)
    }

    @Test
    fun merchantAndDate() {
        val top = arrayOf(
            "KEDAI MAKAN CONTOH", "SDN BHD (123456-X)", "NO. 1 JALAN CONTOH", "TEL: 03-1234 5678",
            "DATE: 05/10/2026 13:05", "MEE 5.00", "TOTAL 5.00"
        )
        val now = midnight(2026, 11, 2)
        val r = read(*top, now = now)
        assertEquals("KEDAI MAKAN CONTOH", r.draft.merchant)
        assertEquals(midnight(2026, 10, 5), r.draft.dateMillis)
        assertNull(read("MEE 5.00", "DATE: 31/02/2026", "TOTAL 5.00", now = now).draft.dateMillis)
        assertNull(read("MEE 5.00", "DATE: 03/11/2026", "TOTAL 5.00", now = now).draft.dateMillis)
        assertEquals(midnight(2026, 10, 5), read("MEE 5.00", "5 Oct 2026", "TOTAL 5.00", now = now).draft.dateMillis)
        assertEquals(midnight(2026, 10, 5), read("MEE 5.00", "2026-10-05", "TOTAL 5.00", now = now).draft.dateMillis)
    }

    @Test
    fun amountOfThousandsWithoutCommaKeepsAllDigits() {
        assertEquals(listOf(BigDecimal("1234.00")), ReceiptRules.parse(listOf("TOTAL 1234.00")).totals)
        assertEquals(listOf(BigDecimal("1234.00")), ReceiptRules.parse(listOf("TOTAL 1,234.00")).totals)
    }

    @Test
    fun bigItemWithoutCommaIsAccepted() {
        val r = read("BANQUET SET 1250.00", "TOTAL RM1250.00")
        assertTrue(r.accepted)
        assertEquals(listOf(item("BANQUET SET", 1, "1250.00")), r.draft.items)
        assertEquals(BigDecimal("1250.00"), r.draft.printedTotal)
    }

    @Test
    fun discountKeywordInsideItemNameIsAnItem() {
        assertEquals(
            listOf(item("TEH LESS SUGAR", 1, "3.00"), item("SET PROMO A", 1, "9.00")),
            items("TEH LESS SUGAR 3.00", "SET PROMO A 9.00", "TOTAL 12.00")
        )
        val p = ReceiptRules.parse(listOf("ROTI 5.00", "DISCOUNT 1.00", "PROMO -0.50", "TOTAL 3.50"))
        assertEquals(BigDecimal("1.50"), p.discount)
    }
}
