package com.expensetracker.app.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Surface
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
import com.expensetracker.app.ui.components.InitialsAvatar
import com.expensetracker.app.ui.components.KobanRow
import com.expensetracker.app.ui.components.ListGroup
import com.expensetracker.app.ui.components.Mon
import com.expensetracker.app.ui.components.MonFace
import com.expensetracker.app.ui.components.MoneyText
import com.expensetracker.app.ui.components.TonalButton
import com.expensetracker.app.ui.theme.LocalMoneyColors
import com.expensetracker.app.ui.viewmodel.ItemRow
import com.expensetracker.app.ui.viewmodel.SplitEditorState
import com.expensetracker.app.ui.viewmodel.SplitEditorViewModel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Selected: primaryContainer fill with a check icon. Unselected: outlined. */
@Composable
private fun PersonChip(name: String, selected: Boolean, enabled: Boolean = true, onClick: () -> Unit) {
    FilterChip(
        selected = selected,
        onClick = onClick,
        enabled = enabled,
        label = { Text(name, style = MaterialTheme.typography.labelLarge) },
        leadingIcon = if (selected) {
            { Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(FilterChipDefaults.IconSize)) }
        } else null,
        colors = FilterChipDefaults.filterChipColors(
            selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
            selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer,
            selectedLeadingIconColor = MaterialTheme.colorScheme.onPrimaryContainer,
            disabledSelectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
            disabledLabelColor = MaterialTheme.colorScheme.onPrimaryContainer,
            disabledLeadingIconColor = MaterialTheme.colorScheme.onPrimaryContainer
        )
    )
}

