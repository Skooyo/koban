package com.expensetracker.app.ui.screens

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
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
import com.expensetracker.app.ui.components.EditExpenseDialog
import com.expensetracker.app.ui.components.NetSpendingTotal
import com.expensetracker.app.ui.components.expensesByDay
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
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, bottom = 16.dp)
        ) {
            item {
                NetSpendingTotal(total = uiState.total)
            }
            if (uiState.expenses.isEmpty()) {
                item {
                    Text(
                        text = "No transactions in this period.",
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
                    onDelete = viewModel::delete
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
