package com.expensetracker.app.parser

import com.expensetracker.app.ui.viewmodel.SplitEditorViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test
import java.math.BigDecimal

class ReceiptCloudChoiceTest {
    private val reply = """{"merchant":"Ramen Shop","date":"2026-11-07",
        "items":[{"name":"Kimista (Large)","quantity":1,"price":"26.00"},{"name":"Ajitama","quantity":2,"price":"6.00"}],
        "serviceCharge":"0.00","tax":"2.28","discount":"0.00","rounding":"0.02","total":"34.30","readsLeftToday":7}"""

    private fun rulesRead(accepted: Boolean) = ReceiptRead(
        ReceiptDraft(null, null, listOf(ReceiptItemDraft("Ramen", 1, BigDecimal("34.30"))),
            BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal("34.30")),
        accepted, emptyList()
    )

    @Test
    fun parsesTheReplyAndChecksTheSum() {
        val read = ReceiptCloudClient.parse(reply)!!
        assertEquals(listOf("Kimista (Large)" to "26.00", "Ajitama" to "6.00"), read.draft.items.map { it.name to it.price.toPlainString() })
        assertEquals(2, read.draft.items[1].quantity)
        assertEquals("34.30", read.draft.printedTotal!!.toPlainString())
        assertEquals(true, read.accepted)
        assertEquals(false, ReceiptCloudClient.parse(reply.replace("\"34.30\"", "\"35.30\""))!!.accepted)
        assertNull(ReceiptCloudClient.parse("""{"items": "none"}"""))
    }

    @Test
    fun claudeWinsWhenItAddsUpElseTheRulesWhenTheyDo() {
        val claudeOk = CloudRead.Ok(ReceiptCloudClient.parse(reply)!!, 7)
        val claudeOff = CloudRead.Ok(ReceiptCloudClient.parse(reply.replace("\"34.30\"", "\"35.30\""))!!, 6)
        val good = rulesRead(true)
        val bad = rulesRead(false)

        assertEquals(claudeOk.read to "✓ Read by Claude · 7 reads left today", SplitEditorViewModel.choose(good, claudeOk))
        assertSame(good, SplitEditorViewModel.choose(good, claudeOff).first)
        assertSame(claudeOff.read, SplitEditorViewModel.choose(bad, claudeOff).first)
        assertEquals(
            bad to "Read on the phone. You used your 10 Claude reads for today.",
            SplitEditorViewModel.choose(bad, CloudRead.Failed("You used your 10 Claude reads for today."))
        )
        assertEquals(bad to null, SplitEditorViewModel.choose(bad, null))
    }
}
