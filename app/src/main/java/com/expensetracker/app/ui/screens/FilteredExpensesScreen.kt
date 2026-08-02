package com.expensetracker.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.data.ParseConfidence
import com.expensetracker.app.ui.components.EditExpenseDialog
import com.expensetracker.app.ui.components.ExpenseListCard
import com.expensetracker.app.ui.components.NetSpendingTotal
import com.expensetracker.app.ui.viewmodel.FilteredExpensesViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FilteredExpensesScreen(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: FilteredExpensesViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val categories by viewModel.categories.collectAsStateWithLifecycle()
    val editing by viewModel.editingExpense.collectAsStateWithLifecycle()

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(
                title = { Text(uiState.title) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f)
                    )
                ) {
                    NetSpendingTotal(
                        total = uiState.total,
                        modifier = Modifier.padding(16.dp),
                        large = false
                    )
                }
            }
            if (uiState.expenses.isEmpty()) {
                item {
                    Text(
                        text = "No transactions in this period.",
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
                        onDelete = { viewModel.delete(expense) },
                        showConfidence = expense.confidence != ParseConfidence.HIGH
                    )
                }
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
