package com.expensetracker.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.data.ParseConfidence
import com.expensetracker.app.ui.components.EditExpenseDialog
import com.expensetracker.app.ui.components.ExpenseListCard
import com.expensetracker.app.ui.viewmodel.ExpensesViewModel

@Composable
fun ExpensesScreen(
    modifier: Modifier = Modifier,
    viewModel: ExpensesViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val categories by viewModel.categories.collectAsStateWithLifecycle()
    val editing by viewModel.editingExpense.collectAsStateWithLifecycle()

    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        item {
            Text(
                text = "All transactions",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = "Edit or delete false positives. Low-confidence items are marked.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 8.dp)
            )
        }
        if (uiState.expenses.isEmpty()) {
            item {
                Text(
                    text = "No expenses recorded yet.",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            items(uiState.expenses, key = { it.id }) { expense ->
                ExpenseListCard(
                    expense = expense,
                    categoryName = viewModel.categoryNameFor(expense, uiState.categoryNames),
                    onEdit = { viewModel.startEditing(expense) },
                    onDelete = { viewModel.dismiss(expense) },
                    showConfidence = expense.confidence != ParseConfidence.HIGH
                )
            }
        }
    }

    editing?.let { expense ->
        EditExpenseDialog(
            expense = expense,
            categories = categories,
            onDismiss = viewModel::clearEditing,
            onSave = viewModel::saveEdit
        )
    }
}
