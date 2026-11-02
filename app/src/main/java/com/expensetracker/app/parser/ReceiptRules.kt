package com.expensetracker.app.parser

import java.math.BigDecimal
import java.math.RoundingMode
import java.util.Calendar

/** `price` is the line total (not the unit price). */
data class ReceiptItemDraft(val name: String, val quantity: Int, val price: BigDecimal)

data class ReceiptDraft(
    val merchant: String?,
    val dateMillis: Long?,
    val items: List<ReceiptItemDraft>,
    val serviceCharge: BigDecimal,
    val tax: BigDecimal,
    val discount: BigDecimal,
    val rounding: BigDecimal,
    val printedTotal: BigDecimal?
)

/** One recognized text line with its box in image pixels. */
data class OcrLine(val text: String, val left: Int, val top: Int, val right: Int, val bottom: Int)

/** `calculated` holds display phrases for charges the rules computed, e.g. "10% service charge". */
data class ReceiptRead(val draft: ReceiptDraft, val accepted: Boolean, val calculated: List<String>)

internal data class ParsedReceipt(
    val items: List<ReceiptItemDraft>,
    val subtotal: BigDecimal?,
    val serviceCharge: BigDecimal,
    val tax: BigDecimal,
    val discount: BigDecimal,
    val rounding: BigDecimal,
    val totals: List<BigDecimal>,
    val nameBelowHint: Boolean = false
)

/** Rule-based receipt reading: OCR lines to rows, repaired rows, then items, charges and totals. Pure JVM. */
object ReceiptRules {
    private val I = RegexOption.IGNORE_CASE
    private val ZERO = BigDecimal("0.00")

    private const val AMOUNT = """-?(?:RM\s*|\$)?\(?(?<![\d,.])(?:\d{1,3}(?:,\d{3})+|\d+)\.\d{2}\)?-?"""
    private val TAIL = Regex("""($AMOUNT)\s*(?:[A-Z]{1,3}-?\d?|\*\w?|#)?\s*$""", I)
    private val QTY_X = Regex("""(\d+(?:\.\d+)?)\s*[xX@*]\s*(?:RM\s*)?(\d+\.\d{2})""")
    private val LEAD_QTY = Regex("""^(\d{1,2})\s+([A-Za-z].*)$""")
    private val LEAD_NUMBER_COLUMNS = Regex("""^(\d{1,2})\s+\d+\.\d{2}\s*$""")
    private val TRAILING_NUMBERS = Regex("""(\s+$AMOUNT|\s+\d+(?:\.\d+)?)+\s*$""", I)

    private fun kw(vararg words: String) =
        Regex("(?<![A-Z])(?:" + words.joinToString("|") + ")(?![A-Z])", I)

    private val SUBTOTAL = kw("""SUB\s*-?\s*TOTAL""", """TOTAL\s*\(?\s*EXCL\w*""", """TOTAL\s+BEFORE""", """NET\s+SALES""")
    private val TOTAL = kw(
        """GRAND\s+TOTAL""", """NETT?\s+TOTAL""", """TOTAL\s+AMOUNT""", """TOTAL\s+INCL\w*""", """TOTAL\s+SALES""",
        """TOTAL\s+PAYABLE""", """AMOUNT\s+DUE""", """AMT\s+DUE""", """TOTAL\s+DUE""", """JUMLAH""", """TOTAL""",
        """TOTAL\s*\(RM\)""", """NETT"""
    )
    private val NOT_TOTAL = kw(
        """TOTAL\s+QTY""", """TOTAL\s+QUANTITY""", """TOTAL\s+ITEMS?""", """TOTAL\s+DISC\w*""", """TOTAL\s+GST""",
        """TOTAL\s+TAX""", """TOTAL\s+SAVING\w*""", """TOTAL\s+NO""", """ITEM\s*\(S\)""", """QTY""", """TOTAL\s+EXCL\w*"""
    )
    private val SERVICE = kw(
        """SERVICE\s+CHARGE""", """SERV\w*\.?\s*CH\w*""", """SVC\s*CHG""", """SVC""", """S/C""", """SERV\.?\s*CHG""",
        """SERVICE\s+CHG""", """SC\s*\d+\s*%"""
    )
    private val TAX = kw("""GST""", """SST""", """TAX""", """SERVICE\s+TAX""", """VAT""")
    private val ROUNDING = kw("""ROUNDING""", """ROUND\w*\s+ADJ\w*""", """RND""", """ADJ\w*""")
    private val DISCOUNT = kw("""DISCOUNT""", """DISC""", """VOUCHER""", """LESS""", """PROMO""")
    private val PAYMENT = kw(
        """CASH""", """CHANGE""", """BAKI""", """TENDER\w*""", """VISA""", """MASTER\w*""", """CARD""", """PAID""",
        """PAYMENT""", """CREDIT""", """DEBIT""", """TNG""", """E-?WALLET""", """BOOST""", """GRABPAY""", """AMEX""",
        """RECEIVED"""
    )
    private val SKIP_ITEM = kw(
        """TEL""", """FAX""", """GST\s*(?:REG|ID|NO)""", """INV""", """RECEIPT""", """DATE""", """TIME""", """TABLE""",
        """PAX""", """CASHIER""", """BILL""", """POINTS?""", """BALANCE""", """MEMBER"""
    )
    private val STOP = kw("""SUMMARY""", """TAX\s+CODE""", """CHANGE""", """BAKI""")
    private val SERVICE_TAX = Regex("""SERVICE\s+TAX""", I)
    private val INCLUDED = Regex("""INCLUDED|INCL""", I)

