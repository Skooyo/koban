package com.expensetracker.app.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.expensetracker.app.data.CategoryBreakdown
import com.expensetracker.app.data.CategoryEntity
import com.expensetracker.app.data.DefaultCategories
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
private const val COMPACT_ROWS = 4

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
 * Spending by category as a donut, with a legend that names every slice.
 * [compact] puts a small ring on the left and at most 4 legend rows on the right.
 */
@Composable
fun CategoryDonut(
    slices: List<DonutSlice>,
    onSelect: (DonutSlice) -> Unit,
    modifier: Modifier = Modifier,
    compact: Boolean = false
) {
    if (slices.isEmpty()) return
    val colors = slices.map { sliceColor(it) }
    val gap = MaterialTheme.colorScheme.background
    val whole = slices.fold(BigDecimal.ZERO) { a, b -> a + b.total }
    val summary = slices.joinToString(", ") { "${it.name} ${percentOf(it.total, whole)} percent" }

    // Compact legend: the first 3 slices, then the rest folded into one gray row.
    val folding = compact && slices.size > COMPACT_ROWS
    val legend = if (folding) {
        val rest = slices.drop(COMPACT_ROWS - 1)
        slices.take(COMPACT_ROWS - 1) +
            DonutSlice(null, EVERYTHING_ELSE, rest.fold(BigDecimal.ZERO) { a, b -> a + b.total }, folded = true)
    } else slices
    val other = LocalMoneyColors.current.other
    val legendColors = if (folding) colors.take(COMPACT_ROWS - 1) + other else colors

    val ring: @Composable (Modifier) -> Unit = { ringModifier ->
        Canvas(
            modifier = ringModifier
                .size(if (compact) 104.dp else 176.dp)
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
            // A 2dp background-colored gap between neighboring slices.
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
    val legendColumn: @Composable (Modifier) -> Unit = { legendModifier ->
        Column(modifier = legendModifier, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            legend.forEachIndexed { i, slice ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 48.dp)
                        .then(
                            if (slice.folded) Modifier
                            else Modifier.clickable(role = Role.Button, onClickLabel = "Show only ${slice.name}") { onSelect(slice) }
                        )
                ) {
                    Box(
                        Modifier
                            .size(10.dp)
                            .clip(RoundedCornerShape(2.dp))
                            .background(legendColors[i])
                    )
                    Text(
                        text = slice.name,
                        style = MaterialTheme.typography.bodyMedium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier
                            .weight(1f)
                            .padding(start = 10.dp, end = if (compact) 8.dp else 0.dp)
                    )
                    if (!compact) {
                        Text(
                            text = "${percentOf(slice.total, whole)}%",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(end = 12.dp)
                        )
                    }
                    MoneyAmount(amount = slice.total, style = MaterialTheme.typography.bodyMedium)
                }
            }
        }
    }

    if (compact) {
        Row(
            modifier = modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            ring(Modifier)
            legendColumn(Modifier.weight(1f))
        }
    } else {
        Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            ring(Modifier.align(Alignment.CenterHorizontally))
            legendColumn(Modifier)
        }
    }
}

/** One row of chips: All, each category, Uncategorized. */
@Composable
fun CategoryFilterRow(
    categories: List<CategoryEntity>,
    selected: String?,
    onSelect: (String?) -> Unit,
    modifier: Modifier = Modifier
) {
    val options = listOf<Pair<String?, String>>(null to "All") +
        categories.map { it.id to it.name } +
        (UNCATEGORIZED_FILTER to DefaultCategories.UNCATEGORIZED_NAME)
    LazyRow(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        items(options, key = { it.first ?: "all" }) { (id, name) ->
            FilterChip(
                selected = selected == id,
                onClick = { onSelect(id) },
                label = { Text(name) }
            )
        }
    }
}
