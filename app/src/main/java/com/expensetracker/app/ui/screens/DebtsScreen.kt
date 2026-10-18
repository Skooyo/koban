package com.expensetracker.app.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.data.ExpenseEntity
import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.ui.components.MoneyAmount
import com.expensetracker.app.ui.viewmodel.DebtsViewModel
import java.math.BigDecimal
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private fun shortDate(timeMs: Long): String =
    SimpleDateFormat("d MMM", Locale.getDefault()).format(Date(timeMs))

/** "RM 12.00 from Sam, 3 Oct" */
private fun repaymentText(e: ExpenseEntity): String =
    "${AmountFormatter.currencySymbol(e.currency)} ${AmountFormatter.formatGrouped(e.amount)} from " +
        "${e.merchant ?: "unknown"}, ${shortDate(e.notificationPostTime)}"

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DebtsScreen(
    onBack: () -> Unit,
    onOpenSplit: (billId: String) -> Unit,
    viewModel: DebtsViewModel = hiltViewModel()
) {
    val debts by viewModel.debts.collectAsStateWithLifecycle()
    val bills by viewModel.bills.collectAsStateWithLifecycle()
    val paying by viewModel.paying.collectAsStateWithLifecycle()
    val error by viewModel.error.collectAsStateWithLifecycle()
    val byPerson = debts.groupBy { it.debt.personId }.values.toList()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Who owes me") },
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
                .padding(padding)
                .fillMaxSize(),
            contentPadding = PaddingValues(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            error?.let {
                item { Text(it, color = MaterialTheme.colorScheme.error) }
            }
            if (debts.isEmpty()) {
                item {
                    Text(
                        text = "Nobody owes you anything. Split a bill from the Expenses tab.",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            byPerson.forEach { personDebts ->
                item(key = "person-${personDebts.first().debt.personId}") {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = personDebts.first().personName,
                            style = MaterialTheme.typography.titleMedium,
                            modifier = Modifier.weight(1f)
                        )
                        MoneyAmount(
                            amount = personDebts.fold(BigDecimal.ZERO) { sum, d -> sum + d.debt.amount },
                            style = MaterialTheme.typography.titleMedium
                        )
                    }
                    HorizontalDivider(
                        modifier = Modifier.padding(top = 6.dp),
                        color = MaterialTheme.colorScheme.outlineVariant
                    )
                }
                items(personDebts, key = { it.debt.id }) { view ->
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(view.billMerchant ?: "Split bill", style = MaterialTheme.typography.bodyLarge)
                                Text(
                                    text = shortDate(view.billTime),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            MoneyAmount(amount = view.debt.amount, style = MaterialTheme.typography.bodyLarge)
                            TextButton(onClick = { viewModel.startPaying(view) }) { Text("Mark paid") }
                        }
                        view.suggestedRepayment?.let { suggested ->
                            Text(
                                text = "Possible repayment: ${repaymentText(suggested)}",
                                style = MaterialTheme.typography.bodyMedium
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Button(onClick = { viewModel.confirm(view.debt.id) }) { Text("Confirm") }
                                OutlinedButton(onClick = { viewModel.dismiss(view.debt.id) }) { Text("Not this") }
                            }
                        }
                    }
                }
            }
            if (bills.isNotEmpty()) {
                item {
                    Text(
                        text = "Past splits",
                        style = MaterialTheme.typography.titleMedium,
                        modifier = Modifier.padding(top = 24.dp)
                    )
                }
                items(bills, key = { "bill-${it.id}" }) { bill ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable(onClickLabel = "Open") { onOpenSplit(bill.id) }
                            .padding(vertical = 8.dp)
                    ) {
                        Text(
                            text = bill.merchant ?: "Split bill",
                            style = MaterialTheme.typography.bodyLarge,
                            modifier = Modifier.weight(1f)
                        )
                        Text(
                            text = shortDate(bill.billTime),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }

    paying?.let { state ->
        AlertDialog(
            onDismissRequest = viewModel::cancelPaying,
            title = { Text("Mark paid") },
            text = {
                Column {
                    state.candidates.forEach { expense ->
                        TextButton(onClick = { viewModel.markPaid(expense.id) }) { Text(repaymentText(expense)) }
                    }
                    TextButton(onClick = { viewModel.markPaid(null) }) { Text("Paid in cash") }
                }
            },
            confirmButton = {},
            dismissButton = { TextButton(onClick = viewModel::cancelPaying) { Text("Cancel") } }
        )
    }
}
