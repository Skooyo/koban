package com.expensetracker.app.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.exclude
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.isImeVisible
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Backspace
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.EditNote
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.data.CategoryEntity
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.data.TransactionType
import com.expensetracker.app.ui.components.AmountInput
import com.expensetracker.app.ui.components.CategoryDot
import com.expensetracker.app.ui.components.DirectionSegments
import com.expensetracker.app.ui.components.DiscardChangesDialog
import com.expensetracker.app.ui.components.KobanRow
import com.expensetracker.app.ui.components.ListGroup
import com.expensetracker.app.ui.components.MoneyText
import com.expensetracker.app.ui.components.PastDatePickerDialog
import com.expensetracker.app.ui.components.TonalButton
import com.expensetracker.app.ui.theme.LocalMoneyColors
import com.expensetracker.app.ui.theme.categoryColor
import com.expensetracker.app.ui.viewmodel.PaymentEvent
import com.expensetracker.app.ui.viewmodel.PaymentForm
import com.expensetracker.app.ui.viewmodel.PaymentViewModel
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

@Composable
fun PaymentScreen(
    onClose: (message: String?) -> Unit,
    onSplit: (expenseId: String) -> Unit,
    viewModel: PaymentViewModel = hiltViewModel()
) {
    LaunchedEffect(viewModel) {
        viewModel.events.collect {
            when (it) {
                is PaymentEvent.Close -> onClose(it.message)
                is PaymentEvent.OpenSplit -> onSplit(it.expenseId)
            }
        }
    }
    val form by viewModel.form.collectAsStateWithLifecycle()
    val categories by viewModel.categories.collectAsStateWithLifecycle()
    val loaded = form ?: return
    PaymentContent(
        form = loaded,
        isEditing = viewModel.isEditing,
        loadedCategoryId = viewModel.loadedCategoryId,
        categories = categories,
        onClose = { onClose(null) },
        viewModel = viewModel
    )
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun PaymentContent(
    form: PaymentForm,
    isEditing: Boolean,
    loadedCategoryId: String?,
    categories: List<CategoryEntity>,
    onClose: () -> Unit,
    viewModel: PaymentViewModel
) {
    val focusManager = LocalFocusManager.current
    var shopFocused by remember { mutableStateOf(false) }
    var noteFocused by remember { mutableStateOf(false) }
    var pickingCategory by remember { mutableStateOf(false) }
    var pickingDate by remember { mutableStateOf(false) }
    var confirmingDelete by remember { mutableStateOf(false) }
    // Add opens with the pad; edit opens without it until the amount is tapped.
    var padRequested by remember { mutableStateOf(!isEditing) }
    val padVisible = padRequested && !shopFocused && !noteFocused
    val valid = AmountInput.toAmount(form.amountText) != null
    val saving by viewModel.saving.collectAsStateWithLifecycle()
    val inGroups by viewModel.inGroups.collectAsStateWithLifecycle()
    // `form` is a parameter, so each edit runs this check again.
    val hasChanges = viewModel.hasChanges
    var confirmingDiscard by remember { mutableStateOf(false) }
    // A save sets `saving` first, so a save never asks.
    BackHandler(enabled = hasChanges && !saving) { confirmingDiscard = true }
    // Back or Done hides the keyboard but leaves focus in Shop/Note; drop it so the number pad returns.
    val imeVisible = WindowInsets.isImeVisible
    var wasImeVisible by remember { mutableStateOf(false) }
    LaunchedEffect(imeVisible) {
        if (wasImeVisible && !imeVisible) {
            focusManager.clearFocus()
            if (!isEditing) padRequested = true
        }
        wasImeVisible = imeVisible
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            // The app Scaffold already pads for the navigation bar; add only the keyboard above it.
            .windowInsetsPadding(WindowInsets.ime.exclude(WindowInsets.navigationBars))
            .padding(horizontal = 16.dp)
    ) {
        TopRow(
            type = form.type,
            isEditing = isEditing,
            onClose = {
                if (!saving) {
                    if (hasChanges) confirmingDiscard = true else onClose()
                }
            },
            onType = viewModel::setType,
            onDelete = { confirmingDelete = true },
            deleteEnabled = !saving
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            val income = form.type == TransactionType.RECEIVE
            val money = LocalMoneyColors.current
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .clickable(onClickLabel = "Type the amount") {
                        focusManager.clearFocus()
                        padRequested = true
                    }
                    .padding(vertical = 16.dp)
                    .semantics(mergeDescendants = true) {
                        contentDescription = if (form.amountText.isEmpty()) "Amount empty" else "Amount RM ${form.amountText}"
                    },
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                val amount = "RM ${form.amountText.ifEmpty { "0" }}"
                MoneyText(
                    text = if (income) "+ $amount" else amount,
                    style = MaterialTheme.typography.displayLarge,
                    color = when {
                        income -> money.received
                        form.amountText.isEmpty() -> MaterialTheme.colorScheme.onSurfaceVariant
                        else -> MaterialTheme.colorScheme.onSurface
                    }
                )
                Text(
                    text = if (isEditing) "${if (income) "Received" else "Spent"} · ${dateTimeLabel(form.postTime)}" else "Tap a number to change it",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            val categoryName = categories.find { it.id == form.categoryId }?.name
                ?: DefaultCategories.UNCATEGORIZED_NAME
            ListGroup {
                item {
                    KobanRow(
                        categoryName,
                        subtitle = "Category",
                        leading = { CategoryDot(categoryColor(form.categoryId), 12.dp) },
                        showChevron = true,
                        onClick = { pickingCategory = true },
                        onClickLabel = "Change category"
                    )
                }
                item {
                    KobanRow(
                        dateLabel(form.postTime),
                        subtitle = "Date",
                        leading = { Icon(Icons.Default.CalendarMonth, contentDescription = null) },
                        showChevron = true,
                        onClick = { pickingDate = true },
                        onClickLabel = "Change date"
                    )
                }
                item {
                    TextRow(
                        label = "Shop",
                        placeholder = "Not set",
                        icon = Icons.Default.Storefront,
                        value = form.merchant,
                        onValueChange = viewModel::setMerchant,
                        onFocus = {
                            shopFocused = it
                            if (it) padRequested = false
                        },
                        singleLine = true
                    )
                }
                item {
                    TextRow(
                        label = "Note",
                        placeholder = "Optional",
                        icon = Icons.Default.EditNote,
                        value = form.notes,
                        onValueChange = viewModel::setNotes,
                        onFocus = {
                            noteFocused = it
                            if (it) padRequested = false
                        },
                        singleLine = false
                    )
                }
            }
            if (inGroups && form.type == TransactionType.WITHDRAW) {
                ListGroup {
                    item {
                        KobanRow(
                            "Count in group totals",
                            subtitle = if (form.privateToGroups) "Group members do not see this payment" else "Group members see this in your totals",
                            trailing = { Switch(checked = !form.privateToGroups, onCheckedChange = null) },
                            onClick = { viewModel.setPrivateToGroups(!form.privateToGroups) }
                        )
                    }
                }
            }
            if (form.categoryId != null && form.categoryId != loadedCategoryId && form.merchant.isNotBlank()) {
                Text(
                    text = "A new category also applies to past payments from this shop",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 4.dp)
                )
            }
            if (isEditing && form.type == TransactionType.WITHDRAW) {
                TonalButton(
                    text = "Split this bill",
                    onClick = viewModel::saveAndSplit,
                    modifier = Modifier.fillMaxWidth().height(56.dp),
                    icon = Icons.Default.Groups,
                    enabled = valid
                )
            }
        }
        if (padVisible) {
            NumberPad(onKey = viewModel::press, onBackspace = viewModel::backspace)
        }
        Button(
            onClick = viewModel::save,
            enabled = valid,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 4.dp, bottom = 12.dp)
                .height(56.dp)
        ) {
            Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text(
                text = if (isEditing) "Save changes" else "Save payment",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
        }
    }

    if (pickingCategory) {
        CategorySheet(
            categories = categories,
            selectedId = form.categoryId,
            onPick = viewModel::setCategory,
            onDismiss = { pickingCategory = false }
        )
    }
    if (confirmingDiscard) {
        DiscardChangesDialog(
            onDiscard = {
                confirmingDiscard = false
                onClose()
            },
            onKeepEditing = { confirmingDiscard = false }
        )
    }
    if (confirmingDelete) {
        AlertDialog(
            shape = RoundedCornerShape(24.dp),
            containerColor = MaterialTheme.colorScheme.surfaceContainer,
            onDismissRequest = { confirmingDelete = false },
            title = { Text("Delete this payment?") },
            text = { Text("It will no longer count in your totals.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        confirmingDelete = false
                        viewModel.delete()
                    },
                    colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)
                ) { Text("Delete") }
            },
            dismissButton = {
                TextButton(onClick = { confirmingDelete = false }) { Text("Cancel") }
            }
        )
    }
    if (pickingDate) {
        PastDatePickerDialog(
            time = form.postTime,
            onDismiss = { pickingDate = false },
            onPicked = {
                viewModel.setDate(it)
                pickingDate = false
            }
        )
    }
}

