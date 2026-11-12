package com.expensetracker.app.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.expensetracker.app.data.CategoryEntity
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.data.PendingPaymentEntity
import com.expensetracker.app.data.TransactionType
import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.parser.CaptureFormat
import com.expensetracker.app.ui.components.AmountInput
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
@OptIn(ExperimentalLayoutApi::class)
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
    val editModifier = if (onEdit != null) Modifier.clickable(onClickLabel = "Change payment", onClick = onEdit) else Modifier

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(22.dp))
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp)
        ) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Tag("${card.appName} · ${android.text.format.DateFormat.getTimeFormat(LocalContext.current).format(Date(payment.notificationPostTime))}")
                if (payment.format == CaptureFormat.UNKNOWN) Tag("Unknown format", money.review)
            }
            Column(
                modifier = Modifier
                    .padding(top = 10.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .then(editModifier)
                    .semantics(mergeDescendants = true) {}
            ) {
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        text = AmountFormatter.currencySymbol(payment.currency),
                        style = MaterialTheme.typography.titleLarge,
                        color = muted,
                        modifier = Modifier.padding(end = 4.dp, bottom = 6.dp)
                    )
                    Text(
                        text = AmountFormatter.formatGrouped(payment.amount),
                        style = MaterialTheme.typography.displaySmall.copy(fontFeatureSettings = "tnum"),
                        fontWeight = FontWeight.ExtraBold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
                Text(
                    text = when {
                        payment.directionUnclear -> "Spent or Received?"
                        received -> "Received"
                        else -> "Spent"
                    },
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = when {
                        payment.directionUnclear -> money.review
                        received -> money.received
                        else -> money.red
                    }
                )
            }
            if (payment.directionUnclear) {
                // Outside the clickable amount block, so each choice is its own button for TalkBack.
                Row(
                    modifier = Modifier.padding(top = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedButton(
                        onClick = { onChooseDirection?.invoke(TransactionType.WITHDRAW) },
                        enabled = onChooseDirection != null
                    ) { Text("Spent", color = money.red, fontWeight = FontWeight.Bold) }
                    OutlinedButton(
                        onClick = { onChooseDirection?.invoke(TransactionType.RECEIVE) },
                        enabled = onChooseDirection != null
                    ) { Text("Received", color = money.received, fontWeight = FontWeight.Bold) }
                }
            }
            Spacer(Modifier.height(8.dp))
            CardField("Merchant", payment.merchant ?: "Not set", editModifier)
            CardField("Category", card.categoryName, editModifier)
            CardField("Date", dateLabel(payment.notificationPostTime), editModifier)
            val rawBar = MaterialTheme.colorScheme.outline
            Text(
                text = "“${payment.rawNotificationText}”",
                style = MaterialTheme.typography.bodyMedium,
                color = muted,
                modifier = Modifier
                    .padding(top = 14.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(MaterialTheme.colorScheme.surfaceContainer)
                    .drawBehind { drawRect(rawBar, size = Size(3.dp.toPx(), size.height)) }
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
private fun CardField(label: String, value: String, editModifier: Modifier) {
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 48.dp)
                .then(editModifier)
                .semantics(mergeDescendants = true) {}
                .padding(vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(label, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.width(12.dp))
            Text(
                text = value,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.End,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f)
            )
            Icon(
                Icons.Default.Edit,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier
                    .padding(start = 6.dp)
                    .size(16.dp)
            )
        }
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
    }
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
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .navigationBarsPadding()
                .padding(horizontal = 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text("Change payment", style = MaterialTheme.typography.titleMedium)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.surfaceContainerHigh)
                    .padding(4.dp)
            ) {
                TypeSegment("Expense", type == TransactionType.WITHDRAW, MaterialTheme.colorScheme.inverseSurface) {
                    type = TransactionType.WITHDRAW
                    typePicked = true
                }
                TypeSegment("Income", type == TransactionType.RECEIVE, LocalMoneyColors.current.received) {
                    type = TransactionType.RECEIVE
                    typePicked = true
                }
            }
            OutlinedTextField(
                value = amountText,
                onValueChange = { amountText = it },
                label = { Text("Amount") },
                prefix = { Text("${AmountFormatter.currencySymbol(payment.currency)} ") },
                isError = amount == null,
                supportingText = if (amount == null) {
                    { Text("Type an amount above 0") }
                } else {
                    null
                },
                singleLine = true,
                textStyle = MaterialTheme.typography.bodyLarge,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                modifier = Modifier.fillMaxWidth()
            )
            OutlinedTextField(
                value = merchant,
                onValueChange = { merchant = it },
                label = { Text("Shop") },
                singleLine = true,
                textStyle = MaterialTheme.typography.bodyLarge,
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
                modifier = Modifier.fillMaxWidth()
            )
            SheetRow(
                label = "Category",
                value = categories.find { it.id == categoryId }?.name ?: DefaultCategories.UNCATEGORIZED_NAME,
                dotColor = categoryColor(categoryId),
                onClick = { pickingCategory = true }
            )
            SheetRow(label = "Date", value = dateLabel(time), dotColor = null, onClick = { pickingDate = true })
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
                shape = RoundedCornerShape(18.dp),
                colors = ButtonDefaults.buttonColors(containerColor = LocalMoneyColors.current.gold, contentColor = Ink)
            ) {
                Text("Save changes", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            }
        }
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

@Composable
private fun SheetRow(label: String, value: String, dotColor: Color?, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
            .clickable(onClickLabel = "Change ${label.lowercase()}", onClick = onClick)
            .semantics(mergeDescendants = true) {}
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.weight(1f))
        if (dotColor != null) {
            Box(
                modifier = Modifier
                    .padding(end = 8.dp)
                    .size(14.dp)
                    .clip(CircleShape)
                    .background(dotColor)
            )
        }
        Text(value, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
    }
}
