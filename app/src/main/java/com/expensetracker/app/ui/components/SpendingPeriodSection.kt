package com.expensetracker.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.expensetracker.app.data.CategoryBreakdown
import com.expensetracker.app.data.PeriodSummary
import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.ui.theme.LocalMoneyColors
import com.expensetracker.app.ui.theme.categoryColor
import java.math.BigDecimal
import java.math.RoundingMode

/**
 * Money with a small currency symbol. A negative [amount] means money received:
 * it shows as "+RM" in the received colour.
 */
@Composable
fun MoneyAmount(
    amount: BigDecimal,
    style: TextStyle,
    modifier: Modifier = Modifier,
    currency: String = "MYR",
    color: Color = MaterialTheme.colorScheme.onSurface,
    symbolScale: Float = 0.75f
) {
    val received = amount < BigDecimal.ZERO
    val symbolColor = MaterialTheme.colorScheme.onSurfaceVariant
    Text(
        text = buildAnnotatedString {
            if (received) append("+")
            withStyle(SpanStyle(fontSize = style.fontSize * symbolScale, color = symbolColor)) {
                append(AmountFormatter.currencySymbol(currency))
                append(" ")
            }
            append(AmountFormatter.formatGrouped(amount.abs()))
        },
        style = style.copy(fontFeatureSettings = "tnum"),
        color = if (received) LocalMoneyColors.current.received else color,
        maxLines = 1,
        modifier = modifier
    )
}

/** Solid fill for a category; diagonal stripes for uncategorized, so it reads as "not sorted yet". */
fun Modifier.categoryFill(categoryId: String?, color: Color): Modifier =
    if (categoryId != null) {
        background(color)
    } else {
        drawBehind {
            val step = 5.5.dp.toPx()
            clipRect {
                var x = -size.height
                while (x < size.width) {
                    drawLine(
                        color = color,
                        start = Offset(x, size.height),
                        end = Offset(x + size.height, 0f),
                        strokeWidth = 2.5.dp.toPx()
                    )
                    x += step
                }
            }
            drawRect(color = color.copy(alpha = 0.55f), style = Stroke(width = 1.dp.toPx()))
        }
    }

/** Spending split by category, one banknote colour per category. Received money is left out. */
@Composable
fun NoteStrip(
    breakdown: List<CategoryBreakdown>,
    modifier: Modifier = Modifier,
    height: Dp = 14.dp
) {
    val spent = breakdown.filter { it.total > BigDecimal.ZERO }
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(height)
            .clip(RoundedCornerShape(3.dp)),
        horizontalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        if (spent.isEmpty()) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.outlineVariant)
            )
        }
        spent.forEach { item ->
            Box(
                Modifier
                    .weight(item.total.toFloat())
                    .fillMaxHeight()
                    .categoryFill(item.categoryId, categoryColor(item.categoryId))
            )
        }
    }
}

/** The large total at the top of Home. Tap opens the transactions for the period. */
@Composable
fun PeriodHero(
    summary: PeriodSummary,
    onOpen: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClickLabel = "Open transactions", onClick = onOpen)
            .padding(vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(text = summary.title, style = MaterialTheme.typography.titleLarge)
            Text(
                text = summary.subtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier
                    .weight(1f)
                    .padding(start = 10.dp)
            )
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Column {
            MoneyAmount(
                amount = summary.total,
                style = MaterialTheme.typography.displayLarge,
                symbolScale = 0.4f
            )
            ReceivedNote(received = summary.received, modifier = Modifier.padding(top = 4.dp))
        }
        NoteStrip(breakdown = summary.breakdown)
        if (summary.breakdown.isEmpty()) {
            Text(
                text = "No payments recorded yet.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        } else {
            CategoryBreakdownList(breakdown = summary.breakdown)
        }
    }
}

/** One tappable period with its total, e.g. a week or a month. [below] draws under the total. */
@Composable
fun PeriodTotalRow(
    title: String,
    subtitle: String?,
    total: BigDecimal,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    below: @Composable () -> Unit = {}
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(text = title, style = MaterialTheme.typography.titleMedium)
                subtitle?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            MoneyAmount(amount = total, style = MaterialTheme.typography.titleLarge)
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(start = 4.dp)
            )
        }
        below()
    }
}

/** Thin bar that compares [total] with the largest total in a list. */
@Composable
fun RelativeBar(total: BigDecimal, max: BigDecimal?, modifier: Modifier = Modifier) {
    val fraction = if (max == null || max <= BigDecimal.ZERO || total <= BigDecimal.ZERO) {
        0f
    } else {
        total.divide(max, 4, RoundingMode.HALF_UP).toFloat().coerceIn(0f, 1f)
    }
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(4.dp)
            .clip(RoundedCornerShape(2.dp))
            .background(MaterialTheme.colorScheme.outlineVariant)
    ) {
        Box(
            Modifier
                .fillMaxWidth(fraction)
                .fillMaxHeight()
                .background(MaterialTheme.colorScheme.primary)
        )
    }
}

/** Money received in a period. Totals count spending only, so this is shown beside them. */
@Composable
fun ReceivedNote(received: BigDecimal, modifier: Modifier = Modifier) {
    if (received <= BigDecimal.ZERO) return
    Text(
        text = "+${AmountFormatter.currencySymbol("MYR")} ${AmountFormatter.formatGrouped(received)} received",
        style = MaterialTheme.typography.bodyMedium,
        color = LocalMoneyColors.current.received,
        modifier = modifier
    )
}

@Composable
fun NetSpendingTotal(
    total: BigDecimal,
    modifier: Modifier = Modifier,
    large: Boolean = false,
    label: String = "Spent"
) {
    Column(modifier = modifier) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        MoneyAmount(
            amount = total,
            style = if (large) MaterialTheme.typography.displayMedium else MaterialTheme.typography.displaySmall,
            symbolScale = 0.45f
        )
    }
}
