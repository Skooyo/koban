package com.expensetracker.app.ui.screens

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.data.Balance
import com.expensetracker.app.data.OpenDebtView
import com.expensetracker.app.data.OwedItemEntity
import com.expensetracker.app.data.PeopleMath
import com.expensetracker.app.data.PersonDetail
import com.expensetracker.app.ui.components.MoneyAmount
import com.expensetracker.app.ui.theme.LocalMoneyColors
import com.expensetracker.app.ui.viewmodel.PersonViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private const val QR_MAX_PX = 1024

/** The QR at [path] decoded at most [QR_MAX_PX] on its long side, or null if it can't be read. */
private fun decodeQr(path: String): ImageBitmap? {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(path, bounds)
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
    var sample = 1
    while (maxOf(bounds.outWidth, bounds.outHeight) / sample > QR_MAX_PX) sample *= 2
    return BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })?.asImageBitmap()
}

/** A finished QR load; [bitmap] is null when the file can't be read. */
private class QrLoad(val bitmap: ImageBitmap?)

private enum class Dialog { RENAME, DELETE, SETTLE, ADD_ITEM }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PersonScreen(
    personId: String,
    onBack: () -> Unit,
    onOpenSplit: (String) -> Unit,
    viewModel: PersonViewModel = hiltViewModel()
) {
    val detail by viewModel.detail.collectAsStateWithLifecycle()
    val gone by viewModel.gone.collectAsStateWithLifecycle()
    val qrVersion by viewModel.qrVersion.collectAsStateWithLifecycle()
    val paying by viewModel.paying.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val context = LocalContext.current
    var menuOpen by remember { mutableStateOf(false) }
    var dialog by remember { mutableStateOf<Dialog?>(null) }
    var editing by remember { mutableStateOf<OwedItemEntity?>(null) }

    LaunchedEffect(gone) { if (gone) onBack() }
    LaunchedEffect(viewModel) { viewModel.messages.collect { snackbar.showSnackbar(it) } }

    val pickQr = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        uri?.let(viewModel::setQr)
    }
    val launchPicker = {
        pickQr.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
    }
    val storagePermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) viewModel.saveQrToGallery() else viewModel.showMessage("Allow storage access to save the QR.")
    }
    val saveQr = {
        // API 26-28 write to shared Pictures through the file path, which needs the permission.
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            storagePermission.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        } else {
            viewModel.saveQrToGallery()
        }
    }

    val qrPath = detail?.person?.qrPath
    val qr by produceState<QrLoad?>(null, qrPath, qrVersion) {
        if (qrPath == null) {
            value = null
            return@produceState
        }
        value = QrLoad(withContext(Dispatchers.IO) { runCatching { decodeQr(qrPath) }.getOrNull() })
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = { Text(detail?.person?.name.orEmpty(), style = MaterialTheme.typography.headlineSmall) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    if (detail != null) {
                        IconButton(onClick = { menuOpen = true }) {
                            Icon(Icons.Default.MoreVert, contentDescription = "More options")
                        }
                        DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                            DropdownMenuItem(text = { Text("Rename") }, onClick = {
                                menuOpen = false
                                dialog = Dialog.RENAME
                            })
                            if (qrPath != null) {
                                DropdownMenuItem(text = { Text("Replace QR") }, onClick = {
                                    menuOpen = false
                                    launchPicker()
                                })
                            }
                            DropdownMenuItem(text = { Text("Delete person") }, onClick = {
                                menuOpen = false
                                dialog = Dialog.DELETE
                            })
                        }
                    }
                }
            )
        }
    ) { padding ->
        val person = detail ?: return@Scaffold
        PersonContent(
            detail = person,
            qr = qr,
            modifier = Modifier.padding(padding),
            onQrClick = launchPicker,
            onSaveQr = saveQr,
            onSettleUp = { dialog = Dialog.SETTLE },
            onConfirmSettle = viewModel::confirmSettle,
            onDismissSettle = viewModel::dismissSettle,
            onOpenSplit = onOpenSplit,
            onMarkDebtPaid = viewModel::startPaying,
            onConfirmDebt = viewModel::confirmDebtSuggestion,
            onDismissDebt = viewModel::dismissDebtSuggestion,
            onEditItem = { editing = it },
            onMarkItemPaid = viewModel::markItemPaid,
            onAddItem = { dialog = Dialog.ADD_ITEM }
        )
    }

    val person = detail ?: return
    val name = person.person.name
    when (dialog) {
        Dialog.RENAME -> RenameDialog(name, onDismiss = { dialog = null }, onSave = viewModel::rename)
        Dialog.DELETE -> DeletePersonDialog(name, onDismiss = { dialog = null }, onConfirm = {
            dialog = null
            viewModel.delete()
        })
        Dialog.SETTLE -> SettleUpDialog(
            name = name,
            debtCount = person.owedToMe.size,
            itemCount = person.iOwe.size,
            onDismiss = { dialog = null },
            onConfirm = {
                dialog = null
                viewModel.settleUp()
            }
        )
        Dialog.ADD_ITEM -> OwedItemDialog(
            item = null,
            onDismiss = { dialog = null },
            onSave = viewModel::addItem,
            onDelete = null
        )
        null -> Unit
    }
    editing?.let { item ->
        OwedItemDialog(
            item = item,
            onDismiss = { editing = null },
            onSave = { description, amount, itemDate ->
                viewModel.updateItem(item.copy(description = description, amount = amount, itemDate = itemDate))
            },
            onDelete = {
                editing = null
                viewModel.deleteItem(item.id)
            }
        )
    }
    paying?.let { state ->
        DebtPaymentDialog(state, onPick = viewModel::markDebtPaid, onDismiss = viewModel::cancelPaying)
    }
}

