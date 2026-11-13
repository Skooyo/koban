package com.expensetracker.app.ui.screens

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.parser.AmountFormatter
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import com.expensetracker.app.ui.components.DiscardChangesDialog
import com.expensetracker.app.ui.components.KobanRow
import com.expensetracker.app.ui.components.ListGroup
import com.expensetracker.app.ui.components.Mon
import com.expensetracker.app.ui.components.MonFace
import com.expensetracker.app.ui.components.MoneyText
import com.expensetracker.app.ui.components.SectionHeading
import com.expensetracker.app.ui.components.StepProgress
import com.expensetracker.app.ui.components.TonalButton
import com.expensetracker.app.ui.theme.LocalMoneyColors
import com.expensetracker.app.ui.viewmodel.ItemRow
import com.expensetracker.app.ui.viewmodel.SplitEditorState
import com.expensetracker.app.ui.viewmodel.SplitEditorViewModel
import com.expensetracker.app.ui.viewmodel.SplitStep

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SplitEditorScreen(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: SplitEditorViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val recent by viewModel.recentPeople.collectAsStateWithLifecycle()
    val context = LocalContext.current

    LaunchedEffect(state.finished) { if (state.finished) onBack() }

    fun goBack() {
        if (!viewModel.back()) onBack()
    }
    BackHandler { goBack() }
    if (state.confirmDiscard) {
        DiscardChangesDialog(
            onDiscard = {
                viewModel.discardEdits()
                onBack()
            },
            onKeepEditing = viewModel::keepEditing
        )
    }

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(
                title = { Text("Split a bill") },
                navigationIcon = {
                    IconButton(onClick = ::goBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        },
        bottomBar = {
            val action = bottomAction(state, viewModel)
            if (action != null) {
                Surface(tonalElevation = 3.dp) {
                    Button(
                        onClick = action.onClick,
                        enabled = action.enabled && !state.saving,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 12.dp)
                            .heightIn(min = 48.dp)
                    ) { Text(action.label) }
                }
            }
        }
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            if (!state.loading) {
                val number = stepNumber(state.step)
                StepProgress(number, stepNames.size, stepNames[number - 1], Modifier.padding(horizontal = 16.dp))
            }
            val content = Modifier.fillMaxWidth().weight(1f)
            when {
                state.loading -> Centered(content) { CircularProgressIndicator() }
                state.step == SplitStep.Photo -> PhotoStep(content, state.onlineAccess, viewModel)
                state.step == SplitStep.Reading -> Centered(content) {
                    CircularProgressIndicator()
                    Text("Reading the receipt…", style = MaterialTheme.typography.bodyLarge)
                }
                state.step == SplitStep.Items -> ItemsStep(content, state, viewModel)
                state.step == SplitStep.People -> PeopleStep(content, state, recent, viewModel)
                state.step == SplitStep.Assign -> AssignStep(content, state, viewModel)
                state.step == SplitStep.Link -> LinkStep(content, state, viewModel)
                else -> SummaryStep(
                    content, state, viewModel,
                    onShare = { text ->
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        context.startActivity(Intent.createChooser(send, "Share summary"))
                    }
                )
            }
        }
    }
}

private val stepNames = listOf("Receipt", "Items", "People", "Who had what", "Payment", "Summary")

private fun stepNumber(step: SplitStep) = when (step) {
    SplitStep.Photo, SplitStep.Reading -> 1
    SplitStep.Items -> 2
    SplitStep.People -> 3
    SplitStep.Assign -> 4
    SplitStep.Link -> 5
    SplitStep.Summary -> 6
}

/** `RM 12.50`, grouped. */
internal fun splitRm(amount: java.math.BigDecimal) = "RM ${AmountFormatter.formatGrouped(amount)}"

private data class BottomAction(val label: String, val enabled: Boolean, val onClick: () -> Unit)

private fun bottomAction(state: SplitEditorState, vm: SplitEditorViewModel): BottomAction? {
    if (state.loading) return null
    return when (state.step) {
        SplitStep.Photo, SplitStep.Reading -> null
        SplitStep.Items -> BottomAction(
            "Next",
            state.items.isNotEmpty() &&
                SplitEditorViewModel.parseItems(state) != null &&
                SplitEditorViewModel.chargesOf(state) != null,
            vm::next
        )
        SplitStep.People -> BottomAction("Next · ${state.people.size + 1} ${if (state.people.isEmpty()) "person" else "people"}", true, vm::next)
        SplitStep.Assign -> BottomAction("Next", SplitEditorViewModel.unassigned(state).isEmpty(), vm::next)
        SplitStep.Link ->
            if (state.locked) BottomAction("Save payment", true, vm::saveLockedPayment)
            else BottomAction("Next", true, vm::next)
        SplitStep.Summary -> if (state.locked) null else BottomAction("Done", true, vm::done)
    }
}