    private val VOCAB = listOf(
        "TOTAL", "SUBTOTAL", "AMOUNT", "SERVICE", "CHARGE", "ROUNDING", "DISCOUNT", "CHANGE", "CASH",
        "INCLUSIVE", "EXCLUDING", "PAYABLE", "GRAND", "SALES", "NETT", "SERV", "TENDER", "BALANCE", "SUMMARY"
    )

    /** Four-letter words match only exactly (CASE is not CASH). SERY is an OCR form of SERV. */
    private val FOUR_LETTER = VOCAB.filter { it.length == 4 }.associateWith { it } + ("SERY" to "SERV")

    private fun money(s: String): BigDecimal {
        val t = s.uppercase().replace("RM", "").replace("$", "").replace(",", "").replace(" ", "")
        val neg = t.startsWith("-") || t.endsWith("-") || t.startsWith("(")
        val v = BigDecimal(t.trim('-', '(', ')'))
        return if (neg) v.negate() else v
    }

    /** Join lines whose vertical centers sit inside one row band, left to right, one space between parts. */
    internal fun rows(lines: List<OcrLine>): List<String> {
        class Band(val cy: Double, val h: Int, val parts: MutableList<Pair<Int, String>>)
        val bands = mutableListOf<Band>()
        for (l in lines.sortedBy { (it.top + it.bottom) / 2.0 }) {
            val cy = (l.top + l.bottom) / 2.0
            val h = maxOf(1, l.bottom - l.top)
            val band = bands.firstOrNull { Math.abs(it.cy - cy) < 0.5 * minOf(h, it.h) }
            if (band != null) band.parts += l.left to l.text else bands += Band(cy, h, mutableListOf(l.left to l.text))
        }
        return bands.map { b ->
            b.parts.sortedWith(compareBy({ it.first }, { it.second })).joinToString(" ") { it.second }.trim()
        }
    }

    /** Repair OCR damage on amounts at the end of a row: "14 00", "79, 60", "-0. 03", "1O.50". */
    internal fun fixRow(row: String): String {
        var r = row.replace(Regex("""(?<=\d)[oO](?=[\d.,])|(?<=[\d.,])[oO](?=\d)"""), "0")
        r = r.replace(Regex("""(\d)\s*[,.]\s+(\d{2})(\s*[A-Za-z]{0,3}\s*)$"""), "$1.$2$3")
        r = r.replace(Regex("""(\d),(\d{2})(\s*[A-Za-z]{0,3}\s*)$"""), "$1.$2$3")
        r = r.replace(Regex("""(?<![\d.,:/])(\d{1,4}) (\d{2})(\s*[A-Za-z]{0,3}\s*)$"""), "$1.$2$3")
        return r
    }

    /** Fuzzy-correct label words for keyword matching only ("SULTOTAL" to "SUBTOTAL", "T0TAL" to "TOTAL"). */
    internal fun normLabel(label: String): String =
        Regex("""[A-Za-z0-9%@#/().:-]+""").findAll(label.uppercase().replace('0', 'O')).joinToString(" ") { m ->
            val w = m.value
            val core = w.filter { it in 'A'..'Z' }
            when {
                core.length == 4 -> FOUR_LETTER[core] ?: w
                core.length >= 5 -> closestWord(core) ?: w
                else -> w
            }
        }

