package com.expensetracker.app.ui.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.ui.components.KobanRow
import com.expensetracker.app.ui.viewmodel.PaymentAppsViewModel

/** Pick which installed apps Koban listens to. Save with none ticked is allowed. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PaymentAppsScreen(
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
    onBack: () -> Unit = onClose,
    viewModel: PaymentAppsViewModel = hiltViewModel()
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val apps = state.apps

    Scaffold(
        modifier = modifier,
        contentWindowInsets = WindowInsets(0),
        topBar = {
            TopAppBar(
                windowInsets = WindowInsets(0),
                title = { Text("Payment apps") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        },
        bottomBar = {
            Button(
                onClick = { viewModel.save(onClose) },
                enabled = apps != null,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
                    .heightIn(min = 48.dp)
            ) {
                Text(
                    when (state.selected.size) {
                        0 -> "Save"
                        1 -> "Save 1 app"
                        else -> "Save ${state.selected.size} apps"
                    }
                )
            }
        }
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            Text(
                text = "Koban reads notifications only from the apps you tick.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
            )
            OutlinedTextField(
                value = state.query,
                onValueChange = viewModel::setQuery,
                placeholder = { Text("Search apps") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                singleLine = true,
                shape = CircleShape,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)
            )
            if (apps == null) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            } else {
                val shown = apps.filter { it.label.contains(state.query.trim(), ignoreCase = true) }
                LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp)) {
                    if (shown.isEmpty()) {
                        item {
                            Text(
                                text = "No apps match.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                    itemsIndexed(shown, key = { _, app -> app.packageName }) { i, app ->
                        val checked = app.packageName in state.selected
                        val shape = RoundedCornerShape(
                            topStart = if (i == 0) 16.dp else 0.dp,
                            topEnd = if (i == 0) 16.dp else 0.dp,
                            bottomStart = if (i == shown.lastIndex) 16.dp else 0.dp,
                            bottomEnd = if (i == shown.lastIndex) 16.dp else 0.dp
                        )
                        Column(Modifier.clip(shape).background(MaterialTheme.colorScheme.surfaceContainer)) {
                            if (i > 0) HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                            KobanRow(
                                title = app.label,
                                leading = {
                                    if (app.icon != null) {
                                        Image(bitmap = app.icon, contentDescription = null, modifier = Modifier.size(40.dp))
                                    } else {
                                        Initials(app.label)
                                    }
                                },
                                trailing = { Checkbox(checked = checked, onCheckedChange = null) },
                                modifier = Modifier.toggleable(
                                    value = checked,
                                    role = Role.Checkbox,
                                    onValueChange = { viewModel.toggle(app.packageName) }
                                )
                            )
                        }
                    }
                }
            }
        }
    }
}

/** Two-letter circle for an app that has no icon. */
@Composable
private fun Initials(label: String) {
    Box(
        Modifier.size(40.dp).clip(CircleShape).background(MaterialTheme.colorScheme.surfaceContainerHighest),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label.trim().take(2).uppercase(),
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurface
        )
    }
}
