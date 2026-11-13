package com.expensetracker.app.ui.screens

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.provider.Settings
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Button
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.ui.components.Mon
import com.expensetracker.app.ui.components.MonFace
import com.expensetracker.app.ui.viewmodel.CheckPaymentsViewModel
import kotlinx.coroutines.launch
import kotlin.math.abs

/** Drag distances from the approved prototype. */
private val StampFullAt = 90.dp
private val CommitAt = 100.dp
private val FlyTo = 520.dp
private const val TILT_DP_PER_DEGREE = 18f
private const val STACK_DEPTH = 3
private const val CHOOSE_DIRECTION_MESSAGE = "Choose Spent or Received first."

internal tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

@Composable
fun CheckPaymentsScreen(onClose: () -> Unit, viewModel: CheckPaymentsViewModel = hiltViewModel()) {
    val cards by viewModel.waiting.collectAsStateWithLifecycle()
    val categories by viewModel.categories.collectAsStateWithLifecycle()
    val handled by viewModel.handled.collectAsStateWithLifecycle()
    val undoLabel by viewModel.undoLabel.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    // Leaving the screen commits the held swipe at once, so nothing waits on a closed screen.
    // Back is covered by the ViewModel onCleared; rotation must keep the Undo window.
    val activity = LocalContext.current.findActivity()
    LifecycleEventEffect(Lifecycle.Event.ON_STOP) {
        if (activity?.isChangingConfigurations != true) viewModel.flushHold()
    }
    LaunchedEffect(viewModel) {
        viewModel.messages.collect { scope.launch { snackbar.showSnackbar(it) } }
    }
    // The Undo pill keeps the screen open for its 4 seconds, so the last card can still come back.
    val done = cards?.isEmpty() == true && undoLabel == null
    LaunchedEffect(done) { if (done) onClose() }

    val loaded = cards ?: return
    val top = loaded.firstOrNull()
    val topId = top?.payment?.id
    val reduceMotion = rememberReduceMotion()
    val density = LocalDensity.current
    val commitPx = with(density) { CommitAt.toPx() }
    val flyPx = with(density) { FlyTo.toPx() }
    val stampPx = with(density) { StampFullAt.toPx() }
    val offset = remember(topId) { Animatable(0f) }
    var flying by remember(topId) { mutableStateOf(false) }
    var editing by remember { mutableStateOf<String?>(null) }

    fun decide(save: Boolean) {
        val id = topId ?: return
        if (flying) return
        // Save waits for a direction; the card springs back. Drop still works.
        if (save && top?.payment?.directionUnclear == true) {
            scope.launch {
                if (reduceMotion) offset.snapTo(0f) else offset.animateTo(0f, spring())
            }
            if (snackbar.currentSnackbarData == null) scope.launch { snackbar.showSnackbar(CHOOSE_DIRECTION_MESSAGE) }
            return
        }
        flying = true
        scope.launch {
            if (!reduceMotion) offset.animateTo(if (save) flyPx else -flyPx, tween(250))
            viewModel.swipe(id, save)
        }
    }

    val dragState = rememberDraggableState { delta -> scope.launch { offset.snapTo(offset.value + delta) } }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 8.dp, end = 20.dp, top = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onClose, modifier = Modifier.size(48.dp)) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                }
                Text(
                    "Check payments",
                    style = MaterialTheme.typography.titleLarge,
                    modifier = Modifier.weight(1f).padding(start = 4.dp).semantics { heading() }
                )
                if (top != null) {
                    Text(
                        text = "${handled + 1} of ${loaded.size + handled}",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 12.dp)
            ) {
                if (top == null) {
                    // Shown while the Undo pill of the last card is open; the screen closes after it.
                    Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
                        Mon(MonFace.HAPPY, 120.dp)
                        Text(
                            "All checked",
                            style = MaterialTheme.typography.headlineMedium,
                            modifier = Modifier.padding(top = 16.dp)
                        )
                        Text(
                            "Nothing left. I will just sit here and shine.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(top = 8.dp)
                        )
                    }
                }
                // Drawn back to front, so the oldest card is on top.
                loaded.take(STACK_DEPTH).asReversed().forEachIndexed { index, card ->
                    val depth = minOf(loaded.size, STACK_DEPTH) - 1 - index
                    key(card.payment.id) {
                        val isTop = depth == 0
                        val anim = if (reduceMotion) snap<Float>() else tween(250)
                        val lift by animateFloatAsState(depth.toFloat(), anim, label = "depth")
                        val layer = Modifier.graphicsLayer {
                                translationY = lift * 10.dp.toPx()
                                scaleX = 1f - lift * 0.04f
                                scaleY = 1f - lift * 0.04f
                                if (isTop) {
                                    translationX = offset.value
                                    rotationZ = offset.value / density.density / TILT_DP_PER_DEGREE
                                    alpha = if (flying) 1f - (abs(offset.value) / flyPx).coerceIn(0f, 1f) else 1f
                                } else {
                                    alpha = 1f - lift * 0.25f
                                }
                            }
                        CheckPaymentCard(
                            card = card,
                            stamp = { if (isTop) offset.value / stampPx else 0f },
                            onEdit = if (isTop) ({ editing = card.payment.id }) else null,
                            onChooseDirection = if (isTop) {
                                { type -> viewModel.edit(card.payment.copy(transactionType = type, directionUnclear = false)) }
                            } else {
                                null
                            },
                            // The drag sits outside the layer, so the tilt does not skew the drag distance.
                            modifier = if (isTop) {
                                Modifier
                                    .fillMaxWidth()
                                    .draggable(
                                        state = dragState,
                                        orientation = Orientation.Horizontal,
                                        enabled = !flying,
                                        onDragStopped = {
                                            when {
                                                abs(offset.value) > commitPx -> decide(offset.value > 0)
                                                reduceMotion -> offset.snapTo(0f)
                                                else -> offset.animateTo(0f, spring())
                                            }
                                        }
                                    )
                                    // Merged, so TalkBack can focus the card and offer its actions.
                                    .semantics(mergeDescendants = true) {
                                        val drop = CustomAccessibilityAction("Not a payment") { decide(false); true }
                                        // No Save while the direction is unclear; the Spent and Received buttons come first.
                                        customActions = if (card.payment.directionUnclear) {
                                            listOf(drop)
                                        } else {
                                            listOf(CustomAccessibilityAction("Save") { decide(true); true }, drop)
                                        }
                                    }
                                    .then(layer)
                            } else {
                                Modifier.fillMaxWidth().clearAndSetSemantics {}.then(layer)
                            }
                        )
                    }
                }
            }
            if (top != null) {
                Text(
                    text = "Tap a field to fix it. Swipe right to save, left for Not a payment.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 32.dp)
                )
                Row(
                    modifier = Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedButton(
                        onClick = { decide(false) },
                        modifier = Modifier.weight(1f).heightIn(min = 52.dp)
                    ) {
                        Icon(Icons.Default.Close, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("Not a payment", style = MaterialTheme.typography.labelLarge)
                    }
                    Button(
                        onClick = { decide(true) },
                        modifier = Modifier.weight(1f).heightIn(min = 52.dp)
                    ) {
                        Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("Save payment", style = MaterialTheme.typography.labelLarge)
                    }
                }
            } else {
                Button(
                    onClick = onClose,
                    modifier = Modifier.fillMaxWidth().padding(16.dp).heightIn(min = 52.dp)
                ) { Text("Back to Home", style = MaterialTheme.typography.labelLarge) }
            }
        }

        AnimatedVisibility(
            visible = undoLabel != null,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 140.dp)
        ) {
            // Holds the last text while it fades out.
            val text = remember { arrayOf("") }
            undoLabel?.let { text[0] = it }
            Text(
                text = text[0],
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.inverseOnSurface,
                modifier = Modifier
                    .heightIn(min = 48.dp)
                    .background(MaterialTheme.colorScheme.inverseSurface, CircleShape)
                    .clickable(role = Role.Button, onClickLabel = "Undo", onClick = viewModel::undo)
                    .semantics { liveRegion = LiveRegionMode.Polite }
                    .padding(horizontal = 18.dp, vertical = 12.dp)
            )
        }
        SnackbarHost(snackbar, modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 80.dp))
    }

    val editCard = loaded.find { it.payment.id == editing }
    if (editCard != null) {
        key(editCard.payment.id) {
            EditPaymentSheet(
                card = editCard,
                categories = categories,
                onSave = viewModel::edit,
                onDismiss = { editing = null }
            )
        }
    }
}

/** True when the owner turned animations off (animator duration scale 0). */
@Composable
private fun rememberReduceMotion(): Boolean {
    val context = LocalContext.current
    return remember {
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }
}
