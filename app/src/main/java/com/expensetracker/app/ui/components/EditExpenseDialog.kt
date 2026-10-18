package com.expensetracker.app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditExpenseDialog(
    expense: ExpenseEntity,
    categories: List<CategoryEntity>,
    onDismiss: () -> Unit,
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
        mutableStateOf(AmountFormatter.formatDisplay(expense.amount))
    }
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
        title = { Text("Edit expense") },
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
                    supportingText = { Text("Category is remembered for this merchant") },
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
                    if (amount == null) {
                        error = "Invalid amount"
                        return@TextButton
                    }
                    onSave(
                        amount,
                        merchantText.ifBlank { null },
                        expense.notificationPostTime,
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
}