@Composable
private fun PersonContent(
    detail: PersonDetail,
    qr: QrLoad?,
    modifier: Modifier,
    onQrClick: () -> Unit,
    onSaveQr: () -> Unit,
    onSettleUp: () -> Unit,
    onConfirmSettle: () -> Unit,
    onDismissSettle: () -> Unit,
    onOpenSplit: (String) -> Unit,
    onMarkDebtPaid: (OpenDebtView) -> Unit,
    onConfirmDebt: (String) -> Unit,
    onDismissDebt: (String) -> Unit,
    onEditItem: (OwedItemEntity) -> Unit,
    onMarkItemPaid: (String) -> Unit,
    onAddItem: () -> Unit
) {
    val money = LocalMoneyColors.current
    val name = detail.person.name
    val hasQr = detail.person.qrPath != null
    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 32.dp)
    ) {
        item {
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                KobanFrame(name = name, hasQr = hasQr, qr = qr, onClick = onQrClick)
            }
        }
        if (hasQr) {
            item {
                Button(
                    onClick = onSaveQr,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 20.dp)
                        .height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = money.gold, contentColor = Ink)
                ) { Text("Save QR to gallery") }
                Text(
                    text = "Then open your bank app and pick it from the gallery",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp)
                )
            }
        }
        item {
            val balance = detail.balance
            val headline = PeopleMath.headline(name, balance)
            val amountColor = when (balance) {
                is Balance.YouPay -> money.gold
                is Balance.PaysYou -> money.received
                else -> null
            }
            // Colour only the amount, which ends the line ("... RM 5.31").
            val cut = headline.lastIndexOf("RM ")
            val text = buildAnnotatedString {
                if (amountColor != null && cut >= 0) {
                    append(headline.substring(0, cut))
                    withStyle(SpanStyle(color = amountColor)) { append(headline.substring(cut)) }
                } else {
                    append(headline)
                }
            }
            HorizontalDivider(modifier = Modifier.padding(top = 20.dp), color = MaterialTheme.colorScheme.outlineVariant)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 56.dp)
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = text,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f)
                )
                if (balance != Balance.AllPaid) {
                    TextButton(onClick = onSettleUp) { Text("Settle up") }
                }
            }
        }
        detail.settleSuggestion?.let { receive ->
            item {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.padding(bottom = 8.dp)) {
                    Text(
                        text = "Possible settle up: ${receiveText(receive)}",
                        style = MaterialTheme.typography.bodyMedium
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = onConfirmSettle) { Text("Confirm") }
                        OutlinedButton(onClick = onDismissSettle) { Text("Not this") }
                    }
                }
            }
        }
        if (detail.owedToMe.isNotEmpty()) {
            item { SectionTitle("$name owes you") }
            items(detail.owedToMe, key = { "debt-${it.debt.id}" }) { view ->
                DebtRow(
                    view = view,
                    onOpenSplit = { onOpenSplit(view.debt.billId) },
                    onMarkPaid = { onMarkDebtPaid(view) },
                    onConfirm = { onConfirmDebt(view.debt.id) },
                    onDismiss = { onDismissDebt(view.debt.id) }
                )
            }
        }
        item { SectionTitle("You owe $name") }
        items(detail.iOwe, key = { "item-${it.id}" }) { item ->
            OwedItemRow(item = item, onClick = { onEditItem(item) }, onMarkPaid = { onMarkItemPaid(item.id) })
        }
        item {
            TextButton(onClick = onAddItem) { Text("+ Add what I owe") }
        }
    }
}

