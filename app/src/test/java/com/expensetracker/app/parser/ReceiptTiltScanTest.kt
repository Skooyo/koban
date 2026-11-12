package com.expensetracker.app.parser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigDecimal

/**
 * A real phone scan (document scanner, 2026-11-12) tilted by about -3 degrees: every price sits about
 * 60 px above its item name. Shop name, address, phone and email are changed.
 */
class ReceiptTiltScanTest {
    private val lines = listOf(
        OcrLine("Qty Item", 82, 1078, 384, 1155, -3.150235f),
        OcrLine("1", 122, 1398, 143, 1442, 0.0f),
        OcrLine("TEST RAMEN (SS15)", 492, 152, 1385, 222, 0.8633801f),
        OcrLine("TEST FOOD SDN BHD", 644, 223, 1239, 277, 0.0f),
        OcrLine("NO.1 JAL AN TEST 1/1, 47500, SUBANG JAYA, SELANGOR", 139, 363, 1720, 542, 2.6593058f),
        OcrLine("Reg no. 200001000001 (100001-X", 435, 286, 1435, 350, 0.0f),
        OcrLine("ST NO: B00-0000 00000000", 600, 349, 1344, 408, 0.0f),
        OcrLine("6", 200, 1845, 228, 1885, 0.0f),
        OcrLine("tnvoc n10001", 90, 735, 617, 800, -1.6647011f),
        OcrLine("Date. 07/1 |/2026 1304", 88, 790, 793, 876, -2.102547f),
        OcrLine("Role cashter: Cashler", 85, 864, 715, 942, -1.9809605f),
        OcrLine("Table pax. 1", 84, 948, 450, 1016, -1.1484855f),
        OcrLine("DARUL EHSAN, MALLAYSJA", 574, 475, 1319, 542, -0.7150174f),
        OcrLine("+60300000| 00", 750, 539, 1164, 601, -2.329955f),
        OcrLine(",test@example.com", 565, 609, 1353, 674, -0.6095095f),
        OcrLine("Kimisla (Large) {26.00/ea)", 262, 1181, 1043, 1292, -3.0025706f),
        OcrLine("Kimista (Smal) (24.00/ea)", 295, 1252, 1046, 1371, -3.465116f),
        OcrLine("Nagoya Mazesoba DX (Large)", 277, 1327, 1117, 1445, -3.4943957f),
        OcrLine("(35 03/ea)", 288, 1439, 585, 1514, -3.6911335f),
        OcrLine("Doniku Nagoya Mazesoba (Large)", 299, 1464, 1226, 1578, -3.397643f),
        OcrLine("(34.00/ea)", 315, 1567, 598, 1642, -3.4805686f),
        OcrLine("Qty", 346, 1836, 431, 1890, 0.0f),
        OcrLine("Subtotal", 347, 1887, 561, 1949, -3.0711343f),
        OcrLine("Korokke (5.50/ea)", 323, 1619, 821, 1706, -3.3747635f),
        OcrLine("Ajitama (3.00/ea)", 333, 1686, 812, 1780, -3.600609f),
        OcrLine("SST (6%)", 350, 1956, 579, 2025, -2.2220633f),
        OcrLine("Bill rounding", 379, 2019, 664, 2091, -1.3795812f),
        OcrLine("Total (MYR)", 342, 2138, 795, 2243, -1.6558771f),
        OcrLine("TOUCH N GO", 337, 2242, 675, 2306, -2.0805328f),
        OcrLine("Change", 333, 2327, 589, 2399, 0.0f),
        OcrLine("Charges summary", 175, 2454, 661, 2532, -2.3863745f),
        OcrLine("SST 6%", 173, 2536, 367, 2594, -2.2243965f),
        OcrLine("This ls an", 624, 2664, 875, 2740, -2.872811f),
        OcrLine("Thank yog for vislllng us", 425, 2735, 875, 2803, -3.2573955f),
        OcrLine("Feedback & e-Invoice >>", 151, 2811, 774, 2898, -3.0157998f),
        OcrLine("Bose Amt.", 1134, 2413, 1395, 2473, -2.3718538f),
        OcrLine("127.50", 1229, 2482, 1394, 2535, -1.4932536f),
        OcrLine("official recelpt.", 916, 2644, 1270, 2725, -2.8728116f),
        OcrLine("Scan the QR code to rate your experlence and", 146, 2842, 1302, 2975, -3.5090919f),
        OcrLine("download your e-Involce.", 139, 2942, 783, 3046, -3.5924501f),
        OcrLine("We hope lo ste yol 4ijdl) i0O)!", 898, 2701, 1470, 2776, -3.2573953f),
        OcrLine("Scan the QR code lo yei your e-Invo ie. lu available (run", 136, 2965, 1361, 3103, -4.1067643f),
        OcrLine("30 minutes after payment intil the end of the month", 147, 3030, 1248, 3161, -4.13593f),
        OcrLine("ORDER", 1402, 753, 1575, 804, 2.6182854f),
        OcrLine("POWEREO DY TEST POS 1", 599, 3123, 1203, 3215, -4.302272f),
        OcrLine("14A", 1401, 838, 1603, 921, 2.2865562f),
        OcrLine("Price (MYR)", 1469, 1034, 1768, 1087, 0.7753996f),
        OcrLine("26.00", 1637, 1149, 1780, 1202, -1.8268398f),
        OcrLine("24.00", 1634, 1221, 1779, 1276, -2.4668925f),
        OcrLine("35.00", 1628, 1295, 1789, 1350, -2.4165123f),
        OcrLine("34.00", 1619, 1433, 1760, 1483, -1.1392041f),
        OcrLine("5.50", 1647, 1570, 1756, 1621, -2.8674028f),
        OcrLine("3.00", 1641, 1639, 1754, 1688, -3.3223083f),
        OcrLine("127.50", 1575, 1822, 1747, 1877, -3.120083f),
        OcrLine("7.65", 1633, 1889, 1797, 1949, -3.386334f),
        OcrLine("0.00", 1629, 1964, 1742, 2014, 0.0f),
        OcrLine("135.15", 1471, 2095, 1739, 2176, -3.0066981f),
        OcrLine("135.15", 1560, 2193, 1734, 2248, -2.3284147f),
        OcrLine("0.00", 1585, 2270, 1729, 2332, -0.9175551f),
        OcrLine("Amount", 1526, 2407, 1728, 2459, -1.3114573f),
        OcrLine("7.65", 1618, 2476, 1729, 2525, 0.0f),
    )

    @Test
    fun tiltedScanIsStraightenedAndAccepted() {
        val read = ReceiptRules.read(lines, now = Long.MAX_VALUE)!!
        assertTrue(read.accepted)
        assertEquals(
            listOf("26.00", "24.00", "35.00", "34.00", "5.50", "3.00").map(::BigDecimal),
            read.draft.items.map { it.price }
        )
        assertEquals(BigDecimal("7.65"), read.draft.tax)
        assertEquals(BigDecimal("135.15"), read.draft.printedTotal)
    }

    @Test
    fun unitPricesAreRemovedFromItemNames() {
        val read = ReceiptRules.read(lines, now = Long.MAX_VALUE)!!
        assertEquals(
            listOf("Kimisla (Large)", "Kimista (Smal)", "Nagoya Mazesoba DX (Large)",
                "Doniku Nagoya Mazesoba (Large)", "Korokke", "Ajitama"),
            read.draft.items.map { it.name }
        )
    }
}
