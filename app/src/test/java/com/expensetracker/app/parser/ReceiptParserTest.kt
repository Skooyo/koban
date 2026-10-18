package com.expensetracker.app.parser

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.math.BigDecimal
import java.util.Calendar

class ReceiptParserTest {

    private fun parse(json: String) = ReceiptParser.parseModelContent(json)

    @Test
    fun parse_fullReceipt() {
        val draft = parse(
            """{"merchant":"KK Super Mart","date":"2026-10-18",
            "items":[{"name":"Milo","quantity":1,"price":5.00},
            {"name":"Bread","quantity":2,"price":8.00},
            {"name":"Satay","quantity":10,"price":10.00}],
            "serviceCharge":2.50,"tax":1.65,"discount":0,"rounding":0,"total":29.15}"""
        )!!
        assertEquals(3, draft.items.size)
        assertEquals(ReceiptItemDraft("Satay", 10, BigDecimal("10.00")), draft.items[2])
        assertEquals(BigDecimal("2.50"), draft.serviceCharge)
        assertEquals(BigDecimal("1.65"), draft.tax)
        assertEquals(BigDecimal("29.15"), draft.printedTotal)
        assertEquals("KK Super Mart", draft.merchant)
    }

    @Test
    fun parse_stringAmounts() {
        val draft = parse(
            """{"items":[{"name":"Fish","quantity":1,"price":"RM 1,234.50"}],"tax":"6.00"}"""
        )!!
        assertEquals(BigDecimal("1234.50"), draft.items[0].price)
        assertEquals(BigDecimal("6.00"), draft.tax)
    }

    @Test
    fun parse_nullChargesBecomeZero() {
        val draft = parse("""{"items":[],"serviceCharge":null}""")!!
        assertEquals(BigDecimal("0.00"), draft.serviceCharge)
        assertEquals(BigDecimal("0.00"), draft.rounding)
        assertNull(draft.printedTotal)
    }

    @Test
    fun parse_negativeDiscountStoredPositive() {
        assertEquals(BigDecimal("3.00"), parse("""{"items":[],"discount":-3}""")!!.discount)
    }

    @Test
    fun parse_skipsItemsWithoutNameOrPrice() {
        val draft = parse(
            """{"items":[{"name":"","price":5},{"name":"Tea","price":null}]}"""
        )!!
        assertEquals(emptyList<ReceiptItemDraft>(), draft.items)
    }

    @Test
    fun parse_skipsZeroPriceItems() {
        val draft = parse("""{"items":[{"name":"Bag","price":0},{"name":"Tea","price":2.50}]}""")!!
        assertEquals(listOf(ReceiptItemDraft("Tea", 1, BigDecimal("2.50"))), draft.items)
    }

    @Test
    fun parse_quantityDefaultsToOne() {
        val draft = parse(
            """{"items":[{"name":"A","price":1},{"name":"B","quantity":0,"price":2},
            {"name":"C","quantity":-2,"price":3}]}"""
        )!!
        assertEquals(listOf(1, 1, 1), draft.items.map { it.quantity })
    }

    @Test
    fun parse_dateToLocalMidnight() {
        val expected = Calendar.getInstance().apply {
            clear()
            set(2026, Calendar.OCTOBER, 18, 0, 0, 0)
        }.timeInMillis
        assertEquals(expected, parse("""{"items":[],"date":"2026-10-18"}""")!!.dateMillis)
        assertNull(parse("""{"items":[],"date":"18/10"}""")!!.dateMillis)
    }

    @Test
    fun parse_brokenJsonReturnsNull() {
        assertNull(parse("not json"))
    }

    @Test
    fun parseGenerateContentBody_readsFirstCandidateText() {
        val text = """{"merchant":"Cafe","items":[{"name":"Tea","price":3.5}],"total":3.50}"""
        val body = JSONObject().put(
            "candidates",
            JSONArray().put(
                JSONObject().put(
                    "content",
                    JSONObject().put("parts", JSONArray().put(JSONObject().put("text", text)))
                )
            )
        ).toString()
        val draft = ReceiptParser.parseGenerateContentBody(body)!!
        assertEquals("Cafe", draft.merchant)
        assertEquals(BigDecimal("3.50"), draft.items[0].price)
        assertEquals(BigDecimal("3.50"), draft.printedTotal)
    }
}
