package com.expensetracker.app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.expensetracker.app.data.CategoryEntity
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.data.ExpenseEntity
import com.expensetracker.app.data.TransactionType
import com.expensetracker.app.parser.AmountFormatter
import java.math.BigDecimal
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditExpenseDialog(
    expense: ExpenseEntity,
    categories: List<CategoryEntity>,
    onDismiss: () -> Unit,
    title: String = "Edit expense",
    onSplit: (() -> Unit)? = null,
    onSave: (
        amount: BigDecimal,
        merchant: String?,
        postTime: Long,
        categoryId: String?,
        notes: String?,
        transactionType: TransactionType
    ) -> Unit
) {
    var amountText by remember(expense.id) {
        mutableStateOf(if (expense.amount.signum() == 0) "" else AmountFormatter.formatDisplay(expense.amount))
    }
    var postTime by remember(expense.id) { mutableStateOf(expense.notificationPostTime) }
    var pickingDate by remember { mutableStateOf(false) }
    var merchantText by remember(expense.id) { mutableStateOf(expense.merchant ?: "") }
    var notesText by remember(expense.id) { mutableStateOf(expense.notes ?: "") }
    var selectedCategoryId by remember(expense.id) { mutableStateOf(expense.categoryId) }
    var selectedType by remember(expense.id) { mutableStateOf(expense.transactionType) }
    var categoryExpanded by remember { mutableStateOf(false) }
    var typeExpanded by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    val selectedCategoryLabel = categories.find { it.id == selectedCategoryId }?.name
        ?: DefaultCategories.UNCATEGORIZED_NAME

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = amountText,
                    onValueChange = { amountText = it },
                    label = { Text("Amount") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = merchantText,
                    onValueChange = { merchantText = it },
                    label = { Text("Merchant") },
                    supportingText = { Text("A new category also applies to past payments from this merchant") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                ExposedDropdownMenuBox(
                    expanded = typeExpanded,
                    onExpandedChange = { typeExpanded = it }
                ) {
                    OutlinedTextField(
                        value = if (selectedType == TransactionType.WITHDRAW) "Withdraw" else "Receive",
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Type") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = typeExpanded) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .menuAnchor()
                    )
                    ExposedDropdownMenu(
                        expanded = typeExpanded,
                        onDismissRequest = { typeExpanded = false }
                    ) {
                        DropdownMenuItem(
                            text = { Text("Withdraw (adds to spending)") },
                            onClick = {
                                selectedType = TransactionType.WITHDRAW
                                typeExpanded = false
                            }
                        )
                        DropdownMenuItem(
                            text = { Text("Receive (reduces spending)") },
                            onClick = {
                                selectedType = TransactionType.RECEIVE
                                typeExpanded = false
                            }
                        )
                    }
                }
                ExposedDropdownMenuBox(
                    expanded = categoryExpanded,
                    onExpandedChange = { categoryExpanded = it }
                ) {
                    OutlinedTextField(
                        value = selectedCategoryLabel,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Category") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = categoryExpanded) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .menuAnchor()
                    )
                    ExposedDropdownMenu(
                        expanded = categoryExpanded,
                        onDismissRequest = { categoryExpanded = false }
                    ) {
                        DropdownMenuItem(
                            text = { Text(DefaultCategories.UNCATEGORIZED_NAME) },
                            onClick = {
                                selectedCategoryId = null
                                categoryExpanded = false
                            }
                        )
                        categories.forEach { category ->
                            DropdownMenuItem(
                                text = { Text(category.name) },
                                onClick = {
                                    selectedCategoryId = category.id
                                    categoryExpanded = false
                                }
                            )
                        }
                    }
                }
                OutlinedButton(onClick = { pickingDate = true }, modifier = Modifier.fillMaxWidth()) {
                    Text("Date: " + SimpleDateFormat("EEE, d MMM yyyy", Locale.getDefault()).format(Date(postTime)))
                }
                OutlinedTextField(
                    value = notesText,
                    onValueChange = { notesText = it },
                    label = { Text("Notes") },
                    placeholder = { Text("Add a personal note…") },
                    minLines = 2,
                    modifier = Modifier.fillMaxWidth()
                )
                if (onSplit != null && selectedType == TransactionType.WITHDRAW) {
                    TextButton(onClick = onSplit, modifier = Modifier.fillMaxWidth()) {
                        Text("Split this bill")
                    }
                }
                error?.let {
                    Text(text = it, color = MaterialTheme.colorScheme.error)
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val amount = AmountFormatter.parseInput(amountText)
                    if (amount == null || amount.signum() <= 0) {
                        error = "Enter an amount above 0"
                        return@TextButton
                    }
                    onSave(
                        amount,
                        merchantText.ifBlank { null },
                        postTime,
                        selectedCategoryId,
                        notesText,
                        selectedType
                    )
                }
            ) {
                Text("Save")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )

    if (pickingDate) {
        val pickerState = rememberDatePickerState(
            initialSelectedDateMillis = localDateAsUtcMillis(postTime),
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long) =
                    utcTimeMillis <= localDateAsUtcMillis(System.currentTimeMillis())
            }
        )
        DatePickerDialog(
            onDismissRequest = { pickingDate = false },
            confirmButton = {
                TextButton(onClick = {
                    pickerState.selectedDateMillis?.let { postTime = withDate(postTime, it) }
                    pickingDate = false
                }) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { pickingDate = false }) { Text("Cancel") }
            }
        ) {
            DatePicker(state = pickerState)
        }
    }
}

/** The DatePicker works in UTC midnights; this is the local date of [time] as one. */
private fun localDateAsUtcMillis(time: Long): Long {
    val local = Calendar.getInstance().apply { timeInMillis = time }
    return Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
        clear()
        set(local.get(Calendar.YEAR), local.get(Calendar.MONTH), local.get(Calendar.DAY_OF_MONTH))
    }.timeInMillis
}

/** [time] moved to the picked date, keeping its local time of day. */
private fun withDate(time: Long, utcDateMillis: Long): Long {
    val picked = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { timeInMillis = utcDateMillis }
    return Calendar.getInstance().apply {
        timeInMillis = time
        set(picked.get(Calendar.YEAR), picked.get(Calendar.MONTH), picked.get(Calendar.DAY_OF_MONTH))
    }.timeInMillis
}
