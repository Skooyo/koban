package com.expensetracker.app.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.SheetValue
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.expensetracker.app.data.CategoryEntity
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.data.PendingPaymentEntity
import com.expensetracker.app.data.TransactionType
import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.parser.CaptureFormat
import com.expensetracker.app.ui.components.AmountInput
import com.expensetracker.app.ui.components.CategoryDot
import com.expensetracker.app.ui.components.DirectionSegments
import com.expensetracker.app.ui.components.DiscardChangesDialog
import com.expensetracker.app.ui.components.KobanRow
import com.expensetracker.app.ui.components.ListGroup
import com.expensetracker.app.ui.components.MoneyText
import com.expensetracker.app.ui.components.PastDatePickerDialog
import com.expensetracker.app.ui.theme.LocalMoneyColors
import com.expensetracker.app.ui.theme.categoryColor
import com.expensetracker.app.ui.viewmodel.CheckCard
import java.util.Date

/**
 * One waiting payment. [stamp] gives the drag as -1 (full "NOT A PAYMENT") to 1 (full "SAVE");
 * it is read in the draw phase, so a drag does not recompose the card. [onEdit] and [onChooseDirection]
 * are null on the cards under the top one.
 */
@Composable
internal fun CheckPaymentCard(
    card: CheckCard,
    stamp: () -> Float,
    onEdit: (() -> Unit)?,
    onChooseDirection: ((TransactionType) -> Unit)?,
    modifier: Modifier = Modifier
) {
    val payment = card.payment
    val money = LocalMoneyColors.current
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    val received = payment.transactionType == TransactionType.RECEIVE
    val timeText = android.text.format.DateFormat.getTimeFormat(LocalContext.current).format(Date(payment.notificationPostTime))
    val editModifier = if (onEdit != null) Modifier.clickable(onClickLabel = "Change payment", onClick = onEdit) else Modifier

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(24.dp))
            .background(MaterialTheme.colorScheme.surfaceContainer)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                SourceAvatar(card.appName)
                Text(
                    text = "${card.appName} · $timeText",
                    style = MaterialTheme.typography.bodyMedium,
                    color = muted,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false)
                )
                if (payment.format == CaptureFormat.UNKNOWN) Tag("Unknown format", money.review)
            }
            val amountText = "${AmountFormatter.currencySymbol(payment.currency)} ${AmountFormatter.formatGrouped(payment.amount)}"
            MoneyText(
                text = if (received) "+ $amountText" else amountText,
                style = MaterialTheme.typography.displayMedium,
                color = if (received) money.received else MaterialTheme.colorScheme.onSurface,
                modifier = Modifier
                    .padding(horizontal = 16.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .then(editModifier)
                    .semantics(mergeDescendants = true) {}
            )
            // Outside the clickable amount, so each choice is its own button for TalkBack.
            DirectionSegments(
                selected = if (payment.directionUnclear) null else payment.transactionType,
                onPick = onChooseDirection.takeIf { payment.directionUnclear },
                modifier = Modifier.padding(horizontal = 16.dp),
                onTapWhenFixed = onEdit
            )
            if (payment.directionUnclear) {
                Text(
                    text = "Spent or Received?",
                    style = MaterialTheme.typography.bodyMedium,
                    color = money.review,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }
            ListGroup {
                item { KobanRow(payment.merchant ?: "Not set", subtitle = "Shop", showChevron = true, onClick = onEdit) }
                item {
                    KobanRow(
                        card.categoryName,
                        subtitle = "Category",
                        leading = { CategoryDot(categoryColor(card.categoryId), 12.dp) },
                        showChevron = true,
                        onClick = onEdit
                    )
                }
                item {
                    KobanRow("${dateLabel(payment.notificationPostTime)}, $timeText", subtitle = "Date", showChevron = true, onClick = onEdit)
                }
            }
            Text(
                text = "“${payment.rawNotificationText}”",
                style = MaterialTheme.typography.bodyMedium,
                color = muted,
                modifier = Modifier
                    .padding(horizontal = 16.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(MaterialTheme.colorScheme.surfaceContainerHigh)
                    .padding(horizontal = 12.dp, vertical = 10.dp)
            )
        }
        // The stamps only echo the drag; TalkBack gets the custom actions instead.
        Stamp(
            text = "SAVE",
            color = money.gold,
            angle = 12f,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = 22.dp, end = 18.dp)
                .graphicsLayer { alpha = stamp().coerceIn(0f, 1f) }
        )
        Stamp(
            text = "NOT A PAYMENT",
            color = money.red,
            angle = -12f,
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(top = 22.dp, start = 18.dp)
                .graphicsLayer { alpha = (-stamp()).coerceIn(0f, 1f) }
        )
    }
}

/** The app's initials in a circle, for example "MB" for Maybank MAE. */
@Composable
private fun SourceAvatar(appName: String) {
    val words = appName.trim().split(' ').filter { it.isNotEmpty() }
    val initials = (if (words.size >= 2) "${words[0].first()}${words[1].first()}" else appName.trim().take(2)).uppercase()
    Box(
        modifier = Modifier
            .size(32.dp)
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
            .clearAndSetSemantics {},
        contentAlignment = Alignment.Center
    ) {
        Text(initials, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
    }
}

@Composable
private fun Tag(text: String, color: Color = MaterialTheme.colorScheme.onSurfaceVariant) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelLarge,
        color = color,
        modifier = Modifier
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.surfaceContainerHighest)
            .padding(horizontal = 10.dp, vertical = 4.dp)
    )
}

