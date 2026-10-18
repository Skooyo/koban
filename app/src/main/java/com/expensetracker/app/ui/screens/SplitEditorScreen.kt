package com.expensetracker.app.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.ui.components.MoneyAmount
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
                            .padding(horizontal = 20.dp, vertical = 12.dp)
                    ) { Text(action.label) }
                }
            }
        }
    ) { padding ->
        val content = Modifier
            .fillMaxSize()
            .padding(padding)
        when {
            state.loading -> Centered(content) { CircularProgressIndicator() }
            state.step == SplitStep.Photo -> PhotoStep(content, viewModel)
            state.step == SplitStep.Reading -> Centered(content) {
                CircularProgressIndicator()
                Text("Reading receipt…", style = MaterialTheme.typography.bodyLarge)
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
        SplitStep.People -> BottomAction("Next", true, vm::next)
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
private fun PhotoStep(modifier: Modifier, vm: SplitEditorViewModel) {
    var pending by rememberSaveable { mutableStateOf<Uri?>(null) }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { saved ->
        val uri = pending
        if (saved && uri != null) vm.readReceipt(uri) else vm.photoCancelled()
    }
    val gallery = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) vm.readReceipt(uri)
    }
    Column(
        modifier = modifier.padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("Start with the receipt", style = MaterialTheme.typography.headlineMedium)
        Text(
            "The photo is read once and then deleted. It is not kept.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Button(
            onClick = {
                val uri = vm.newPhotoUri()
                pending = uri
                camera.launch(uri)
            },
            modifier = Modifier.fillMaxWidth()
        ) { Text("Take photo") }
        OutlinedButton(onClick = { gallery.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }, modifier = Modifier.fillMaxWidth()) {
            Text("Choose from gallery")
        }
        TextButton(onClick = vm::typeItemsInstead, modifier = Modifier.fillMaxWidth()) {
            Text("Type items instead")
        }
    }
}

@Composable
private fun ItemsStep(modifier: Modifier, state: SplitEditorState, vm: SplitEditorViewModel) {
    val total = SplitEditorViewModel.totalOf(state)
    val diff = SplitEditorViewModel.difference(state)
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Text("Items", style = MaterialTheme.typography.headlineMedium)
            state.message?.let {
                Text(
                    it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(top = 4.dp)
                )
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
        items(state.items, key = { it.key }) { row -> ItemEditor(row, vm) }
        item {
            OutlinedButton(onClick = vm::addItem, modifier = Modifier.fillMaxWidth()) { Text("Add item") }
        }
        item {
            Text("Charges", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 8.dp))
        }
        item { MoneyField("Service charge", state.serviceCharge, vm::setServiceCharge) }
        item { MoneyField("SST", state.tax, vm::setTax) }
        item { MoneyField("Discount", state.discount, vm::setDiscount) }
        item {
            MoneyField(
                "Rounding", state.rounding, vm::setRounding,
                keyboard = KeyboardType.Text, hint = "Use - for a negative amount"
            )
        }
        item {
            HorizontalDivider()
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Total", style = MaterialTheme.typography.titleMedium)
                if (total != null) MoneyAmount(total, MaterialTheme.typography.titleLarge)
                else Text("Check the amounts", color = MaterialTheme.colorScheme.error)
            }
            state.printedTotal?.let { printed ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Receipt total", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    MoneyAmount(printed, MaterialTheme.typography.bodyLarge)
                }
            }
        }
        if (diff != null) {
            item {
                Text(
                    "The items and charges differ from the receipt total by RM ${AmountFormatter.formatDisplay(diff.abs())}.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.error
                )
                OutlinedButton(
                    onClick = vm::addRoundingDifference,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp)
                ) { Text("Add RM ${AmountFormatter.formatDisplay(diff)} as rounding") }
            }
        }
    }
}

@Composable
private fun ItemEditor(row: ItemRow, vm: SplitEditorViewModel) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = row.name,
                onValueChange = { v -> vm.updateItem(row.key) { it.copy(name = v) } },
                label = { Text("Item") },
                singleLine = true,
                modifier = Modifier.weight(1f)
            )
            IconButton(onClick = { vm.removeItem(row.key) }) {
                Icon(Icons.Default.Delete, contentDescription = "Remove ${row.name.ifBlank { "item" }}")
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
        modifier = Modifier.fillMaxWidth()
    )
}