@Composable
private fun StepIntro(text: String) {
    Text(text, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

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
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Text("Who is sharing?", style = MaterialTheme.typography.headlineMedium)
            Spacer(Modifier.size(8.dp))
            StepIntro("Tap a name to add or remove it.")
        }
        item {
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                PersonChip("Me", selected = true, enabled = false, onClick = {})
                state.people.forEach { person ->
                    PersonChip(person.name, selected = true, onClick = { vm.togglePerson(person) })
                }
                recent.filter { it.id !in picked }.forEach { person ->
                    PersonChip(person.name, selected = false, onClick = { vm.togglePerson(person) })
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
                TonalButton("Add", addName, enabled = name.isNotBlank())
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
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item { StepIntro("Tap names to share each item. A shared item splits evenly.") }
        items(state.items, key = { it.key }) { row: ItemRow ->
            val unassigned = row.key in missing
            Surface(
                shape = RoundedCornerShape(16.dp),
                color = MaterialTheme.colorScheme.surfaceContainer,
                border = if (unassigned) BorderStroke(2.dp, MaterialTheme.colorScheme.error) else null,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            if (row.quantity.trim() == "1") row.name else "${row.name} ×${row.quantity.trim()}",
                            style = MaterialTheme.typography.titleMedium,
                            modifier = Modifier.weight(1f)
                        )
                        AmountFormatter.parseInput(row.price)?.let {
                            MoneyText(splitRm(it), style = MaterialTheme.typography.titleMedium)
                        }
                    }
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        PersonChip("Me", ME_ID in row.sharedBy, onClick = { vm.toggleShare(row.key, ME_ID) })
                        state.people.forEach { person ->
                            PersonChip(person.name, person.id in row.sharedBy, onClick = { vm.toggleShare(row.key, person.id) })
                        }
                    }
                    if (unassigned) {
                        Text(
                            "Pick at least one person",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error
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
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Text("Which payment was this?", style = MaterialTheme.typography.headlineMedium)
            Spacer(Modifier.size(8.dp))
            StepIntro("Link the card payment, so your spending counts only your share.")
        }
        item {
            ListGroup {
                state.candidates.forEach { expense ->
                    item { PaymentOption(expense, expense.id == state.selectedExpenseId) { vm.selectExpense(expense.id) } }
                }
                item {
                    KobanRow(
                        "Not paid by card",
                        Modifier.selectable(selected = state.selectedExpenseId == null, role = Role.RadioButton) {
                            vm.selectExpense(null)
                        },
                        leading = { RadioButton(selected = state.selectedExpenseId == null, onClick = null) }
                    )
                }
            }
        }
        state.error?.let { item { Text(it, color = MaterialTheme.colorScheme.error) } }
        if (selected != null && total != null && selected.amount.compareTo(total) != 0) {
            item {
                val review = LocalMoneyColors.current.review
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = MaterialTheme.colorScheme.surfaceContainer,
                    border = BorderStroke(1.dp, review),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Icon(
                            Icons.Default.Info, contentDescription = null,
                            tint = review, modifier = Modifier.size(20.dp)
                        )
                        Text(
                            "The payment is ${splitRm(selected.amount)}, the receipt is ${splitRm(total)}. " +
                                "Your share absorbs the difference.",
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PaymentOption(expense: ExpenseEntity, selected: Boolean, onSelect: () -> Unit) {
    val date = SimpleDateFormat("EEE, d MMM, HH:mm", Locale.ENGLISH).format(Date(expense.notificationPostTime))
    KobanRow(
        expense.merchant ?: "Payment",
        Modifier.selectable(selected = selected, role = Role.RadioButton, onClick = onSelect),
        subtitle = date,
        leading = { RadioButton(selected = selected, onClick = null) },
        trailing = { MoneyText(splitRm(expense.amount)) }
    )
}

private fun joinNames(names: List<String>): String =
    if (names.size <= 1) names.joinToString() else names.dropLast(1).joinToString(", ") + " and " + names.last()

@OptIn(ExperimentalLayoutApi::class)
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
    // The last line is always "Me"; everyone before it owes the user.
    val owing = lines.dropLast(1).map { it.first }
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Mon(MonFace.HAPPY, 56.dp)
                Column {
                    Text("Split done", style = MaterialTheme.typography.headlineMedium)
                    if (state.locked) {
                        StepIntro("Someone has paid you back, so the items can't change.")
                    } else if (owing.isNotEmpty()) {
                        StepIntro("${joinNames(owing)} now ${if (owing.size == 1) "owes" else "owe"} you.")
                    }
                }
            }
        }
        item {
            ListGroup {
                lines.forEach { (name, amount) ->
                    item {
                        KobanRow(
                            name,
                            leading = { InitialsAvatar(name) },
                            trailing = { MoneyText(splitRm(amount)) }
                        )
                    }
                }
            }
        }
        if (total != null) {
            item {
                ListGroup {
                    item {
                        KobanRow(
                            "Total",
                            trailing = { MoneyText(splitRm(total), style = MaterialTheme.typography.titleLarge) }
                        )
                    }
                }
            }
        }
        state.error?.let {
            item { Text(it, color = MaterialTheme.colorScheme.error) }
        }
        item {
            FlowRow(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                TonalButton(
                    "Share summary",
                    onClick = { SplitEditorViewModel.shareText(state)?.let(onShare) },
                    icon = Icons.Default.Share
                )
                if (state.billId != null) {
                    if (state.locked) {
                        TextButton(onClick = vm::changePayment, enabled = !state.saving, modifier = Modifier.heightIn(min = 48.dp)) {
                            Icon(Icons.Default.Edit, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(8.dp))
                            Text("Change payment")
                        }
                    } else {
                        TextButton(onClick = vm::editItems, enabled = !state.saving, modifier = Modifier.heightIn(min = 48.dp)) {
                            Icon(Icons.Default.Edit, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(8.dp))
                            Text("Edit items")
                        }
                    }
                }
            }
        }
        if (state.billId != null) {
            item {
                TextButton(
                    onClick = { confirmDelete = true },
                    enabled = !state.saving,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
                ) {
                    Icon(
                        Icons.Default.Delete, contentDescription = null,
                        tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(18.dp)
                    )
                    Spacer(Modifier.width(8.dp))
                    Text("Delete split", color = MaterialTheme.colorScheme.error)
                }
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