    private fun closestWord(core: String): String? {
        var best: String? = null
        var bestSim = 0.75 - 1e-9
        for (v in VOCAB) {
            if (v[0] != core[0]) continue
            val sim = 1.0 - levenshtein(core, v).toDouble() / maxOf(core.length, v.length)
            if (sim > bestSim) { best = v; bestSim = sim }
        }
        return best
    }

    private fun levenshtein(a: String, b: String): Int {
        var prev = IntArray(b.length + 1) { it }
        for (i in 1..a.length) {
            val cur = IntArray(b.length + 1)
            cur[0] = i
            for (j in 1..b.length) {
                cur[j] = minOf(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + if (a[i - 1] == b[j - 1]) 0 else 1)
            }
            prev = cur
        }
        return prev[b.length]
    }

    private val HEADER_QTY = Regex("""(?<![A-Z])QTY(?![A-Z])""", I)
    private val HEADER_NAME = Regex("""(?<![A-Z])(?:DESC\w*|ITEMS?)(?![A-Z])""", I)
    private val HEADER_PRICE = Regex("""(?<![A-Z])(?:TOTAL|AMOUNT|PRICE|AMT)(?![A-Z])""", I)

    /**
     * A tilted scan can put each price row one row above its name. The first pass pairs names above;
     * if the first item had no name above it and a name row is left after the last item, parse again with `nameBelow`.
     */
    internal fun parse(rows: List<String>): ParsedReceipt {
        val first = parse(rows, false)
        return if (first.nameBelowHint) parse(rows, true).copy(nameBelowHint = false) else first
    }

    private fun parse(rows: List<String>, nameBelow: Boolean): ParsedReceipt {
        val items = mutableListOf<ReceiptItemDraft>()
        val sc = mutableListOf<BigDecimal>()
        val tax = mutableListOf<BigDecimal>()
        val disc = mutableListOf<BigDecimal>()
        val rnd = mutableListOf<BigDecimal>()
        val totals = mutableListOf<BigDecimal>()
        var subtotal: BigDecimal? = null
        var inItems = true
        var firstNameless = false
        var trailingName = false
        var pending = -1 // nameBelow: index of the item still waiting for the name row below it
        val names = mutableListOf<String>() // text rows since the last item: the last one names an item whose numbers sit lower
        fun leaveItems() { if (inItems && names.isNotEmpty()) trailingName = true; inItems = false }
        for (raw in rows) {
            val row = fixRow(raw)
            if (HEADER_QTY.containsMatchIn(row) && HEADER_NAME.containsMatchIn(row) && HEADER_PRICE.containsMatchIn(row)) {
                names.clear()
                continue
            }
            val m = TAIL.find(row)
            if (STOP.containsMatchIn(normLabel(row)) && (m != null || "SUMMARY" in row.uppercase())) break
            if (m == null) {
                if (Regex("[A-Za-z]{3}").containsMatchIn(row) && !SKIP_ITEM.containsMatchIn(row)) {
                    if (nameBelow && inItems && pending >= 0) {
                        items[pending] = items[pending].copy(name = row)
                        pending = -1
                    } else names += row
                }
                continue
            }
            val amt = money(m.groupValues[1])
            val rawLabel = row.substring(0, m.range.first).trim()
            val label = normLabel(rawLabel)
            if (PAYMENT.containsMatchIn(label) && !TOTAL.containsMatchIn(label)) {
                if (totals.isNotEmpty()) break
                continue
            }
            if (SUBTOTAL.containsMatchIn(label)) {
                leaveItems()
                if (subtotal == null) subtotal = amt
            } else if (SERVICE.containsMatchIn(label) && !SERVICE_TAX.containsMatchIn(label)) {
                leaveItems(); sc += amt
            } else if (TOTAL.containsMatchIn(label) || NOT_TOTAL.containsMatchIn(label)) {
                leaveItems()
                if (!NOT_TOTAL.containsMatchIn(label)) totals += amt
            } else if (TAX.containsMatchIn(label)) {
                leaveItems()
                if (!INCLUDED.containsMatchIn(label)) tax += amt
            } else if (ROUNDING.containsMatchIn(label)) {
                leaveItems(); rnd += amt
            } else if (DISCOUNT.find(label)?.let { it.range.first == 0 || amt.signum() < 0 } == true) {
                disc += amt.abs()
            } else if (inItems && !Regex("[A-Za-z0-9]").containsMatchIn(label) && items.isNotEmpty() &&
                names.isEmpty() && items.last().price.compareTo(amt) == 0
            ) {
                continue // the line total printed again under its row
            } else if (inItems && !SKIP_ITEM.containsMatchIn(label)) {
                var name = rawLabel
                var qty = 1
                val q = QTY_X.find(row)
                if (q != null) {
                    qty = q.groupValues[1].toBigDecimal().toInt().takeIf { it != 0 } ?: 1
                    name = row.substring(0, q.range.first).trim()
                }
                name = TRAILING_NUMBERS.replace(" $name", "").trim()
                val lq = LEAD_QTY.matchEntire(name)
                if (lq != null && q == null) {
                    qty = lq.groupValues[1].toInt().takeIf { it != 0 } ?: 1
                    name = lq.groupValues[2]
                }
                var nameless = false
                if (!Regex("[A-Za-z]{2}").containsMatchIn(name)) {
                    nameless = true
                    if (items.isEmpty() && names.isEmpty()) firstNameless = true
                    name = if (nameBelow) "Item" else names.lastOrNull() ?: "Item"
                    // "4 3.50 14.00": no name, the leading count is the quantity
                    if (q == null) LEAD_NUMBER_COLUMNS.find(rawLabel)?.let { qty = it.groupValues[1].toInt().takeIf { n -> n != 0 } ?: 1 }
                }
                if (amt.signum() < 0) disc += amt.negate()
                else if (amt.signum() > 0) {
                    items += ReceiptItemDraft(name, qty, amt)
                    if (nameBelow && nameless) pending = items.lastIndex
                }
                names.clear()
            }
        }
        if (inItems && names.isNotEmpty()) trailingName = true
        return ParsedReceipt(
            items, subtotal,
            sc.fold(ZERO, BigDecimal::add), tax.fold(ZERO, BigDecimal::add),
            disc.fold(ZERO, BigDecimal::add), rnd.fold(ZERO, BigDecimal::add), totals,
            !nameBelow && firstNameless && trailingName
        )
    }

