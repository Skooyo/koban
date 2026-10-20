package com.expensetracker.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.expensetracker.app.data.ExpenseEntity
import com.expensetracker.app.data.OwedItemEntity
import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.ui.components.PastDatePickerDialog
import com.expensetracker.app.ui.viewmodel.DebtPayment
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import java.math.BigDecimal
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

internal fun personDate(timeMs: Long): String =
    SimpleDateFormat("d MMM", Locale.getDefault()).format(Date(timeMs))

/** "RM 12.00 from Sam, 3 Oct" */
internal fun receiveText(e: ExpenseEntity): String =
    "${AmountFormatter.currencySymbol(e.currency)} ${AmountFormatter.formatGrouped(e.amount)} from " +
        "${e.merchant ?: "unknown"}, ${personDate(e.notificationPostTime)}"

private fun count(n: Int, one: String, many: String) = "$n ${if (n == 1) one else many}"

/** Runs [save]; on failure keeps the dialog open and returns the message to show in it. */
private suspend fun attempt(save: suspend () -> Unit): String? =
    try {
        save()
        null
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) {
        e.message ?: "Something went wrong. Try again."
    }

@Composable
internal fun RenameDialog(name: String, onDismiss: () -> Unit, onSave: suspend (String) -> Unit) {
    val scope = rememberCoroutineScope()
    var text by remember { mutableStateOf(name) }
    var error by remember { mutableStateOf<String?>(null) }
    var saving by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Rename") },
        text = {
            OutlinedTextField(
                value = text,
                onValueChange = {
                    text = it
                    error = null
                },
                label = { Text("Name") },
                singleLine = true,
                isError = error != null,
                supportingText = error?.let { message -> { Text(message) } },
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words)
            )
        },
        confirmButton = {
            TextButton(enabled = !saving, onClick = {
                saving = true
                scope.launch {
                    error = attempt { onSave(text) }
                    saving = false
                    if (error == null) onDismiss()
                }
            }) { Text("Save") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}

/** Add (when [item] is null) or edit one thing the owner owes. */
@Composable
internal fun OwedItemDialog(
    item: OwedItemEntity?,
    onDismiss: () -> Unit,
    onSave: suspend (description: String, amount: BigDecimal, itemDate: Long) -> Unit,
    onDelete: (() -> Unit)?
) {
    val scope = rememberCoroutineScope()
    var description by remember { mutableStateOf(item?.description.orEmpty()) }
    var amountText by remember { mutableStateOf(item?.amount?.let(AmountFormatter::formatDisplay).orEmpty()) }
    var itemDate by remember { mutableStateOf(item?.itemDate ?: System.currentTimeMillis()) }
    var pickingDate by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var saving by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (item == null) "Add what I owe" else "Edit what I owe") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = description,
                    onValueChange = {
                        description = it
                        error = null
                    },
                    label = { Text("What for") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = amountText,
                    onValueChange = {
                        amountText = it
                        error = null
                    },
                    label = { Text("Amount") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedButton(onClick = { pickingDate = true }, modifier = Modifier.fillMaxWidth()) {
                    Text("Date: " + SimpleDateFormat("EEE, d MMM yyyy", Locale.getDefault()).format(Date(itemDate)))
                }
                if (onDelete != null) {
                    TextButton(onClick = onDelete, modifier = Modifier.fillMaxWidth()) {
                        Text("Delete", color = MaterialTheme.colorScheme.error)
                    }
                }
                error?.let { Text(text = it, color = MaterialTheme.colorScheme.error) }
            }
        },
        confirmButton = {
            TextButton(enabled = !saving, onClick = {
                saving = true
                scope.launch {
                    // An unreadable amount reaches the repository as zero and gets its message.
                    val amount = AmountFormatter.parseInput(amountText) ?: BigDecimal.ZERO
                    error = attempt { onSave(description, amount, itemDate) }
                    saving = false
                    if (error == null) onDismiss()
                }
            }) { Text("Save") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )

    if (pickingDate) {
        PastDatePickerDialog(
            time = itemDate,
            onDismiss = { pickingDate = false },
            onPicked = {
                itemDate = it
                pickingDate = false
            }
        )
    }
}

@Composable
internal fun SettleUpDialog(name: String, debtCount: Int, itemCount: Int, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    val closes = listOfNotNull(
        count(debtCount, "split bill debt", "split bill debts").takeIf { debtCount > 0 },
        count(itemCount, "item you owe", "items you owe").takeIf { itemCount > 0 }
    ).joinToString(" and ")
    val lock = if (debtCount > 0) " Split bills it touches can't be edited after this." else ""
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Settle up with $name?") },
        text = { Text("Closes $closes.$lock") },
        confirmButton = { TextButton(onClick = onConfirm) { Text("Settle up") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}

@Composable
internal fun DeletePersonDialog(name: String, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Delete $name?") },
        text = { Text("Their QR and paid items are removed. Split bills keep their name.") },
        confirmButton = {
            TextButton(onClick = onConfirm) { Text("Delete", color = MaterialTheme.colorScheme.error) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}

/** Mark paid for one split debt: pick the received payment, or cash. */
@Composable
internal fun DebtPaymentDialog(state: DebtPayment, onPick: (expenseId: String?) -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Mark paid") },
        text = {
            Column {
                state.candidates.forEach { expense ->
                    TextButton(onClick = { onPick(expense.id) }) { Text(receiveText(expense)) }
                }
                TextButton(onClick = { onPick(null) }) { Text("Paid in cash") }
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}
