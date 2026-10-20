package com.expensetracker.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.exclude
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.isImeVisible
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.material.icons.filled.EditNote
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.data.CategoryEntity
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.data.TransactionType
import com.expensetracker.app.ui.components.AmountInput
import com.expensetracker.app.ui.components.PastDatePickerDialog
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
    onClose: () -> Unit,
    onSplit: (expenseId: String) -> Unit,
    viewModel: PaymentViewModel = hiltViewModel()
) {
    LaunchedEffect(viewModel) {
        viewModel.events.collect {
            when (it) {
                PaymentEvent.Close -> onClose()
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
        onClose = onClose,
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
    val padVisible = !shopFocused && !noteFocused
    val valid = AmountInput.toAmount(form.amountText) != null
    val saving by viewModel.saving.collectAsStateWithLifecycle()
    // Back or Done hides the keyboard but leaves focus in Shop/Note; drop it so the number pad returns.
    val imeVisible = WindowInsets.isImeVisible
    var wasImeVisible by remember { mutableStateOf(false) }
    LaunchedEffect(imeVisible) {
        if (wasImeVisible && !imeVisible) focusManager.clearFocus()
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
        TopRow(type = form.type, onClose = { if (!saving) onClose() }, onType = viewModel::setType)
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            AmountDisplay(
                text = form.amountText,
                type = form.type,
                caret = padVisible,
                onClick = { focusManager.clearFocus() }
            )
            val categoryName = categories.find { it.id == form.categoryId }?.name
                ?: DefaultCategories.UNCATEGORIZED_NAME
            PaymentCard(label = "Category", value = categoryName, onClick = { pickingCategory = true }, icon = {
                Box(
                    modifier = Modifier
                        .size(14.dp)
                        .clip(CircleShape)
                        .background(categoryColor(form.categoryId))
                )
            }, trailing = {
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            })
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                PaymentCard(
                    label = "Date",
                    value = dateLabel(form.postTime),
                    onClick = { pickingDate = true },
                    icon = { CardIcon(Icons.Default.CalendarMonth) },
                    modifier = Modifier.weight(1f)
                )
                TextCard(
                    label = "Shop",
                    icon = Icons.Default.Storefront,
                    value = form.merchant,
                    onValueChange = viewModel::setMerchant,
                    onFocus = { shopFocused = it },
                    singleLine = true,
                    modifier = Modifier.weight(1f)
                )
            }
            TextCard(
                label = "Note",
                icon = Icons.Default.EditNote,
                value = form.notes,
                onValueChange = viewModel::setNotes,
                onFocus = { noteFocused = it },
                singleLine = false
            )
            if (form.categoryId != null && form.categoryId != loadedCategoryId && form.merchant.isNotBlank()) {
                Text(
                    text = "A new category also applies to past payments from this shop",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 4.dp)
                )
            }
        }
        if (padVisible) {
            NumberPad(onKey = viewModel::press, onBackspace = viewModel::backspace)
        }
        if (isEditing && form.type == TransactionType.WITHDRAW) {
            TextButton(
                onClick = viewModel::saveAndSplit,
                enabled = valid,
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 48.dp)
            ) { Text("Split this bill") }
        }
        Button(
            onClick = viewModel::save,
            enabled = valid,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 4.dp, bottom = 12.dp)
                .height(56.dp),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(containerColor = LocalMoneyColors.current.gold, contentColor = Ink)
        ) {
            Text(
                text = when {
                    isEditing -> "Save"
                    form.type == TransactionType.RECEIVE -> "✓ Add income"
                    else -> "✓ Add expense"
                },
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
private fun TopRow(type: TransactionType, onClose: () -> Unit, onType: (TransactionType) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(
            onClick = onClose,
            colors = IconButtonDefaults.iconButtonColors(
                containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
            )
        ) {
            Icon(Icons.Default.Close, contentDescription = "Close")
        }
        Spacer(Modifier.width(12.dp))
        Row(
            modifier = Modifier
                .weight(1f)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.surfaceContainerHigh)
                .padding(4.dp)
        ) {
            TypeSegment("Expense", type == TransactionType.WITHDRAW, MaterialTheme.colorScheme.inverseSurface) {
                onType(TransactionType.WITHDRAW)
            }
            TypeSegment("Income", type == TransactionType.RECEIVE, LocalMoneyColors.current.received) {
                onType(TransactionType.RECEIVE)
            }
        }
    }
}

@Composable
private fun RowScope.TypeSegment(label: String, selected: Boolean, selectedColor: Color, onClick: () -> Unit) {
    val lightTheme = MaterialTheme.colorScheme.background.luminance() > 0.5f
    Box(
        modifier = Modifier
            .weight(1f)
            .heightIn(min = 48.dp)
            .clip(CircleShape)
            .background(if (selected) selectedColor else Color.Transparent)
            .selectable(selected = selected, role = Role.Tab, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = when {
                !selected -> MaterialTheme.colorScheme.onSurfaceVariant
                // Ink on the light-theme green is only ~3.6:1.
                lightTheme && selectedColor == LocalMoneyColors.current.received -> Color.White
                selectedColor.luminance() > 0.18f -> Ink
                else -> Color.White
            }
        )
    }
}

