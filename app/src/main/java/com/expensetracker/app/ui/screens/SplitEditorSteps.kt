package com.expensetracker.app.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.expensetracker.app.data.ExpenseEntity
import com.expensetracker.app.data.ME_ID
import com.expensetracker.app.data.SplitPersonEntity
import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.ui.components.MoneyAmount
import com.expensetracker.app.ui.viewmodel.ItemRow
import com.expensetracker.app.ui.viewmodel.SplitEditorState
import com.expensetracker.app.ui.viewmodel.SplitEditorViewModel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun PeopleStep(
    modifier: Modifier,
    state: SplitEditorState,
    recent: List<SplitPersonEntity>,
    vm: SplitEditorViewModel
) {
    var name by remember { mutableStateOf("") }
    val picked = state.people.map { it.id }.toSet()
    val addName = {
        vm.addPerson(name)
        name = ""
    }
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Text("Who is sharing?", style = MaterialTheme.typography.headlineMedium)
            Text(
                "Tap a name to add or remove it.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        item {
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                FilterChip(selected = true, onClick = {}, enabled = false, label = { Text("Me") })
                state.people.forEach { person ->
                    FilterChip(
                        selected = true,
                        onClick = { vm.togglePerson(person) },
                        label = { Text(person.name) }
                    )
                }
                recent.filter { it.id !in picked }.forEach { person ->
                    FilterChip(
                        selected = false,
                        onClick = { vm.togglePerson(person) },
                        label = { Text(person.name) }
                    )
                }
            }
        }
        item {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("New person") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { addName() }),
                    modifier = Modifier.weight(1f)
                )
                Button(onClick = addName, enabled = name.isNotBlank()) { Text("Add") }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun AssignStep(modifier: Modifier, state: SplitEditorState, vm: SplitEditorViewModel) {
    val missing = SplitEditorViewModel.unassigned(state)
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Text("Who had what?", style = MaterialTheme.typography.headlineMedium)
            Text(
                "Tap names to share each item. Shared items split evenly.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        items(state.items, key = { it.key }) { row: ItemRow ->
            val unassigned = row.key in missing
            Card(
                border = if (unassigned) BorderStroke(2.dp, MaterialTheme.colorScheme.error) else null,
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 16.dp, end = 16.dp, top = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        if (row.quantity.trim() == "1") row.name else "${row.quantity} × ${row.name}",
                        style = MaterialTheme.typography.titleMedium,
                        modifier = Modifier.weight(1f)
                    )
                    AmountFormatter.parseInput(row.price)?.let {
                        MoneyAmount(it, MaterialTheme.typography.titleMedium)
                    }
                }
                if (unassigned) {
                    Text(
                        "Pick at least one person",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                    )
                }
                FlowRow(
                    modifier = Modifier.padding(16.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    FilterChip(
                        selected = ME_ID in row.sharedBy,
                        onClick = { vm.toggleShare(row.key, ME_ID) },
                        label = { Text("Me") }
                    )
                    state.people.forEach { person ->
                        FilterChip(
                            selected = person.id in row.sharedBy,
                            onClick = { vm.toggleShare(row.key, person.id) },
                            label = { Text(person.name) }
                        )
                    }
                }
            }
        }
    }
}

@Composable
internal fun LinkStep(modifier: Modifier, state: SplitEditorState, vm: SplitEditorViewModel) {
    val total = SplitEditorViewModel.totalOf(state)
    val selected = state.candidates.firstOrNull { it.id == state.selectedExpenseId }
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        item {
            Text("Which payment was this?", style = MaterialTheme.typography.headlineMedium)
            Text(
                "Link the card payment so your spending counts only your share.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 8.dp)
            )
        }
        items(state.candidates, key = { it.id }) { expense ->
            PaymentOption(
                selected = expense.id == state.selectedExpenseId,
                onSelect = { vm.selectExpense(expense.id) }
            ) { PaymentLabel(expense) }
        }
        item {
            PaymentOption(
                selected = state.selectedExpenseId == null,
                onSelect = { vm.selectExpense(null) }
            ) { Text("Not paid by card", style = MaterialTheme.typography.bodyLarge) }
        }
        state.error?.let { item { Text(it, color = MaterialTheme.colorScheme.error) } }
        if (selected != null && total != null && selected.amount.compareTo(total) != 0) {
            item {
                Text(
                    "The payment is RM ${AmountFormatter.formatDisplay(selected.amount)}, " +
                        "the receipt is RM ${AmountFormatter.formatDisplay(total)}. " +
                        "Your share absorbs the difference.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(top = 12.dp)
                )
            }
        }
    }
}

@Composable
private fun PaymentOption(selected: Boolean, onSelect: () -> Unit, label: @Composable () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .selectable(selected = selected, onClick = onSelect, role = Role.RadioButton),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        RadioButton(selected = selected, onClick = null)
        label()
    }
}

@Composable
private fun PaymentLabel(expense: ExpenseEntity) {
    val date = SimpleDateFormat("d MMM, h:mm a", Locale.ENGLISH).format(Date(expense.notificationPostTime))
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        androidx.compose.foundation.layout.Column(modifier = Modifier.weight(1f)) {
            Text(expense.merchant ?: "Payment", style = MaterialTheme.typography.bodyLarge)
            Text(
                date,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        MoneyAmount(expense.amount, MaterialTheme.typography.titleMedium)
    }
}

@Composable
internal fun SummaryStep(
    modifier: Modifier,
    state: SplitEditorState,
    vm: SplitEditorViewModel,
    onShare: (String) -> Unit
) {
    val lines = SplitEditorViewModel.summaryLines(state).orEmpty()
    val total = SplitEditorViewModel.totalOf(state)
    var confirmDelete by remember { mutableStateOf(false) }
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Text("Summary", style = MaterialTheme.typography.headlineMedium)
            if (state.locked) {
                Text(
                    "Someone has paid you back, so the items can't change.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        items(lines) { (name, amount) ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 48.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(name, style = MaterialTheme.typography.bodyLarge)
                MoneyAmount(amount, MaterialTheme.typography.titleMedium)
            }
        }
        if (total != null) {
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Total", style = MaterialTheme.typography.titleMedium)
                    MoneyAmount(total, MaterialTheme.typography.titleLarge)
                }
            }
        }
        state.error?.let {
            item { Text(it, color = MaterialTheme.colorScheme.error) }
        }
        item {
            OutlinedButton(
                onClick = { SplitEditorViewModel.shareText(state)?.let(onShare) },
                modifier = Modifier.fillMaxWidth()
            ) { Text("Share summary") }
        }
        if (state.billId != null) {
            item {
                if (state.locked) {
                    OutlinedButton(onClick = vm::changePayment, enabled = !state.saving, modifier = Modifier.fillMaxWidth()) {
                        Text("Change payment")
                    }
                } else {
                    OutlinedButton(onClick = vm::editItems, enabled = !state.saving, modifier = Modifier.fillMaxWidth()) {
                        Text("Edit items")
                    }
                }
                TextButton(
                    onClick = { confirmDelete = true },
                    enabled = !state.saving,
                    modifier = Modifier.fillMaxWidth()
                ) { Text("Delete split", color = MaterialTheme.colorScheme.error) }
            }
        }
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete this split?") },
            text = { Text("The bill and what people owe are removed. Your payment counts in full again.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    vm.deleteSplit()
                }) { Text("Delete split") }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Cancel") } }
        )
    }
}
