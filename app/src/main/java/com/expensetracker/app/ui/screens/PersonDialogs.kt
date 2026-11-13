package com.expensetracker.app.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.expensetracker.app.data.ExpenseEntity
import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.ui.components.DialogTextField
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

private val DialogShape = RoundedCornerShape(24.dp)

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
        shape = DialogShape,
        containerColor = MaterialTheme.colorScheme.surfaceContainer,
        onDismissRequest = onDismiss,
        title = { Text("Rename") },
        text = {
            DialogTextField(
                value = text,
                onValueChange = {
                    text = it
                    error = null
                },
                label = "Name",
                isError = error != null,
                supportingText = error,
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

/** Add (when [amount] is null) or edit one hand-entered amount, owed either way. */
@Composable
internal fun OwedItemDialog(
    title: String,
    onDismiss: () -> Unit,
    onSave: suspend (description: String, amount: BigDecimal, itemDate: Long) -> Unit,
    onDelete: (() -> Unit)?,
    description: String = "",
    amount: BigDecimal? = null,
    itemDate: Long? = null
) {
    val scope = rememberCoroutineScope()
    var description by remember { mutableStateOf(description) }
    var amountText by remember { mutableStateOf(amount?.let(AmountFormatter::formatDisplay).orEmpty()) }
    var itemDate by remember { mutableStateOf(itemDate ?: System.currentTimeMillis()) }
    var pickingDate by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var saving by remember { mutableStateOf(false) }

    AlertDialog(
        shape = DialogShape,
        containerColor = MaterialTheme.colorScheme.surfaceContainer,
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                DialogTextField(
                    value = description,
                    onValueChange = {
                        description = it
                        error = null
                    },
                    label = "What for",
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences)
                )
                DialogTextField(
                    value = amountText,
                    onValueChange = {
                        amountText = it
                        error = null
                    },
                    label = "Amount",
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
                )
                Row(
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 56.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(MaterialTheme.colorScheme.surfaceContainerHigh)
                        .clickable(onClickLabel = "Pick date", role = Role.Button) { pickingDate = true }
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Default.DateRange, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(
                            SimpleDateFormat("EEE, d MMM yyyy", Locale.getDefault()).format(Date(itemDate)),
                            style = MaterialTheme.typography.titleSmall
                        )
                        Text("Date", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
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
        shape = DialogShape,
        containerColor = MaterialTheme.colorScheme.surfaceContainer,
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
        shape = DialogShape,
        containerColor = MaterialTheme.colorScheme.surfaceContainer,
        onDismissRequest = onDismiss,
        title = { Text("Delete $name?") },
        text = { Text("Their QR and paid items are removed. Split bills keep their name.") },
        confirmButton = {
            TextButton(onClick = onConfirm) { Text("Delete", color = MaterialTheme.colorScheme.error) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}

@Composable
internal fun DeleteOwedItemDialog(text: String, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        shape = DialogShape,
        containerColor = MaterialTheme.colorScheme.surfaceContainer,
        onDismissRequest = onDismiss,
        title = { Text("Delete this item?") },
        text = { Text(text) },
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
        shape = DialogShape,
        containerColor = MaterialTheme.colorScheme.surfaceContainer,
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
