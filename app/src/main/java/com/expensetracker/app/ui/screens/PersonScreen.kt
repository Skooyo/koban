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
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import com.expensetracker.app.ui.components.KobanRow
import com.expensetracker.app.ui.components.ListGroup
import com.expensetracker.app.ui.components.MoneyAmount
import com.expensetracker.app.ui.components.SectionHeading
import com.expensetracker.app.ui.components.TonalButton
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

private enum class Dialog { RENAME, DELETE, SETTLE, ADD_ITEM, ADD_OWED_TO_ME }

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
    var deletingItem by remember { mutableStateOf<OwedItemEntity?>(null) }
    var editingDebt by remember { mutableStateOf<OpenDebtView?>(null) }
    var deletingDebt by remember { mutableStateOf<OpenDebtView?>(null) }

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
        contentWindowInsets = WindowInsets(0),
        topBar = {
            TopAppBar(
                windowInsets = WindowInsets(0),
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
            onOpenDebt = { view -> if (view.manual) editingDebt = view else onOpenSplit(view.debt.billId) },
            onAddOwedToMe = { dialog = Dialog.ADD_OWED_TO_ME },
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
            title = "Add what I owe",
            onDismiss = { dialog = null },
            onSave = viewModel::addItem,
            onDelete = null
        )
        Dialog.ADD_OWED_TO_ME -> OwedItemDialog(
            title = "Add what $name owes me",
            onDismiss = { dialog = null },
            onSave = viewModel::addOwedToMe,
            onDelete = null
        )
        null -> Unit
    }
    editingDebt?.let { view ->
        OwedItemDialog(
            title = "Edit what $name owes me",
            description = view.billMerchant.orEmpty(),
            amount = view.debt.amount,
            itemDate = view.billTime,
            onDismiss = { editingDebt = null },
            onSave = { description, amount, itemDate ->
                viewModel.updateOwedToMe(view.debt.id, description, amount, itemDate)
            },
            onDelete = {
                editingDebt = null
                deletingDebt = view
            }
        )
    }
    deletingDebt?.let { view ->
        DeleteOwedItemDialog(
            text = "This removes what $name owes you for it.",
            onDismiss = { deletingDebt = null },
            onConfirm = {
                deletingDebt = null
                viewModel.deleteOwedToMe(view.debt.id)
            }
        )
    }
    editing?.let { item ->
        OwedItemDialog(
            title = "Edit what I owe",
            description = item.description,
            amount = item.amount,
            itemDate = item.itemDate,
            onDismiss = { editing = null },
            onSave = { description, amount, itemDate ->
                viewModel.updateItem(item.copy(description = description, amount = amount, itemDate = itemDate))
            },
            onDelete = {
                editing = null
                deletingItem = item
            }
        )
    }
    deletingItem?.let { item ->
        DeleteOwedItemDialog(
            text = "This removes what you owe for it.",
            onDismiss = { deletingItem = null },
            onConfirm = {
                deletingItem = null
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
    onOpenDebt: (OpenDebtView) -> Unit,
    onAddOwedToMe: () -> Unit,
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
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 32.dp)
    ) {
        item {
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                KobanFrame(name = name, hasQr = hasQr, qr = qr, onClick = onQrClick)
            }
        }
        if (hasQr) {
            item {
                TonalButton(
                    text = "Save QR to gallery",
                    onClick = onSaveQr,
                    modifier = Modifier.fillMaxWidth().padding(top = 20.dp),
                    icon = Icons.Default.Download
                )
                Text(
                    text = "Then open your bank app and pick it from the gallery",
                    style = MaterialTheme.typography.bodySmall,
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
                is Balance.YouPay -> money.goldText
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
            Column(
                modifier = Modifier
                    .padding(top = 16.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(MaterialTheme.colorScheme.surfaceContainer)
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = text,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
                if (balance != Balance.AllPaid) {
                    Button(onClick = onSettleUp, modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp)) {
                        Text("Settle up", style = MaterialTheme.typography.labelLarge)
                    }
                }
            }
        }
        detail.settleSuggestion?.let { receive ->
            item {
                RepaymentCard(
                    title = "Possible settle up",
                    text = receiveText(receive),
                    onConfirm = onConfirmSettle,
                    onDismiss = onDismissSettle,
                    modifier = Modifier.padding(top = 16.dp)
                )
            }
        }
        item { SectionHeading("$name owes you", Modifier.padding(top = 24.dp)) }
        if (detail.owedToMe.isEmpty()) {
            item { NothingText() }
        } else {
            item {
                ListGroup {
                    detail.owedToMe.forEach { view ->
                        item {
                            DebtRow(
                                view = view,
                                onOpen = { onOpenDebt(view) },
                                onMarkPaid = { onMarkDebtPaid(view) },
                                onConfirm = { onConfirmDebt(view.debt.id) },
                                onDismiss = { onDismissDebt(view.debt.id) }
                            )
                        }
                    }
                }
            }
        }
        item { AddButton("Add what $name owes me", onAddOwedToMe) }
        item { SectionHeading("You owe $name", Modifier.padding(top = 16.dp)) }
        if (detail.iOwe.isEmpty()) {
            item { NothingText() }
        } else {
            item {
                ListGroup {
                    detail.iOwe.forEach { owed ->
                        item {
                            OwedItemRow(item = owed, onClick = { onEditItem(owed) }, onMarkPaid = { onMarkItemPaid(owed.id) })
                        }
                    }
                }
            }
        }
        item { AddButton("Add what I owe", onAddItem) }
    }
}

/** The QR on a white box with a gold frame. Tap to add or replace it. White stays white in the dark theme so the QR scans. */
@Composable
private fun KobanFrame(name: String, hasQr: Boolean, qr: QrLoad?, onClick: () -> Unit) {
    val card = RoundedCornerShape(28.dp)
    Box(
        modifier = Modifier
            .width(240.dp)
            .clip(card)
            .background(Color.White)
            .border(6.dp, MaterialTheme.colorScheme.primary, card)
            .clickable(onClickLabel = if (hasQr) "Replace QR" else "Add QR", role = Role.Button, onClick = onClick)
            .padding(20.dp),
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
                    color = Color.Black,
                    textAlign = TextAlign.Center
                )
            }
        }
    }
}