@Composable
internal fun Centered(modifier: Modifier, content: @Composable () -> Unit) {
    Column(
        modifier = modifier.padding(horizontal = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically)
    ) { content() }
}

@Composable
private fun PhotoStep(modifier: Modifier, online: Boolean, vm: SplitEditorViewModel) {
    var pending by rememberSaveable { mutableStateOf<Uri?>(null) }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { saved ->
        val uri = pending
        if (saved && uri != null) vm.readReceipt(uri) else vm.photoCancelled()
    }
    val gallery = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) vm.readReceipt(uri)
    }
    val activity = LocalContext.current.findActivity()
    fun takeWithCamera() {
        val uri = vm.newPhotoUri()
        pending = uri
        camera.launch(uri)
    }
    val scanner = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { result ->
        if (result.resultCode != Activity.RESULT_OK) return@rememberLauncherForActivityResult
        val uri = GmsDocumentScanningResult.fromActivityResultIntent(result.data)?.pages?.firstOrNull()?.imageUri
        if (uri != null) vm.readReceipt(uri)
    }
    fun takePhoto() {
        if (activity == null) return takeWithCamera()
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(false)
            .setPageLimit(1)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
        try {
            GmsDocumentScanning.getClient(options).getStartScanIntent(activity)
                .addOnSuccessListener { sender ->
                    runCatching { scanner.launch(IntentSenderRequest.Builder(sender).build()) }
                        .onFailure { takeWithCamera() }
                }
                .addOnFailureListener { takeWithCamera() }
        } catch (e: Exception) {
            takeWithCamera()
        }
    }
    Column(
        modifier = modifier.padding(horizontal = 16.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Column(
            modifier = Modifier.weight(1f).fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically)
        ) {
            Mon(MonFace.IDLE, 96.dp)
            Text(
                "Start with the receipt",
                style = MaterialTheme.typography.headlineMedium,
                textAlign = TextAlign.Center
            )
            Text(
                if (online) "Koban reads the items for you. With online access, the photo goes to Koban's server to be read, then it is deleted."
                else "Koban reads the items for you. The photo is read once and then deleted. It is not kept.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(
                onClick = ::takePhoto,
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
            ) {
                Icon(Icons.Default.CameraAlt, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text("Take photo")
            }
            OutlinedButton(
                onClick = { gallery.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
            ) {
                Icon(Icons.Default.Image, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text("Choose from gallery")
            }
            TextButton(onClick = vm::typeItemsInstead, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
                Text("Type items instead")
            }
        }
    }
}

@Composable
private fun ItemsStep(modifier: Modifier, state: SplitEditorState, vm: SplitEditorViewModel) {
    val total = SplitEditorViewModel.totalOf(state)
    val diff = SplitEditorViewModel.difference(state)
    var fixOpen by rememberSaveable { mutableStateOf(false) }
    if (fixOpen && (diff != null || state.readingAgain)) {
        FixSheet(diff, state, vm, onClose = { fixOpen = false })
    }
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        val hasTop = state.readSource != null || diff != null || state.message != null ||
            (state.readNote != null && diff == null)
        if (hasTop) item {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                state.readSource?.let {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(
                            Icons.Default.Check, contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp)
                        )
                        Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
                if (diff != null) MismatchCard(diff, total, state.printedTotal, onFix = { fixOpen = true })
                state.message?.let {
                    Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.error)
                }
                state.readNote?.takeIf { diff == null }?.let {
                    Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        item {
            OutlinedTextField(
                value = state.merchant,
                onValueChange = vm::setMerchant,
                label = { Text("Place") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
        }
        item {
            Column {
                SectionHeading("Items")
                if (state.items.isNotEmpty()) {
                    ListGroup {
                        state.items.forEach { row -> item(key = row.key) { ItemEditor(row, vm) } }
                    }
                }
                TextButton(
                    onClick = vm::addItem,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
                ) {
                    Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Add item")
                }
            }
        }
        item {
            Column {
                SectionHeading("Charges")
                ListGroup {
                    item { MoneyField("Service charge", state.serviceCharge, vm::setServiceCharge) }
                    item { MoneyField("SST", state.tax, vm::setTax) }
                    item { MoneyField("Discount", state.discount, vm::setDiscount) }
                    item {
                        MoneyField(
                            "Rounding", state.rounding, vm::setRounding,
                            keyboard = KeyboardType.Text, hint = "Use - for a negative amount"
                        )
                    }
                }
            }
        }
        item {
            ListGroup {
                item {
                    KobanRow(
                        "Total",
                        trailing = {
                            if (total != null) MoneyText(splitRm(total), style = MaterialTheme.typography.titleLarge)
                            else Text("Check the amounts", color = MaterialTheme.colorScheme.error)
                        }
                    )
                }
                state.printedTotal?.let { printed ->
                    item {
                        KobanRow(
                            "Receipt total",
                            trailing = {
                                MoneyText(
                                    splitRm(printed),
                                    style = MaterialTheme.typography.bodyLarge,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        )
                    }
                }
            }
        }
    }
}

/** Items and the receipt total differ: a card with the `review` outline and a Fix button. */
@Composable
private fun MismatchCard(diff: java.math.BigDecimal, total: java.math.BigDecimal?, printed: java.math.BigDecimal?, onFix: () -> Unit) {
    val review = LocalMoneyColors.current.review
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceContainer,
        border = BorderStroke(1.dp, review),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Default.Warning, contentDescription = null, tint = review, modifier = Modifier.size(20.dp))
                Text(
                    "Differs from the receipt total by RM ${AmountFormatter.formatDisplay(diff.abs())}.",
                    style = MaterialTheme.typography.titleMedium
                )
            }
            if (total != null && printed != null) {
                Text(
                    "Items add up to ${splitRm(total)}. The receipt says ${splitRm(printed)}.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            TonalButton("Fix", onFix, Modifier.align(Alignment.End))
        }
    }
}

/** Layout C from docs/prototypes/claude-fallback-prototype.html. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FixSheet(diff: java.math.BigDecimal?, state: SplitEditorState, vm: SplitEditorViewModel, onClose: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onClose) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 20.dp, end = 20.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            if (state.readingAgain) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    CircularProgressIndicator()
                    Text("Reading with Claude… about 10 seconds", style = MaterialTheme.typography.bodyLarge)
                }
                return@Column
            }
            if (diff == null) return@Column
            Text(
                "Differs from the receipt total by RM ${AmountFormatter.formatDisplay(diff.abs())}",
                style = MaterialTheme.typography.titleMedium
            )
            Button(
                onClick = { vm.addRoundingDifference(); onClose() },
                modifier = Modifier.fillMaxWidth()
            ) { Text("Add RM ${AmountFormatter.formatDisplay(diff)} as rounding") }
            OutlinedButton(onClick = onClose, modifier = Modifier.fillMaxWidth()) { Text("Edit by hand") }
            if (state.canReadAgain) {
                OutlinedButton(onClick = vm::readAgainWithClaude, modifier = Modifier.fillMaxWidth()) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("Read again with Claude")
                        Text(
                            "Sends the photo to Koban's server" +
                                (state.readsLeft?.let { " · $it reads left today" } ?: ""),
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ItemEditor(row: ItemRow, vm: SplitEditorViewModel) {
    Column(Modifier.padding(horizontal = 16.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = row.name,
                onValueChange = { v -> vm.updateItem(row.key) { it.copy(name = v) } },
                label = { Text("Item") },
                singleLine = true,
                modifier = Modifier.weight(1f)
            )
            IconButton(onClick = { vm.removeItem(row.key) }) {
                Icon(
                    Icons.Default.Delete,
                    contentDescription = "Remove ${row.name.ifBlank { "item" }}",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(
                value = row.quantity,
                onValueChange = { v -> vm.updateItem(row.key) { it.copy(quantity = v) } },
                label = { Text("Qty") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.width(88.dp)
            )
            OutlinedTextField(
                value = row.price,
                onValueChange = { v -> vm.updateItem(row.key) { it.copy(price = v) } },
                label = { Text("Line price (RM)") },
                isError = row.price.isNotBlank() && (AmountFormatter.parseInput(row.price)?.signum() ?: 0) <= 0,
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun MoneyField(
    label: String,
    value: String,
    onChange: (String) -> Unit,
    keyboard: KeyboardType = KeyboardType.Decimal,
    hint: String? = null
) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text("$label (RM)") },
        supportingText = hint?.let { { Text(it) } },
        singleLine = true,
        isError = value.isNotBlank() && AmountFormatter.parseInput(value) == null,
        keyboardOptions = KeyboardOptions(keyboardType = keyboard),
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)
    )
}