/** The one bold element: the QR on a white card in a gold koban ring. Tap to add or replace it. */
@Composable
private fun KobanFrame(name: String, hasQr: Boolean, qr: QrLoad?, onClick: () -> Unit) {
    val gold = LocalMoneyColors.current.gold
    val card = RoundedCornerShape(24.dp)
    Box(
        modifier = Modifier
            .border(9.dp, gold.copy(alpha = 0.18f), RoundedCornerShape(33.dp))
            .padding(9.dp)
    ) {
        Box(
            modifier = Modifier
                .width(240.dp)
                .clip(card)
                .background(Color.White)
                .border(4.dp, gold, card)
                .clickable(onClickLabel = if (hasQr) "Replace QR" else "Add QR", role = Role.Button, onClick = onClick)
                .padding(16.dp),
            contentAlignment = Alignment.Center
        ) {
            val bitmap = qr?.bitmap
            when {
                bitmap != null -> Image(
                    bitmap = bitmap,
                    contentDescription = "$name's payment QR",
                    modifier = Modifier
                        .fillMaxWidth()
                        .aspectRatio(bitmap.width.toFloat() / bitmap.height)
                )
                // Still loading: keep the square so the layout doesn't jump.
                hasQr && qr == null -> Box(Modifier.fillMaxWidth().aspectRatio(1f))
                else -> Box(Modifier.fillMaxWidth().aspectRatio(1f), contentAlignment = Alignment.Center) {
                    Text(
                        text = if (hasQr) "Couldn't load the QR. Tap to pick it again." else "Add their payment QR",
                        style = MaterialTheme.typography.titleSmall,
                        color = Ink,
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Column {
        Text(
            text = text,
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(top = 20.dp, bottom = 4.dp)
        )
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
    }
}

@Composable
private fun DebtRow(
    view: OpenDebtView,
    onOpenSplit: () -> Unit,
    onMarkPaid: () -> Unit,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit
) {
    Column {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(
                modifier = Modifier
                    .weight(1f)
                    .heightIn(min = 56.dp)
                    .clickable(onClickLabel = "Open split", role = Role.Button, onClick = onOpenSplit)
                    .padding(vertical = 8.dp),
                verticalArrangement = Arrangement.Center
            ) {
                Text(view.billMerchant ?: "Split bill", style = MaterialTheme.typography.bodyLarge)
                Text(
                    text = personDate(view.billTime),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            MoneyAmount(amount = view.debt.amount, style = MaterialTheme.typography.bodyLarge)
            TextButton(onClick = onMarkPaid) { Text("Mark paid") }
        }
        view.suggestedRepayment?.let { suggested ->
            Text(
                text = "Possible repayment: ${receiveText(suggested)}",
                style = MaterialTheme.typography.bodyMedium
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(bottom = 8.dp)) {
                Button(onClick = onConfirm) { Text("Confirm") }
                OutlinedButton(onClick = onDismiss) { Text("Not this") }
            }
        }
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
    }
}

@Composable
private fun OwedItemRow(item: OwedItemEntity, onClick: () -> Unit, onMarkPaid: () -> Unit) {
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 56.dp)
                .clickable(onClickLabel = "Edit", role = Role.Button, onClick = onClick)
                .padding(vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(item.description, style = MaterialTheme.typography.bodyLarge)
                Text(
                    text = personDate(item.itemDate),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            MoneyAmount(amount = item.amount, style = MaterialTheme.typography.bodyLarge)
            TextButton(onClick = onMarkPaid) { Text("Mark paid") }
        }
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
    }
}
