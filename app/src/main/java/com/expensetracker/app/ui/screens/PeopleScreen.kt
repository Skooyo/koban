package com.expensetracker.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.data.Balance
import com.expensetracker.app.data.PeopleMath
import com.expensetracker.app.data.PersonSummary
import com.expensetracker.app.ui.theme.LocalMoneyColors
import com.expensetracker.app.ui.viewmodel.PeopleViewModel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

internal val Ink = Color(0xFF1B2430)

private fun groupTitle(group: PeopleMath.Group) = when (group) {
    PeopleMath.Group.YOU_OWE -> "You owe"
    PeopleMath.Group.OWES_YOU -> "Owes you"
    PeopleMath.Group.OTHERS -> "Everyone else"
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PeopleScreen(
    onOpenPerson: (String) -> Unit,
    onOpenSplit: (String) -> Unit,
    onSplitBill: () -> Unit,
    viewModel: PeopleViewModel = hiltViewModel()
) {
    val sections by viewModel.sections.collectAsStateWithLifecycle()
    val bills by viewModel.bills.collectAsStateWithLifecycle()
    val query by viewModel.query.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    var adding by remember { mutableStateOf(false) }
    var newName by remember { mutableStateOf("") }
    var addError by remember { mutableStateOf<String?>(null) }
    var saving by remember { mutableStateOf(false) }
    val money = LocalMoneyColors.current
    val avatarColors = listOf(money.red, money.blue, money.orange, money.purple, money.teal)

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("People")
                        Text(
                            text = "Their payment QRs, and what you owe each other",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = {
                    newName = ""
                    addError = null
                    adding = true
                },
                containerColor = money.gold,
                contentColor = Ink,
                icon = { Icon(Icons.Default.Add, contentDescription = null) },
                text = { Text("Add person") }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize(),
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 96.dp)
        ) {
            item {
                OutlinedButton(onClick = onSplitBill, modifier = Modifier.padding(bottom = 12.dp)) {
                    Text("Split a bill")
                }
                OutlinedTextField(
                    value = query,
                    onValueChange = viewModel::setQuery,
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text("Search people") },
                    leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                    singleLine = true
                )
            }
            if (sections.isEmpty()) {
                item {
                    Text(
                        text = if (query.isBlank()) "No people yet. Add someone, or split a bill to start."
                        else "Nobody matches that search.",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 16.dp)
                    )
                }
            }
            sections.forEach { (group, people) ->
                item(key = "group-$group") {
                    Text(
                        text = groupTitle(group),
                        style = MaterialTheme.typography.titleMedium,
                        modifier = Modifier.padding(top = 20.dp, bottom = 4.dp)
                    )
                }
                items(people, key = { "person-${it.person.id}" }) { summary ->
                    PersonRow(
                        summary = summary,
                        avatarColor = avatarColors[Math.floorMod(summary.person.id.hashCode(), avatarColors.size)],
                        onClick = { onOpenPerson(summary.person.id) }
                    )
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
                            .heightIn(min = 48.dp)
                            .clickable(onClickLabel = "Open", role = Role.Button) { onOpenSplit(bill.id) }
                            .padding(vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = bill.merchant ?: "Split bill",
                            style = MaterialTheme.typography.bodyLarge,
                            modifier = Modifier.weight(1f)
                        )
                        Text(
                            text = personDate(bill.billTime),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }

    if (adding) {
        AlertDialog(
            onDismissRequest = { adding = false },
            title = { Text("Add person") },
            text = {
                OutlinedTextField(
                    value = newName,
                    onValueChange = {
                        newName = it
                        addError = null
                    },
                    label = { Text("Name") },
                    singleLine = true,
                    isError = addError != null,
                    supportingText = addError?.let { message -> { Text(message) } },
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words)
                )
            },
            confirmButton = {
                TextButton(enabled = !saving, onClick = {
                    saving = true
                    scope.launch {
                        try {
                            val id = viewModel.add(newName)
                            adding = false
                            onOpenPerson(id)
                        } catch (e: CancellationException) {
                            throw e
                        } catch (e: IllegalArgumentException) {
                            addError = e.message
                        } finally {
                            saving = false
                        }
                    }
                }) { Text("Add") }
            },
            dismissButton = { TextButton(onClick = { adding = false }) { Text("Cancel") } }
        )
    }
}

@Composable
private fun PersonRow(summary: PersonSummary, avatarColor: Color, onClick: () -> Unit) {
    val money = LocalMoneyColors.current
    val name = summary.person.name
    val statusColor = when (summary.balance) {
        is Balance.YouPay -> money.goldText
        is Balance.PaysYou -> money.received
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 56.dp)
                .clickable(onClickLabel = "Open", role = Role.Button, onClick = onClick)
                .padding(vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clearAndSetSemantics {}
                    .background(avatarColor, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = name.trim().take(1).uppercase(),
                    style = MaterialTheme.typography.titleSmall,
                    color = if (avatarColor.luminance() > 0.18f) Ink else Color.White
                )
            }
            Spacer(Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(text = name, style = MaterialTheme.typography.titleSmall)
                Text(
                    text = PeopleMath.statusLine(name, summary.balance, summary.person.qrPath != null),
                    style = MaterialTheme.typography.bodyMedium,
                    color = statusColor
                )
            }
        }
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
    }
}