    private class Reading(
        val value: BigDecimal, val sc: BigDecimal, val tax: BigDecimal, val disc: BigDecimal,
        val rnd: BigDecimal, val calculated: List<String> = emptyList()
    )

    /** Readings 1 to 6 of the spec, in order. */
    private fun readings(p: ParsedReceipt): List<Reading> {
        val s = p.items.fold(ZERO) { a, i -> a + i.price }
        val (sc, tax, disc, rnd) = listOf(p.serviceCharge, p.tax, p.discount, p.rounding)
        val out = mutableListOf(
            Reading(s, ZERO, ZERO, ZERO, ZERO),
            Reading(s + rnd, ZERO, ZERO, ZERO, rnd),
            Reading(s - disc + rnd, ZERO, ZERO, disc, rnd),
            Reading(s + sc + tax - disc + rnd, sc, tax, disc, rnd),
            Reading(s + sc - disc + rnd, sc, ZERO, disc, rnd)
        )
        val base = s - disc
        for (scRate in (if (sc.signum() == 0) listOf(BigDecimal("0.10")) else emptyList()) + listOf(null)) {
            val sc2 = if (scRate != null) (base * scRate).setScale(2, RoundingMode.HALF_UP) else sc
            for (txRate in (if (tax.signum() == 0) listOf(BigDecimal("0.06"), BigDecimal("0.08")) else emptyList()) + listOf(null)) {
                if (scRate == null && txRate == null) continue
                val tx2 = if (txRate != null) ((base + sc2) * txRate).setScale(2, RoundingMode.HALF_UP) else tax
                val phrases = listOfNotNull(
                    scRate?.let { "10% service charge" },
                    txRate?.let { "${it.movePointRight(2).toInt()}% SST" }
                )
                out += Reading(base + sc2 + tx2 + rnd, sc2, tx2, disc, rnd, phrases)
            }
        }
        return out
    }

