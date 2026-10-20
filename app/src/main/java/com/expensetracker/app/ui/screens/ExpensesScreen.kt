package com.expensetracker.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.ui.Alignment
import com.expensetracker.app.ui.components.CategoryFilterRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
    onSplit: (expenseId: String?) -> Unit,
    onPeople: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: ExpensesViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val categories by viewModel.categories.collectAsStateWithLifecycle()
    val openPeople by viewModel.openPeopleCount.collectAsStateWithLifecycle()
    val editing by viewModel.editingExpense.collectAsStateWithLifecycle()

    Box(modifier = modifier.fillMaxSize()) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 16.dp, bottom = 96.dp)
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
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.padding(top = 12.dp)
                ) {
                    OutlinedButton(onClick = { onSplit(null) }) { Text("Split a bill") }
                    OutlinedButton(onClick = onPeople) {
                        Text(if (openPeople > 0) "People ($openPeople)" else "People")
                    }
                }
                CategoryFilterRow(
                    categories = categories,
                    selected = uiState.categoryFilter,
                    onSelect = viewModel::setCategoryFilter,
                    modifier = Modifier.padding(top = 12.dp)
                )
            }
            if (uiState.expenses.isEmpty()) {
                item {
                    Text(
                        text = if (uiState.categoryFilter == null) {
                            "No transactions yet. Payments appear here when your bank or e-wallet sends a notification."
                        } else {
                            "No transactions in this category."
                        },
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
        FloatingActionButton(
            onClick = viewModel::startAdding,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(16.dp)
        ) {
            Icon(Icons.Default.Add, contentDescription = "Add a payment")
        }
    }

    editing?.let { expense ->
        val adding = viewModel.isAdding(expense)
        EditExpenseDialog(
            expense = expense,
            categories = categories,
            onDismiss = viewModel::clearEditing,
            title = if (adding) "Add payment" else "Edit expense",
            onSplit = if (adding) null else {
                {
                    viewModel.clearEditing()
                    onSplit(expense.id)
                }
            },
            onSave = viewModel::saveEdit
        )
    }
}