@Composable
private fun Stamp(text: String, color: Color, angle: Float, modifier: Modifier) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleLarge,
        fontWeight = FontWeight.Black,
        color = color,
        modifier = modifier
            .clearAndSetSemantics {}
            .rotate(angle)
            .border(BorderStroke(3.dp, color), RoundedCornerShape(10.dp))
            .padding(horizontal = 12.dp, vertical = 4.dp)
    )
}

/**
 * The add page's fields for one waiting card. A category is stored only when the owner picks one,
 * so an untouched card keeps following the merchant memory.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun EditPaymentSheet(
    card: CheckCard,
    categories: List<CategoryEntity>,
    onSave: (PendingPaymentEntity) -> Unit,
    onDismiss: () -> Unit
) {
    val payment = card.payment
    var amountText by rememberSaveable { mutableStateOf(AmountInput.fromAmount(payment.amount)) }
    var type by rememberSaveable { mutableStateOf(payment.transactionType) }
    var typePicked by rememberSaveable { mutableStateOf(false) }
    var merchant by rememberSaveable { mutableStateOf(payment.merchant.orEmpty()) }
    var categoryId by rememberSaveable { mutableStateOf(card.categoryId) }
    var categoryPicked by rememberSaveable { mutableStateOf(false) }
    var time by rememberSaveable { mutableStateOf(payment.notificationPostTime) }
    var pickingCategory by rememberSaveable { mutableStateOf(false) }
    var pickingDate by rememberSaveable { mutableStateOf(false) }
    val amount = AmountInput.toAmount(amountText)?.takeIf { it.signum() > 0 }
    val changed = amountText != AmountInput.fromAmount(payment.amount) ||
        type != payment.transactionType ||
        merchant != payment.merchant.orEmpty() ||
        categoryId != card.categoryId ||
        time != payment.notificationPostTime
    var confirmingDiscard by remember { mutableStateOf(false) }
    // The sheet state keeps its first lambda, so read `changed` through a State.
    val latestChanged = rememberUpdatedState(changed)
    val sheetState = rememberModalBottomSheetState(
        skipPartiallyExpanded = true,
        confirmValueChange = {
            // Swipe-down and Back both ask to hide; with changes, ask first and stay open.
            val block = it == SheetValue.Hidden && latestChanged.value
            if (block) confirmingDiscard = true
            !block
        }
    )

    ModalBottomSheet(
        onDismissRequest = { if (changed) confirmingDiscard = true else onDismiss() },
        sheetState = sheetState
    ) {
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .navigationBarsPadding()
                .padding(horizontal = 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text("Change payment", style = MaterialTheme.typography.titleLarge)
            DirectionSegments(
                selected = type.takeIf { !payment.directionUnclear || typePicked },
                onPick = {
                    type = it
                    typePicked = true
                }
            )
            val fieldColors = TextFieldDefaults.colors(
                focusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                errorContainerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent
            )
            TextField(
                value = amountText,
                onValueChange = { amountText = it },
                label = { Text("Amount (${AmountFormatter.currencySymbol(payment.currency)})") },
                isError = amount == null,
                supportingText = if (amount == null) {
                    { Text("Type an amount above 0") }
                } else {
                    null
                },
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                colors = fieldColors,
                textStyle = MaterialTheme.typography.bodyLarge,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                modifier = Modifier.fillMaxWidth()
            )
            TextField(
                value = merchant,
                onValueChange = { merchant = it },
                label = { Text("Shop") },
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                colors = fieldColors,
                textStyle = MaterialTheme.typography.bodyLarge,
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
                modifier = Modifier.fillMaxWidth()
            )
            ListGroup {
                item {
                    KobanRow(
                        categories.find { it.id == categoryId }?.name ?: DefaultCategories.UNCATEGORIZED_NAME,
                        subtitle = "Category",
                        leading = { CategoryDot(categoryColor(categoryId), 12.dp) },
                        showChevron = true,
                        onClick = { pickingCategory = true }
                    )
                }
                item { KobanRow(dateLabel(time), subtitle = "Date", showChevron = true, onClick = { pickingDate = true }) }
            }
            Button(
                onClick = {
                    val newAmount = amount ?: return@Button
                    val changed = payment.copy(
                        // compareTo: 23.4 and 23.40 are the same money.
                        amount = if (newAmount.compareTo(payment.amount) == 0) payment.amount else newAmount,
                        transactionType = type,
                        // A tap on Expense or Income here is the owner's choice too.
                        directionUnclear = payment.directionUnclear && !typePicked,
                        merchant = merchant.trim().ifEmpty { null },
                        categoryId = if (categoryPicked) categoryId else payment.categoryId,
                        notificationPostTime = time
                    )
                    if (changed != payment) onSave(changed)
                    onDismiss()
                },
                enabled = amount != null,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp)
                    .height(56.dp),
            ) {
                Text("Save changes", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            }
        }
    }

    if (confirmingDiscard) {
        DiscardChangesDialog(
            onDiscard = {
                confirmingDiscard = false
                onDismiss()
            },
            onKeepEditing = { confirmingDiscard = false }
        )
    }
    if (pickingCategory) {
        CategorySheet(
            categories = categories,
            selectedId = categoryId,
            onPick = {
                categoryId = it
                categoryPicked = true
            },
            onDismiss = { pickingCategory = false }
        )
    }
    if (pickingDate) {
        PastDatePickerDialog(
            time = time,
            onDismiss = { pickingDate = false },
            onPicked = {
                time = it
                pickingDate = false
            }
        )
    }
}
