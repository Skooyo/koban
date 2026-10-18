package com.expensetracker.app.ui.screens

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.ui.components.EditExpenseDialog
import com.expensetracker.app.ui.components.expensesByDay
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
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 16.dp)
    ) {
        item {
            Text(
                text = "All transactions",
                style = MaterialTheme.typography.headlineMedium
            )
            Text(
                text = "Tap a transaction to fix it. Delete anything that is not a real payment.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 4.dp)
            )
        }
        if (uiState.expenses.isEmpty()) {
            item {
                Text(
                    text = "No transactions yet. Payments appear here when your bank or e-wallet sends a notification.",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 24.dp)
                )
            }
        } else {
            expensesByDay(
                expenses = uiState.expenses,
                categoryName = { viewModel.categoryNameFor(it, uiState.categoryNames) },
                onEdit = viewModel::startEditing,
                onDelete = viewModel::dismiss
            )
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
