package com.expensetracker.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.expensetracker.app.data.TransactionType

/** Collects the rows of a [ListGroup]. */
class ListGroupScope {
    internal val items = mutableListOf<@Composable () -> Unit>()

    /** Adds one row. */
    fun item(content: @Composable () -> Unit) {
        items += content
    }
}

/** One rounded group of rows. Call `item { KobanRow(...) }` per row; a divider shows between rows only. */
@Composable
fun ListGroup(modifier: Modifier = Modifier, content: ListGroupScope.() -> Unit) {
    val rows = ListGroupScope().apply(content).items
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceContainer)
    ) {
        rows.forEachIndexed { i, row ->
            if (i > 0) HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            row()
        }
    }
}

/** A list row with optional subtitle, trailing content and chevron; leading is centered in a 40 dp box; pass a 24 dp icon or an avatar. */
@Composable
fun KobanRow(
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    subtitleColor: Color = Color.Unspecified,
    leading: (@Composable () -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
    showChevron: Boolean = false,
    onClick: (() -> Unit)? = null,
    minHeight: Dp = 56.dp,
    titleSuffix: (@Composable () -> Unit)? = null,
    onClickLabel: String? = null,
    subtitleMaxLines: Int = Int.MAX_VALUE
) {
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    Row(
        modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(role = Role.Button, onClickLabel = onClickLabel, onClick = onClick) else Modifier)
            .defaultMinSize(minHeight = minHeight)
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (leading != null) {
            CompositionLocalProvider(LocalContentColor provides muted) {
                Box(Modifier.size(40.dp), contentAlignment = Alignment.Center) { leading() }
            }
            Spacer(Modifier.width(12.dp))
        }
        Column(Modifier.weight(1f)) {
            if (titleSuffix == null) {
                Text(title, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurface)
            } else {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        title,
                        Modifier.weight(1f, fill = false),
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    titleSuffix()
                }
            }
            if (subtitle != null) {
                Text(
                    subtitle,
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (subtitleColor == Color.Unspecified) muted else subtitleColor,
                    maxLines = subtitleMaxLines,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
        if (trailing != null) {
            Spacer(Modifier.width(12.dp))
            trailing()
        }
        if (showChevron) {
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = muted,
                modifier = Modifier.padding(start = 8.dp).size(24.dp)
            )
        }
    }
}

@Composable
fun SectionHeading(text: String, modifier: Modifier = Modifier) {
    Text(
        text,
        modifier = modifier.padding(bottom = 8.dp),
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
}

@Composable
fun MoneyText(
    text: String,
    modifier: Modifier = Modifier,
    style: TextStyle = MaterialTheme.typography.titleMedium,
    color: Color = Color.Unspecified
) {
    val tnum = style.copy(fontFeatureSettings = "tnum")
    if (style.fontSize.value <= 40f) {
        Text(text, modifier, color = color, style = tnum, maxLines = 1, softWrap = false)
        return
    }
    // Compose 1.7 has no autoSize: a big amount steps down the display sizes until it fits the width.
    BoxWithConstraints(modifier) {
        val measurer = rememberTextMeasurer()
        val t = MaterialTheme.typography
        val steps = listOf(tnum) + listOf(t.displayMedium, t.displaySmall, t.headlineLarge)
            .filter { it.fontSize < style.fontSize }
            .map { it.copy(color = style.color, fontFeatureSettings = "tnum") }
        val fitted = steps.firstOrNull {
            measurer.measure(text, it, maxLines = 1, softWrap = false).size.width <= constraints.maxWidth
        } ?: steps.last()
        Text(text, color = color, style = fitted, maxLines = 1, softWrap = false)
    }
}

@Composable
fun CategoryDot(color: Color, size: Dp = 10.dp) {
    Box(Modifier.size(size).clip(CircleShape).background(color))
}

/** The big left-aligned title of a top-level tab (Today, Activity, People, Groups). */
@Composable
fun LargeTopBar(
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    actions: @Composable RowScope.() -> Unit = {}
) {
    Row(
        modifier.fillMaxWidth().padding(start = 16.dp, end = 8.dp, top = 16.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, Modifier.semantics { heading() }, style = MaterialTheme.typography.headlineLarge, color = MaterialTheme.colorScheme.onSurface)
            if (subtitle != null) {
                Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        actions()
    }
}

/** Second action: primaryContainer fill. Use [Button] for the one gold action. */
@Composable
fun TonalButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    enabled: Boolean = true
) {
    Button(
        onClick = onClick,
        modifier = modifier.defaultMinSize(minHeight = 48.dp),
        enabled = enabled,
        elevation = ButtonDefaults.buttonElevation(0.dp, 0.dp, 0.dp, 0.dp, 0.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer,
            contentColor = MaterialTheme.colorScheme.onPrimaryContainer
        )
    ) {
        if (icon != null) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
        }
        Text(text, style = MaterialTheme.typography.labelLarge)
    }
}

/**
 * Spent / Received. [onPick] null makes it a plain display; [selected] null means neither is chosen yet.
 */
@Composable
fun DirectionSegments(selected: TransactionType?, onPick: ((TransactionType) -> Unit)?, modifier: Modifier = Modifier, onTapWhenFixed: (() -> Unit)? = null) {
    Row(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        listOf("Spent" to TransactionType.WITHDRAW, "Received" to TransactionType.RECEIVE).forEach { (label, type) ->
            val on = selected == type
            Segment(
                label = label,
                on = on,
                action = when {
                    onPick != null -> Modifier.selectable(selected = on, role = Role.RadioButton) { onPick(type) }
                    onTapWhenFixed != null -> Modifier.clickable(onClickLabel = "Change payment", onClick = onTapWhenFixed)
                    else -> Modifier
                }
            )
        }
    }
}

/** Two or more choices in one track, for example Month | All. The chosen one is a gold-soft pill. */
@Composable
fun SegmentedControl(labels: List<String>, selectedIndex: Int, onPick: (Int) -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier
            .fillMaxWidth()
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
            .padding(4.dp)
            .selectableGroup(),
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        labels.forEachIndexed { i, label ->
            Segment(label, i == selectedIndex, Modifier.selectable(selected = i == selectedIndex, role = Role.RadioButton) { onPick(i) })
        }
    }
}

@Composable
private fun RowScope.Segment(label: String, on: Boolean, action: Modifier) {
    Box(
        modifier = Modifier
            .weight(1f)
            .heightIn(min = 48.dp)
            .clip(CircleShape)
            .background(if (on) MaterialTheme.colorScheme.primaryContainer else Color.Transparent)
            .then(action),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = if (on) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}