    /** Null when the lines hold no item and no printed total. */
    fun read(lines: List<OcrLine>, now: Long = System.currentTimeMillis()): ReceiptRead? {
        val rows = rows(lines)
        val p = parse(rows)
        val total = p.totals.lastOrNull()
        val printed = total ?: p.subtotal
        if (p.items.isEmpty() && printed == null) return null

        var hit: Reading? = null
        var rounding = p.rounding
        if (total != null && p.items.isNotEmpty()) {
            val rs = readings(p)
            hit = rs.firstOrNull { (it.value - total).abs() <= TOLERANCE }
            if (hit == null && (total * BigDecimal(20)).stripTrailingZeros().scale() <= 0) {
                hit = rs.firstOrNull { (it.value - total).abs() <= BigDecimal("0.02") }
            }
            if (hit != null) rounding = hit.rnd + (total - hit.value)
        }
        val draft = ReceiptDraft(
            merchant = merchant(rows), dateMillis = date(rows, now), items = p.items,
            serviceCharge = hit?.sc ?: p.serviceCharge, tax = hit?.tax ?: p.tax,
            discount = hit?.disc ?: p.discount, rounding = rounding, printedTotal = printed
        )
        return ReceiptRead(draft, hit != null, hit?.calculated ?: emptyList())
    }

    private val TOLERANCE = BigDecimal("0.01")
    private val NOT_MERCHANT = Regex("""^(?:TAX\s+)?(?:INVOI\s*CE|RECEIPT)\W*$""", I)
    private val ADDRESS = Regex(
        """(?<![A-Z])(?:NO\.|(?:JALAN|JLN|LORONG|LRG|TAMAN|TMN|KAWASAN|BANDAR|PERSIARAN|LEBUH|KUALA|SELANGOR|JOHOR|PENANG|""" +
            """PERAK|KEDAH|MELAKA|SABAH|SARAWAK|PAHANG|KELANTAN|TERENGGANU|TEL|FAX|GST|SST|REG|COMPANY|CASHIER|DATE|WWW|""" +
            """THANK|TQ|WELCOME|INVOICE|QTY|CASH\s+SALE)(?![A-Z]))|\.COM|(?<!\d)\d{5}(?!\d)""", I
    )
    private val LEGAL_ONLY = Regex("""(?<![A-Z])(?:SDN|BHD|S/B)(?![A-Z])|\([^)]*\)""", I)

    private val COMPANY_NO = Regex("""\s*[(\[{]\s*\d{4,}\s*-?\s*[A-Z]?\s*[)\]}]?\s*$""", I)

    private fun merchant(rows: List<String>): String? {
        val candidates = rows.take(8).filter { r ->
            val letters = r.count { it.isLetter() }
            letters >= 3 && letters > r.count { it.isDigit() } && !NOT_MERCHANT.matches(r.trim()) &&
                !ADDRESS.containsMatchIn(r) && LEGAL_ONLY.replace(r, "").count { it.isLetter() } >= 3
        }
        return candidates.firstOrNull()?.replace(COMPANY_NO, "")?.trim()
    }

    private const val MONTHS = "JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC"
    private val DMY = Regex("""(?<!\d)(\d{1,2})[/.-](\d{1,2})[/.-](\d{4}|\d{2})(?!\d)""")
    private val DMONY = Regex("""(?<!\d)(\d{1,2})\s+(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*\.?,?\s+(\d{4}|\d{2})(?!\d)""", I)
    private val YMD = Regex("""(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)""")

    /** The first date in the text, day first, as local midnight. An impossible date or one after `now` is null. */
    private fun date(rows: List<String>, now: Long): Long? {
        val text = rows.joinToString("\n")
        val found = listOfNotNull(
            DMY.find(text)?.let { it.range.first to Triple(it.groupValues[3], it.groupValues[2], it.groupValues[1]) },
            DMONY.find(text)?.let {
                it.range.first to Triple(it.groupValues[3], (MONTHS.split(" ").indexOf(it.groupValues[2].uppercase()) + 1).toString(), it.groupValues[1])
            },
            YMD.find(text)?.let { it.range.first to Triple(it.groupValues[1], it.groupValues[2], it.groupValues[3]) }
        ).minByOrNull { it.first }?.second ?: return null
        val (y, m, d) = found
        val year = y.toInt().let { if (y.length == 2) 2000 + it else it }
        return try {
            Calendar.getInstance().apply { isLenient = false; clear(); set(year, m.toInt() - 1, d.toInt(), 0, 0, 0) }.timeInMillis
        } catch (e: IllegalArgumentException) {
            null
        }?.takeIf { it <= now }
    }
}
