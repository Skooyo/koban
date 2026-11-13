package com.expensetracker.app.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.expensetracker.app.data.CategoryBreakdown
import com.expensetracker.app.data.ExpenseEntity
import com.expensetracker.app.ui.theme.LocalMoneyColors
import com.expensetracker.app.ui.theme.categoryColor
import java.math.BigDecimal
import java.math.RoundingMode
import kotlin.math.cos
import kotlin.math.sin

/** Filter value for payments with no category. Null means no filter. */
const val UNCATEGORIZED_FILTER = "__uncategorized"

fun ExpenseEntity.matchesCategory(filter: String?): Boolean = when (filter) {
    null -> true
    UNCATEGORIZED_FILTER -> categoryId == null
    else -> categoryId == filter
}

/** One donut slice: a category, or several small ones folded together ([folded]). */
data class DonutSlice(val categoryId: String?, val name: String, val total: BigDecimal, val folded: Boolean = false)

const val EVERYTHING_ELSE = "Everything else"
private const val MAX_SLICES = 6

/**
 * Slices in a fixed order. In this order no two neighbors have colors that look alike
 * (checked with the dataviz palette validator, light and dark themes).
 * Other, custom and uncategorized spending folds into one gray slice at the end.
 */
private val SLICE_ORDER = listOf("food", "health", "transport", "entertainment", "shopping", "bills")

fun donutSlices(breakdown: List<CategoryBreakdown>): List<DonutSlice> {
    val positive = breakdown.filter { it.total.signum() > 0 }
    val named = SLICE_ORDER.mapNotNull { id -> positive.find { it.categoryId == id } }.toMutableList()
    val rest = positive.filter { it.categoryId !in SLICE_ORDER }.toMutableList()
    while (named.size + (if (rest.isEmpty()) 0 else 1) > MAX_SLICES) {
        val smallest = named.minBy { it.total }
        named.remove(smallest)
        rest.add(smallest)
    }
    val slices = named.map { DonutSlice(it.categoryId, it.name, it.total) }
    return when (rest.size) {
        0 -> slices
        1 -> slices + DonutSlice(rest[0].categoryId, rest[0].name, rest[0].total)
        else -> slices + DonutSlice(null, EVERYTHING_ELSE, rest.fold(BigDecimal.ZERO) { a, b -> a + b.total }, folded = true)
    }
}

@Composable
private fun sliceColor(slice: DonutSlice) =
    if (slice.folded || slice.categoryId !in SLICE_ORDER) LocalMoneyColors.current.other else categoryColor(slice.categoryId)

private fun percentOf(part: BigDecimal, whole: BigDecimal): Int =
    if (whole.signum() == 0) 0 else part.multiply(BigDecimal(100)).divide(whole, 0, RoundingMode.HALF_UP).toInt()

/**
 * Spending by category as a small ring. The ring is a button when [onClick] is set.
 * The gap between slices has the color of the card the ring sits on.
 */
@Composable
fun CategoryDonut(
    slices: List<DonutSlice>,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null
) {
    if (slices.isEmpty()) return
    val colors = slices.map { sliceColor(it) }
    val gap = MaterialTheme.colorScheme.surfaceContainer
    val whole = slices.fold(BigDecimal.ZERO) { a, b -> a + b.total }
    val summary = slices.joinToString(", ") { "${it.name} ${percentOf(it.total, whole)} percent" }

    Canvas(
        modifier = modifier
            .size(104.dp)
            .then(
                if (onClick != null) Modifier.clickable(role = Role.Button, onClickLabel = "Filter by category", onClick = onClick)
                else Modifier
            )
            .semantics { contentDescription = "Spending by category: $summary" }
    ) {
        val stroke = size.minDimension * 0.2f
        val diameter = size.minDimension - stroke
        val topLeft = Offset((size.width - diameter) / 2, (size.height - diameter) / 2)
        val sweeps = slices.map { 360f * it.total.toFloat() / whole.toFloat() }
        var start = -90f
        sweeps.forEachIndexed { i, sweep ->
            drawArc(colors[i], start, sweep, false, topLeft, Size(diameter, diameter), style = Stroke(stroke))
            start += sweep
        }
        // A 2dp gap between neighboring slices.
        if (slices.size > 1) {
            val inner = diameter / 2 - stroke / 2 - 1f
            val outer = diameter / 2 + stroke / 2 + 1f
            start = -90f
            sweeps.forEach { sweep ->
                val angle = Math.toRadians(start.toDouble())
                val dx = cos(angle).toFloat()
                val dy = sin(angle).toFloat()
                drawLine(gap, center + Offset(dx * inner, dy * inner), center + Offset(dx * outer, dy * outer), 2.dp.toPx())
                start += sweep
            }
        }
    }
}
