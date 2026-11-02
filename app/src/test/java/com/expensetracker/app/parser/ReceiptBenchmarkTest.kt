package com.expensetracker.app.parser

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume
import org.junit.Test
import java.io.File
import java.util.Calendar

/** Scores ReceiptRules on SROIE receipts read by ML Kit. Needs the git-ignored `receipt-bench` folder. */
class ReceiptBenchmarkTest {
    private val food = Regex(
        "RESTORAN|RESTAURANT|CAFE|KOPITIAM|FOOD|NASI|MAKAN|BAKERY|KITCHEN|SEAFOOD|BISTRO|DIM SUM|" +
            "BAK KUT|CHICKEN|BURGER|PIZZA|SUSHI|MAMAK|CATERING|DELIGHTS|STOOGES|PUB|DAKGALBI|COFFEE|" +
            "TEALIVE|MENTAI|WARAKUYA|UNIHAKKA|KITCHENETTE|SUNFISH|BANH MI",
        RegexOption.IGNORE_CASE
    )

    private class Stats {
        var n = 0; var accepted = 0; var correct = 0; var wrong = 0
        var merchantN = 0; var merchantOk = 0; var dateN = 0; var dateOk = 0
        val correctIds = mutableListOf<String>()
        val wrongIds = mutableListOf<String>()
        fun pct(x: Int, d: Int) = if (d == 0) "n/a" else "%.1f%%".format(100.0 * x / d)
        fun report(name: String) =
            "Benchmark $name n=$n accepted-correct ${pct(correct, n)} flagged ${pct(n - accepted, n)} " +
                "wrong-not-flagged $wrong merchant ${pct(merchantOk, merchantN)} date ${pct(dateOk, dateN)}"
    }

    private fun norm(s: String) = s.uppercase().replace(Regex("\\s+"), " ").trim()

    /** Day, month, year from a SROIE date string, or null when the format is unknown. */
    private fun keyDate(s: String): Triple<Int, Int, Int>? {
        val months = "JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC".split(" ")
        Regex("""(\d{4})[/.-](\d{1,2})[/.-](\d{1,2})""").find(s)?.let {
            return Triple(it.groupValues[3].toInt(), it.groupValues[2].toInt(), it.groupValues[1].toInt())
        }
        Regex("""(\d{1,2})[/.-](\d{1,2})[/.-](\d{4}|\d{2})""").find(s)?.let {
            val y = it.groupValues[3].toInt().let { v -> if (v < 100) 2000 + v else v }
            return Triple(it.groupValues[1].toInt(), it.groupValues[2].toInt(), y)
        }
        Regex("""(\d{1,2})[\s-]*([A-Za-z]{3})[A-Za-z]*[\s,.-]*(\d{4}|\d{2})""").find(s)?.let {
            val m = months.indexOf(it.groupValues[2].uppercase()) + 1
            if (m == 0) return null
            val y = it.groupValues[3].toInt().let { v -> if (v < 100) 2000 + v else v }
            return Triple(it.groupValues[1].toInt(), m, y)
        }
        return null
    }

    @Test
    fun restaurantBenchmark() {
        val root = File("../receipt-bench")
        Assume.assumeTrue(File(root, "mlkit").isDirectory)
        val all = Stats()
        val restaurant = Stats()
        for (keyFile in File(root, "sroie/key").listFiles { f -> f.extension == "json" }!!.sortedBy { it.name }) {
            val id = keyFile.nameWithoutExtension
            val key = JSONObject(keyFile.readText(Charsets.UTF_8))
            val truth = key.optString("total").replace(Regex("[^0-9.]"), "").toBigDecimalOrNull() ?: continue
            val mlkit = File(root, "mlkit/$id.json")
            if (!mlkit.exists()) continue
            val arr = JSONObject(mlkit.readText(Charsets.UTF_8)).getJSONArray("lines")
            val lines = (0 until arr.length()).map {
                val o = arr.getJSONObject(it)
                val b = o.getJSONArray("box")
                OcrLine(o.getString("text"), b.getInt(0), b.getInt(1), b.getInt(2), b.getInt(3))
            }
            val company = key.optString("company")
            val read = ReceiptRules.read(lines, now = Long.MAX_VALUE)
            val groups = listOf(all) + if (food.containsMatchIn(company)) listOf(restaurant) else emptyList()
            for (s in groups) {
                s.n++
                if (read != null && read.accepted) {
                    s.accepted++
                    if (read.draft.printedTotal?.compareTo(truth) == 0) { s.correct++; s.correctIds += id }
                    else { s.wrong++; s.wrongIds += id }
                }
                s.merchantN++
                val m = read?.draft?.merchant?.let(::norm)
                val c = norm(company)
                if (m != null && c.isNotEmpty() && (m == c || m in c || c in m)) s.merchantOk++
                val kd = keyDate(key.optString("date"))
                if (kd != null) {
                    s.dateN++
                    val ms = read?.draft?.dateMillis
                    if (ms != null) {
                        val cal = Calendar.getInstance().apply { timeInMillis = ms }
                        if (Triple(cal.get(Calendar.DAY_OF_MONTH), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.YEAR)) == kd) s.dateOk++
                    }
                }
            }
        }
        println(all.report("all"))
        println(restaurant.report("restaurant"))
        println("Benchmark restaurant-correct-ids " + restaurant.correctIds.joinToString(","))
        println("Benchmark restaurant-wrong-ids " + restaurant.wrongIds.joinToString(","))
        println("Benchmark all-wrong-ids " + all.wrongIds.joinToString(","))
        assertTrue("restaurant accepted-correct ${restaurant.correct}/${restaurant.n}", restaurant.correct >= 0.73 * restaurant.n)
        assertEquals(0, restaurant.wrong)
    }
}