@Composable
private fun NothingText() {
    Text("Nothing.", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

@Composable
private fun AddButton(text: String, onClick: () -> Unit) {
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        TextButton(onClick = onClick, modifier = Modifier.defaultMinSize(minHeight = 48.dp)) {
            Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text(text)
        }
    }
}

/** A possible match for a received payment: gold outline, Confirm (tonal) and Not this (text). */
@Composable
private fun RepaymentCard(title: String, text: String, onConfirm: () -> Unit, onDismiss: () -> Unit, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(16.dp)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(MaterialTheme.colorScheme.surfaceContainer)
            .border(1.dp, MaterialTheme.colorScheme.primary, shape)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Icons.Default.Info, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(20.dp))
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        }
        Text(text, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.End)) {
            TextButton(onClick = onDismiss, modifier = Modifier.defaultMinSize(minHeight = 48.dp)) { Text("Not this") }
            TonalButton("Confirm", onConfirm)
        }
    }
}

@Composable
private fun DebtRow(
    view: OpenDebtView,
    onOpen: () -> Unit,
    onMarkPaid: () -> Unit,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit
) {
    Column {
        KobanRow(
            title = view.billMerchant ?: "Split bill",
            subtitle = personDate(view.billTime),
            trailing = {
                MoneyAmount(
                    amount = view.debt.amount,
                    style = MaterialTheme.typography.titleMedium,
                    color = LocalMoneyColors.current.received
                )
            },
            onClick = onOpen,
            onClickLabel = if (view.manual) "Edit" else "Open split"
        )
        MarkPaidButton(onMarkPaid)
        view.suggestedRepayment?.let { suggested ->
            RepaymentCard(
                title = "Possible repayment",
                text = receiveText(suggested),
                onConfirm = onConfirm,
                onDismiss = onDismiss,
                modifier = Modifier.padding(start = 12.dp, end = 12.dp, bottom = 12.dp)
            )
        }
    }
}

@Composable
private fun OwedItemRow(item: OwedItemEntity, onClick: () -> Unit, onMarkPaid: () -> Unit) {
    Column {
        KobanRow(
            title = item.description,
            subtitle = personDate(item.itemDate),
            trailing = {
                MoneyAmount(
                    amount = item.amount,
                    style = MaterialTheme.typography.titleMedium,
                    color = LocalMoneyColors.current.goldText
                )
            },
            onClick = onClick,
            onClickLabel = "Edit"
        )
        MarkPaidButton(onMarkPaid)
    }
}

@Composable
private fun MarkPaidButton(onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(end = 8.dp), horizontalArrangement = Arrangement.End) {
        TextButton(onClick = onClick, modifier = Modifier.defaultMinSize(minHeight = 48.dp)) { Text("Mark paid") }
    }
}