@Composable
private fun AmountDisplay(text: String, type: TransactionType, caret: Boolean, onClick: () -> Unit) {
    val money = LocalMoneyColors.current
    val income = type == TransactionType.RECEIVE
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    val digitColor = if (income) money.received else MaterialTheme.colorScheme.onSurface
    val size = if (text.length > 9) 44.sp else 56.sp
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 120.dp)
            .clickable(onClickLabel = "Type the amount", onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = if (text.isEmpty()) "Amount empty" else "Amount RM $text"
                role = Role.Button
            },
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = buildAnnotatedString {
                withStyle(SpanStyle(fontSize = size * 0.45f, color = if (income) money.received else muted)) {
                    append(if (income) "+RM " else "RM ")
                }
                if (text.isEmpty()) {
                    withStyle(SpanStyle(color = muted)) { append("0") }
                } else {
                    append(text)
                }
            },
            fontSize = size,
            fontWeight = FontWeight.Bold,
            color = digitColor,
            maxLines = 1,
            style = MaterialTheme.typography.displayLarge.copy(fontFeatureSettings = "tnum")
        )
        if (caret) {
            Box(
                modifier = Modifier
                    .padding(start = 4.dp)
                    .width(3.dp)
                    .height(48.dp)
                    .background(money.gold)
            )
        }
    }
}

private val CardShape = RoundedCornerShape(20.dp)

@Composable
private fun CardIcon(icon: ImageVector) {
    Icon(icon, contentDescription = null, modifier = Modifier.size(18.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
}

/** Round icon spot, label on top, value below. */
@Composable
private fun CardFrame(
    label: String,
    icon: @Composable () -> Unit,
    modifier: Modifier = Modifier,
    trailing: @Composable () -> Unit = {},
    value: @Composable () -> Unit
) {
    Row(
        modifier = modifier
            .clip(CardShape)
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
            .heightIn(min = 64.dp)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.surfaceContainerHighest),
            contentAlignment = Alignment.Center
        ) { icon() }
        Spacer(Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            value()
        }
        trailing()
    }
}

@Composable
private fun PaymentCard(
    label: String,
    value: String,
    onClick: () -> Unit,
    icon: @Composable () -> Unit,
    modifier: Modifier = Modifier,
    trailing: @Composable () -> Unit = {}
) {
    CardFrame(
        label = label,
        icon = icon,
        trailing = trailing,
        modifier = modifier
            .fillMaxWidth()
            .clip(CardShape)
            .clickable(onClickLabel = "Change ${label.lowercase()}", onClick = onClick)
            .semantics(mergeDescendants = true) {}
    ) {
        Text(
            text = value,
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun TextCard(
    label: String,
    icon: ImageVector,
    value: String,
    onValueChange: (String) -> Unit,
    onFocus: (Boolean) -> Unit,
    singleLine: Boolean,
    modifier: Modifier = Modifier
) {
    val focus = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current
    val textStyle = MaterialTheme.typography.bodyLarge.copy(
        color = MaterialTheme.colorScheme.onSurface,
        fontWeight = FontWeight.SemiBold
    )
    CardFrame(
        label = label,
        icon = { CardIcon(icon) },
        modifier = modifier
            .fillMaxWidth()
            .clip(CardShape)
            .clickable { focus.requestFocus() }
    ) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            singleLine = singleLine,
            maxLines = if (singleLine) 1 else 4,
            textStyle = textStyle,
            cursorBrush = SolidColor(LocalMoneyColors.current.gold),
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
                    if (value.isEmpty()) {
                        Text("Optional", style = textStyle.copy(fontWeight = FontWeight.Normal), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    inner()
                }
            }
        )
    }
}

private val padRows = listOf("123", "456", "789", ".0<")

@Composable
private fun NumberPad(onKey: (Char) -> Unit, onBackspace: () -> Unit) {
    Column(
        modifier = Modifier.padding(vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        padRows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { key ->
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(56.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .background(MaterialTheme.colorScheme.surfaceContainer)
                            .clickable(role = Role.Button) { if (key == '<') onBackspace() else onKey(key) }
                            .semantics {
                                if (key == '.') contentDescription = "Decimal point"
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        if (key == '<') {
                            Icon(Icons.AutoMirrored.Filled.Backspace, contentDescription = "Delete digit")
                        } else {
                            Text(key.toString(), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CategorySheet(
    categories: List<CategoryEntity>,
    selectedId: String?,
    onPick: (String?) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val options = listOf<Pair<String?, String>>(null to DefaultCategories.UNCATEGORIZED_NAME) +
        categories.map { it.id to it.name }
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Text(
            text = "Category",
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp)
        )
        LazyColumn(modifier = Modifier.navigationBarsPadding()) {
            items(options, key = { it.first ?: "" }) { (id, name) ->
                val selected = id == selectedId
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 56.dp)
                        .selectable(selected = selected, role = Role.RadioButton) {
                            onPick(id)
                            scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() }
                        }
                        .padding(horizontal = 24.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(14.dp)
                            .clip(CircleShape)
                            .background(categoryColor(id))
                    )
                    Spacer(Modifier.width(16.dp))
                    Text(name, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                    if (selected) {
                        Icon(Icons.Default.Check, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    }
                }
            }
        }
    }
}

/** "Today", "Yesterday", or "Mon, 12 Oct". */
private fun dateLabel(time: Long): String {
    val day = Calendar.getInstance().apply { timeInMillis = time }
    val today = Calendar.getInstance()
    fun same(a: Calendar, b: Calendar) =
        a.get(Calendar.YEAR) == b.get(Calendar.YEAR) && a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)
    if (same(day, today)) return "Today"
    today.add(Calendar.DAY_OF_YEAR, -1)
    if (same(day, today)) return "Yesterday"
    return SimpleDateFormat("EEE, d MMM", Locale.getDefault()).format(Date(time))
}