@Composable
private fun TopRow(
    type: TransactionType,
    isEditing: Boolean,
    onClose: () -> Unit,
    onType: (TransactionType) -> Unit,
    onDelete: () -> Unit,
    deleteEnabled: Boolean
) {
    Column(Modifier.fillMaxWidth().padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            IconButton(onClick = onClose, modifier = Modifier.size(48.dp)) {
                Icon(Icons.Default.Close, contentDescription = "Close")
            }
            if (isEditing) {
                Text(
                    "Payment",
                    modifier = Modifier.weight(1f).semantics { heading() },
                    style = MaterialTheme.typography.titleLarge
                )
                IconButton(onClick = onDelete, enabled = deleteEnabled, modifier = Modifier.size(48.dp)) {
                    Icon(Icons.Default.Delete, contentDescription = "Delete payment", tint = MaterialTheme.colorScheme.error)
                }
            } else {
                DirectionSegments(selected = type, onPick = onType, modifier = Modifier.weight(1f))
            }
        }
        // Edit keeps the Spent / Received switch that the screen has today, under the title row.
        if (isEditing) DirectionSegments(selected = type, onPick = onType)
    }
}

/** A [KobanRow]-shaped row whose title is typed in place. Tap anywhere on the row to type. */
@Composable
private fun TextRow(
    label: String,
    placeholder: String,
    icon: ImageVector,
    value: String,
    onValueChange: (String) -> Unit,
    onFocus: (Boolean) -> Unit,
    singleLine: Boolean
) {
    val focus = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    val textStyle = MaterialTheme.typography.titleMedium.copy(color = MaterialTheme.colorScheme.onSurface)
    Row(
        Modifier
            .fillMaxWidth()
            .clickable { focus.requestFocus() }
            .defaultMinSize(minHeight = 56.dp)
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(Modifier.size(40.dp), contentAlignment = Alignment.Center) {
            Icon(icon, contentDescription = null, tint = muted)
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                singleLine = singleLine,
                maxLines = if (singleLine) 1 else 4,
                textStyle = textStyle,
                cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Sentences,
                    imeAction = if (singleLine) ImeAction.Done else ImeAction.Default
                ),
                keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus() }),
                modifier = Modifier
                    .fillMaxWidth()
                    .focusRequester(focus)
                    .onFocusChanged { onFocus(it.isFocused) }
                    .semantics { contentDescription = label },
                decorationBox = { inner ->
                    Box {
                        if (value.isEmpty()) Text(placeholder, style = textStyle, color = muted)
                        inner()
                    }
                }
            )
            Text(label, style = MaterialTheme.typography.bodyMedium, color = muted)
        }
        Icon(
            Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = muted,
            modifier = Modifier.padding(start = 8.dp).size(24.dp)
        )
    }
}

