package com.expensetracker.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.data.Balance
import com.expensetracker.app.data.PeopleMath
import com.expensetracker.app.data.PersonSummary
import com.expensetracker.app.ui.components.KobanRow
import com.expensetracker.app.ui.components.LargeTopBar
import com.expensetracker.app.ui.components.ListGroup
import com.expensetracker.app.ui.components.SectionHeading
import com.expensetracker.app.ui.components.TonalButton
import com.expensetracker.app.ui.theme.LocalMoneyColors
import com.expensetracker.app.ui.viewmodel.PeopleViewModel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

private fun groupTitle(group: PeopleMath.Group) = when (group) {
    PeopleMath.Group.YOU_OWE -> "You owe"
    PeopleMath.Group.OWES_YOU -> "Owes you"
    PeopleMath.Group.OTHERS -> "Everyone else"
}

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
        contentWindowInsets = WindowInsets(0),
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = {
                    newName = ""
                    addError = null
                    adding = true
                },
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary,
                icon = { Icon(Icons.Default.PersonAdd, contentDescription = null) },
                text = { Text("Add person", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold) }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 96.dp)
        ) {
            item {
                LargeTopBar(
                    "People",
                    subtitle = "Payment QRs, and what you owe each other"
                )
                TextField(
                    value = query,
                    onValueChange = viewModel::setQuery,
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text("Search people") },
                    leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                    singleLine = true,
                    shape = CircleShape,
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                        unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent
                    )
                )
                TonalButton(
                    text = "Split a bill",
                    onClick = onSplitBill,
                    modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                    icon = Icons.Default.Receipt
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
                    Column(Modifier.padding(top = 20.dp)) {
                        SectionHeading(groupTitle(group))
                        ListGroup {
                            people.forEach { summary ->
                                item {
                                    PersonRow(
                                        summary = summary,
                                        avatarColor = avatarColors[Math.floorMod(summary.person.id.hashCode(), avatarColors.size)],
                                        onClick = { onOpenPerson(summary.person.id) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            if (bills.isNotEmpty()) {
                item {
                    Column(Modifier.padding(top = 24.dp)) {
                        SectionHeading("Past splits")
                        ListGroup {
                            bills.forEach { bill ->
                                item {
                                    KobanRow(
                                        title = bill.merchant ?: "Split bill",
                                        trailing = {
                                            Text(
                                                text = personDate(bill.billTime),
                                                style = MaterialTheme.typography.bodyMedium,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant
                                            )
                                        },
                                        showChevron = true,
                                        onClick = { onOpenSplit(bill.id) },
                                        onClickLabel = "Open"
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (adding) {
        AlertDialog(
            shape = RoundedCornerShape(24.dp),
            containerColor = MaterialTheme.colorScheme.surfaceContainer,
            onDismissRequest = { adding = false },
            title = { Text("Add person") },
            text = {
                DialogTextField(
                    value = newName,
                    onValueChange = {
                        newName = it
                        addError = null
                    },
                    label = "Name",
                    isError = addError != null,
                    supportingText = addError,
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
    KobanRow(
        title = name,
        subtitle = PeopleMath.statusLine(name, summary.balance, summary.person.qrPath != null),
        subtitleColor = statusColor,
        leading = {
            // A tint of the color of the person under normal text keeps the initial readable in light and dark.
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clearAndSetSemantics {}
                    .background(avatarColor.copy(alpha = 0.3f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = name.trim().take(1).uppercase(),
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }
        },
        showChevron = true,
        onClick = onClick,
        onClickLabel = "Open"
    )
}
