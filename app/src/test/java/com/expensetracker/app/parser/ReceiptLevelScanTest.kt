package com.expensetracker.app.parser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import java.math.BigDecimal

/**
 * A real phone scan (document scanner, 2026-11-12) of a level but slightly curled receipt: prices sit level with
 * their names, yet ML Kit reports +0.6 to +1.3 degrees on some wide lines. Straightening this scan shifts every
 * price one item down, so the plain read must win. OCR misread "3.00" as "300," and the SST as "7.63", so the
 * read is not accepted. Shop name, address, phone and invoice number are changed.
 */
class ReceiptLevelScanTest {
    private val lines = listOf(
        OcrLine("QUy tem", 124, 943, 380, 998, -0.5007841f),
        OcrLine("TEST RAMEN (SS15)", 470, 165, 1246, 249, 2.6312964f),
        OcrLine("NO. 1 JAL AN TEST 1/1, 47500, SUBANG JAYA, SELANGOR", 173, 339, 1565, 523, 3.9854946f),
        OcrLine("1", 137, 1343, 158, 1384, 0.0f),
        OcrLine("Rey o. 200001000001 (I00 001 x)", 422, 280, 1292, 363, 2.2068553f),
        OcrLine("\$S1 N0: B00-000 00000000", 533, 345, 1209, 415, 1.9026492f),
        OcrLine("nvo hR10001", 162, 655, 584, 717, 2.726742f),
        OcrLine("Date. 07/11/2026 1304", 130, 711, 735, 784, 2.734995f),
        OcrLine("Role.cashter: Cashler", 151, 768, 667, 842, 2.853199f),
        OcrLine("Table pax: 1", 127, 829, 430, 895, 3.1574094f),
        OcrLine("6", 160, 1635, 183, 1674, 0.0f),
        OcrLine("Kimtsla (Large) (26.00/ea)", 267, 1059, 954, 1134, 1.2610381f),
        OcrLine("Klmista (Simall) (24.00/e a)", 268, 1126, 961, 1194, 0.56298876f),
        OcrLine("1 Nagoya Mazesoba DX (Large})", 132, 1203, 1024, 1264, 0.0f),
        OcrLine("(35.00/ea)", 271, 1269, 536, 1330, 0.77093077f),
        OcrLine("DARUL EHSAN MAI.AYSIA", 541, 464, 1191, 523, 1.1435944f),
        OcrLine("+60300000|00", 693, 528, 1050, 578, 1.2193583f),
        OcrLine("(34.00/ea)", 280, 1403, 539, 1460, 0.0f),
        OcrLine("test@example.com", 553, 579, 1221, 646, 1.4077457f),
        OcrLine("Doniku Nagoya Mazesoba (Large)", 275, 1334, 1122, 1395, 0.0f),
        OcrLine("Qty", 292, 1638, 371, 1692, 0.0f),
        OcrLine("Subtotal", 292, 1697, 490, 1744, 0.0f),
        OcrLine("Korokke (5.50/ea)", 283, 1467, 741, 1521, 0.0f),
        OcrLine("Ajitama (3.00/ea)", 286, 1525, 728, 1585, 0.0f),
        OcrLine("SST (6%)", 289, 1756, 504, 1817, 1.2200546f),
        OcrLine("Bill rounding", 312, 1819, 588, 1886, 1.3926101f),
        OcrLine("Total (MYR)", 280, 1936, 713, 2028, 0.82378983f),
        OcrLine("Change", 276, 2102, 518, 2174, 0.5044462f),
        OcrLine("TOUCH N GO", 279, 2036, 601, 2084, 0.0f),
        OcrLine("Charges summary", 134, 2234, 591, 2292, 0.5359168f),
        OcrLine("SST 6%", 134, 2302, 319, 2348, 0.0f),
        OcrLine("This is an officlal recelpt.", 583, 2448, 1167, 2507, 0.0f),
        OcrLine("Feedback & e-Invoice >>", 125, 2584, 705, 2634, 0.0f),
        OcrLine("Bose Amt.", 1038, 2230, 1283, 2276, 0.0f),
        OcrLine("127.50", 1126, 2291, 1283, 2340, -0.836593f),
        OcrLine("ORDER", 1267, 711, 1429, 754, 1.8005936f),
        OcrLine("Scan the QR code to rate your experlence and", 122, 2641, 1203, 2708, 0.0f),
        OcrLine("download your e-Invoice.", 119, 2712, 716, 2772, 0.0f),
        OcrLine("14A", 1269, 791, 1451, 864, 0.0f),
        OcrLine("Thank you lor vislting us We hope u ste yau ajaln &n'", 374, 2513, 1362, 2560, 0.0f),
        OcrLine("POWLRED DYLEEDMI SMA:2!", 565, 2905, 1080, 2958, -1.0364349f),
        OcrLine("Scan the QR cude lo gei yoụr e lnyo ee i avdilabta fronn", 136, 2760, 1269, 2826, -0.92341346f),
        OcrLine("30 ninufes after payment iintl the etnd of ihe oath", 115, 2814, 1156, 2882, -1.1129439f),
        OcrLine("Price (MYR)", 1328, 967, 1606, 1016, 0.9129626f),
        OcrLine("26.00", 1488, 1075, 1617, 1115, 0.0f),
        OcrLine("24.00", 1490, 1140, 1619, 1181, 0.0f),
        OcrLine("35.00", 1488, 1204, 1620, 1249, 0.0f),
        OcrLine("34.00", 1476, 1334, 1605, 1376, 0.0f),
        OcrLine("5.50", 1499, 1464, 1598, 1504, 0.0f),
        OcrLine("300,", 1514, 1523, 1614, 1574, 0.0f),
        OcrLine("127.50", 1433, 1701, 1587, 1742, 0.0f),
        OcrLine("7.63", 1488, 1761, 1637, 1812, -1.4202039f),
        OcrLine("0.00", 1488, 1826, 1588, 1868, 0.0f),
        OcrLine("135.15", 1345, 1946, 1588, 2007, 0.0f),
        OcrLine("135.15", 1429, 2034, 1590, 2078, 0.0f),
        OcrLine("0.00", 1453, 2101, 1586, 2156, -0.5451608f),
        OcrLine("Amount", 1404, 2230, 1588, 2273, 0.0f),
        OcrLine("7.65", 1489, 2291, 1589, 2336, 0.0f),
    )

    @Test
    fun levelScanKeepsThePlainRead() {
        val read = ReceiptRules.read(lines, now = Long.MAX_VALUE)!!
        assertFalse(read.accepted)
        assertEquals(
            listOf("Kimtsla (Large)" to "26.00", "Klmista (Simall)" to "24.00", "Nagoya Mazesoba DX (Large})" to "35.00",
                "Doniku Nagoya Mazesoba (Large)" to "34.00", "Korokke" to "5.50"),
            read.draft.items.map { it.name to it.price.toPlainString() }
        )
        assertEquals(BigDecimal("135.15"), read.draft.printedTotal)
    }
}
