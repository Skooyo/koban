package com.expensetracker.app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.expensetracker.app.data.CategoryBreakdown
import com.expensetracker.app.ui.theme.categoryColor

/** Legend for [NoteStrip]: one line per category with its colour and total. */
@Composable
fun CategoryBreakdownList(
    breakdown: List<CategoryBreakdown>,
    modifier: Modifier = Modifier
) {
    if (breakdown.isEmpty()) return

    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        breakdown.forEach { item ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .categoryFill(item.categoryId, categoryColor(item.categoryId))
                )
                Text(
                    text = item.name,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier
                        .weight(1f)
                        .padding(start = 10.dp)
                )
                MoneyAmount(
                    amount = item.total,
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }
    }
}