private val padRows = listOf("123", "456", "789", ".0<")

@Composable
private fun NumberPad(onKey: (Char) -> Unit, onBackspace: () -> Unit) {
    Column(
        modifier = Modifier.padding(vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        padRows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { key ->
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(52.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
                            .clickable(role = Role.Button) { if (key == '<') onBackspace() else onKey(key) }
                            .semantics {
                                if (key == '.') contentDescription = "Decimal point"
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        if (key == '<') {
                            Icon(Icons.AutoMirrored.Filled.Backspace, contentDescription = "Delete digit")
                        } else {
                            Text(key.toString(), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun CategorySheet(
    categories: List<CategoryEntity>,
    selectedId: String?,
    onPick: (String?) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val options = listOf<Pair<String?, String>>(null to DefaultCategories.UNCATEGORIZED_NAME) +
        categories.map { it.id to it.name }
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp)
    ) {
        Text(
            text = "Category",
            style = MaterialTheme.typography.titleLarge,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp).semantics { heading() }
        )
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .navigationBarsPadding()
                .padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            ListGroup {
                options.forEach { (id, name) ->
                    val selected = id == selectedId
                    item {
                        KobanRow(
                            name,
                            modifier = Modifier.semantics { this.selected = selected },
                            leading = { CategoryDot(categoryColor(id), 12.dp) },
                            trailing = if (selected) {
                                { Icon(Icons.Default.Check, contentDescription = "Selected", tint = MaterialTheme.colorScheme.primary) }
                            } else null,
                            onClick = {
                                onPick(id)
                                scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() }
                            }
                        )
                    }
                }
            }
        }
    }
}

/** "Wed, 11 Nov, 20:15". */
private fun dateTimeLabel(time: Long): String =
    SimpleDateFormat("EEE, d MMM, HH:mm", Locale.getDefault()).format(Date(time))

/** "Today", "Yesterday", or "Mon, 12 Oct". */
internal fun dateLabel(time: Long): String {
    val day = Calendar.getInstance().apply { timeInMillis = time }
    val today = Calendar.getInstance()
    fun same(a: Calendar, b: Calendar) =
        a.get(Calendar.YEAR) == b.get(Calendar.YEAR) && a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)
    if (same(day, today)) return "Today"
    today.add(Calendar.DAY_OF_YEAR, -1)
    if (same(day, today)) return "Yesterday"
    return SimpleDateFormat("EEE, d MMM", Locale.getDefault()).format(Date(time))
}
