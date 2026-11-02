package com.expensetracker.app.ui.viewmodel

import com.expensetracker.app.parser.ReceiptDraft
import com.expensetracker.app.parser.ReceiptRead
import java.math.BigDecimal
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SplitReadNoteTest {
    private fun read(accepted: Boolean, total: String?, calculated: List<String> = emptyList()) = ReceiptRead(
        ReceiptDraft(
            null, null, emptyList(), BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO,
            total?.let { BigDecimal(it) }
        ),
        accepted, calculated
    )

    @Test
    fun itemsNoteText() {
        assertEquals(
            "Matches the receipt total of RM 57.80.",
            SplitEditorViewModel.readNote(read(true, "57.80"))
        )
        assertEquals(
            "Matches the receipt total of RM 57.80 with a calculated 10% service charge and 6% SST.",
            SplitEditorViewModel.readNote(read(true, "57.80", listOf("10% service charge", "6% SST")))
        )
        assertEquals(
            "Matches the receipt total of RM 57.80 with a calculated 6% SST.",
            SplitEditorViewModel.readNote(read(true, "57.80", listOf("6% SST")))
        )
        assertNull(SplitEditorViewModel.readNote(read(false, null)))
        assertNull(SplitEditorViewModel.readNote(read(false, "57.80")))
    }
}
