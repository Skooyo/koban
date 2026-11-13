package com.expensetracker.app.ui

import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ReceiptLong
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.People
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import android.app.Activity
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NamedNavArgument
import androidx.navigation.NavBackStackEntry
import androidx.navigation.NavController
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.expensetracker.app.ui.navigation.Routes
import com.expensetracker.app.ui.screens.ActivityScreen
import com.expensetracker.app.ui.screens.CheckPaymentsScreen
import com.expensetracker.app.ui.screens.GroupScreen
import com.expensetracker.app.ui.screens.GroupsScreen
import com.expensetracker.app.ui.screens.HomeScreen
import com.expensetracker.app.ui.screens.NotificationDebugScreen
import com.expensetracker.app.ui.screens.OnboardingScreen
import com.expensetracker.app.ui.screens.PaymentAppsScreen
import com.expensetracker.app.ui.screens.PaymentScreen
import com.expensetracker.app.ui.screens.PeopleScreen
import com.expensetracker.app.ui.screens.PersonScreen
import com.expensetracker.app.ui.screens.SettingsScreen
import com.expensetracker.app.ui.screens.SplitEditorScreen
import com.expensetracker.app.ui.viewmodel.AppViewModel
import kotlinx.coroutines.flow.first

private data class BottomNavItem(val route: String, val label: String, val icon: androidx.compose.ui.graphics.vector.ImageVector)

private val bottomNavItems = listOf(
    BottomNavItem(Routes.HOME, "Home", Icons.Default.Home),
    BottomNavItem(Routes.ACTIVITY, "Activity", Icons.AutoMirrored.Filled.ReceiptLong),
    BottomNavItem(Routes.PEOPLE, "People", Icons.Default.People),
    BottomNavItem(Routes.GROUPS, "Groups", Icons.Default.Groups)
)

private val topLevelRoutes = setOf(Routes.HOME, Routes.ACTIVITY, Routes.PEOPLE, Routes.GROUPS)

// Screen motion, modeled on Touch 'n Go (measured from a screen recording, 13 Nov 2026):
// an opened screen slides in across the full width while the screen below moves 30% left and darkens;
// Back reverses it. Tabs switch at once. The payment page rises like a sheet.
// Android's "remove animations" setting skips all of it.
private const val PUSH_MS = 400
private const val SHEET_OPEN_MS = 450
private const val SHEET_CLOSE_MS = 300

/** How far the screen below moves, as a share of the width, and how dark it gets (alpha over night). */
private const val PARALLAX = 0.3f
private const val UNDER_ALPHA = 0.6f

/** Material 3 emphasized decelerate and accelerate curves. */
private val EmphasizedDecelerate = CubicBezierEasing(0.05f, 0.7f, 0.1f, 1f)
private val EmphasizedAccelerate = CubicBezierEasing(0.3f, 0f, 0.8f, 0.15f)

/** The payment page (add and edit) opens and closes like a bottom sheet. */
private val sheetRoutes = setOf(Routes.PAYMENT_NEW, Routes.PAYMENT_EDIT)

private fun NavBackStackEntry.isSheet() = destination.route in sheetRoutes

private fun AnimatedContentTransitionScope<NavBackStackEntry>.isTabSwitch() =
    initialState.destination.route in topLevelRoutes && targetState.destination.route in topLevelRoutes

private fun <T> push() = tween<T>(PUSH_MS, easing = FastOutSlowInEasing)

/** The opened screen comes in from the right edge; on Back it leaves the same way. */
private fun pushIn(): EnterTransition = slideInHorizontally(push()) { it }
private fun pushOut(): ExitTransition = slideOutHorizontally(push()) { it }

/** The screen below moves 30% left and darkens while a screen covers it, and returns on Back. */
private fun underOut(): ExitTransition =
    slideOutHorizontally(push()) { -(it * PARALLAX).toInt() } + fadeOut(push(), targetAlpha = UNDER_ALPHA)
private fun underIn(): EnterTransition =
    slideInHorizontally(push()) { -(it * PARALLAX).toInt() } + fadeIn(push(), initialAlpha = UNDER_ALPHA)

/** A tab screen with the tab bar under it. The bar moves with the screen when another screen covers it. */
private fun NavGraphBuilder.tab(
    route: String,
    bar: @Composable (String) -> Unit,
    content: @Composable (NavBackStackEntry) -> Unit
) = composable(route) { entry ->
    Column(Modifier.fillMaxSize()) {
        Box(Modifier.weight(1f)) { content(entry) }
        bar(route)
    }
}

/** An opened screen. Its background fills the system-bar space too, so it covers the tab bar fully. */
private fun NavGraphBuilder.page(
    route: String,
    arguments: List<NamedNavArgument> = emptyList(),
    content: @Composable (NavBackStackEntry) -> Unit
) = composable(route, arguments) { entry ->
    Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background).navigationBarsPadding()) {
        content(entry)
    }
}

@Composable
private fun BottomBar(route: String, openPeopleCount: Int, onSelect: (String) -> Unit) {
    NavigationBar(containerColor = MaterialTheme.colorScheme.surfaceContainer) {
        bottomNavItems.forEach { item ->
            NavigationBarItem(
                icon = {
                    if (item.route == Routes.PEOPLE && openPeopleCount > 0) {
                        BadgedBox(badge = {
                            Badge(Modifier.semantics { contentDescription = "$openPeopleCount open" }) {
                                Text("$openPeopleCount")
                            }
                        }) {
                            Icon(item.icon, contentDescription = item.label)
                        }
                    } else {
                        Icon(item.icon, contentDescription = item.label)
                    }
                },
                label = { Text(item.label) },
                selected = item.route == route,
                onClick = { onSelect(item.route) },
                colors = NavigationBarItemDefaults.colors(indicatorColor = MaterialTheme.colorScheme.primaryContainer)
            )
        }
    }
}

/** Key under which the payment page hands its closing message to the screen below it. */
private const val PAYMENT_MESSAGE = "paymentMessage"

/** Switches tabs the way a bottom-bar tap does: one copy per tab, each tab keeps its state. */
private fun NavController.navigateToTab(route: String) = navigate(route) {
    popUpTo(graph.findStartDestination().id) {
        saveState = true
    }
    launchSingleTop = true
    restoreState = true
}

/** Pops the payment page, if it is still on top, and leaves [message] for the screen below. */
private fun NavController.closePayment(entry: NavBackStackEntry, message: String?) {
    if (currentBackStackEntry != entry) return
    if (message != null) previousBackStackEntry?.savedStateHandle?.set(PAYMENT_MESSAGE, message)
    popBackStack()
}

@Composable
fun ExpenseTrackerNavHost(modifier: Modifier = Modifier, appViewModel: AppViewModel = hiltViewModel()) {
    val navController = rememberNavController()
    val openPeopleCount by appViewModel.openPeopleCount.collectAsStateWithLifecycle()

    // Auto-open: one check per start of the activity, so backing out does not reopen the swipe screen.
    val activity = LocalContext.current as? Activity
    var autoOpenTurn by remember { mutableIntStateOf(0) }
    LifecycleEventEffect(Lifecycle.Event.ON_START) {
        if (appViewModel.takeAutoOpenTurn()) autoOpenTurn++
    }
    LifecycleEventEffect(Lifecycle.Event.ON_STOP) {
        appViewModel.onActivityStop(activity?.isChangingConfigurations == true)
    }
    LaunchedEffect(autoOpenTurn) {
        if (autoOpenTurn == 0) return@LaunchedEffect
        val count = appViewModel.waitingCountNow()
        // Waits for the graph on a cold start.
        val route = navController.currentBackStackEntryFlow.first().destination.route
        // Onboarding comes first, then the payment-apps picker, then the swipe screen.
        if (route in topLevelRoutes && appViewModel.onboardingDue()) {
            navController.navigate(Routes.ONBOARDING) { launchSingleTop = true }
        } else if (route in topLevelRoutes && appViewModel.paymentAppsDue()) {
            navController.navigate(Routes.PAYMENT_APPS) { launchSingleTop = true }
        } else if (count > 0 && route in topLevelRoutes) {
            navController.navigate(Routes.CHECK) { launchSingleTop = true }
        }
    }

    val bar: @Composable (String) -> Unit = { route ->
        BottomBar(route, openPeopleCount, onSelect = { navController.navigateToTab(it) })
    }

    // The tab bar belongs to each tab screen (see tab()), so an opened screen slides over it and Back
    // uncovers it, as in Touch 'n Go. Each screen handles the bottom system-bar space itself.
    Scaffold(modifier = modifier) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Routes.HOME,
            modifier = Modifier.padding(top = innerPadding.calculateTopPadding()),
            enterTransition = {
                when {
                    targetState.isSheet() -> slideInVertically(tween(SHEET_OPEN_MS, easing = EmphasizedDecelerate)) { it }
                    isTabSwitch() -> EnterTransition.None
                    else -> pushIn()
                }
            },
            exitTransition = {
                when {
                    targetState.isSheet() -> ExitTransition.KeepUntilTransitionsFinished
                    isTabSwitch() -> ExitTransition.None
                    else -> underOut()
                }
            },
            // A Home tab tap pops back to the start screen, so tab switches also arrive here.
            popEnterTransition = {
                when {
                    initialState.isSheet() || isTabSwitch() -> EnterTransition.None
                    else -> underIn()
                }
            },
            popExitTransition = {
                when {
                    initialState.isSheet() -> slideOutVertically(tween(SHEET_CLOSE_MS, easing = EmphasizedAccelerate)) { it }
                    isTabSwitch() -> ExitTransition.None
                    else -> pushOut()
                }
            }
        ) {
            tab(Routes.HOME, bar) { entry ->
                val message by entry.savedStateHandle.getStateFlow<String?>(PAYMENT_MESSAGE, null)
                    .collectAsStateWithLifecycle()
                HomeScreen(
                    onOpenActivity = { navController.navigateToTab(Routes.ACTIVITY) },
                    onAddPayment = { navController.navigate(Routes.PAYMENT_NEW) { launchSingleTop = true } },
                    onEditPayment = { id -> navController.navigate(Routes.paymentEdit(id)) { launchSingleTop = true } },
                    onOpenSettings = { navController.navigate(Routes.SETTINGS) { launchSingleTop = true } },
                    onCheckPayments = { navController.navigate(Routes.CHECK) { launchSingleTop = true } },
                    onChoosePaymentApps = { navController.navigate(Routes.PAYMENT_APPS) { launchSingleTop = true } },
                    message = message,
                    onMessageShown = { entry.savedStateHandle[PAYMENT_MESSAGE] = null }
                )
            }
            tab(Routes.ACTIVITY, bar) { entry ->
                val message by entry.savedStateHandle.getStateFlow<String?>(PAYMENT_MESSAGE, null)
                    .collectAsStateWithLifecycle()
                ActivityScreen(
                    onAddPayment = { navController.navigate(Routes.PAYMENT_NEW) { launchSingleTop = true } },
                    onEditPayment = { id -> navController.navigate(Routes.paymentEdit(id)) { launchSingleTop = true } },
                    message = message,
                    onMessageShown = { entry.savedStateHandle[PAYMENT_MESSAGE] = null }
                )
            }
            tab(Routes.PEOPLE, bar) {
                PeopleScreen(
                    onOpenPerson = { id -> navController.navigate(Routes.person(id)) },
                    onOpenSplit = { id -> navController.navigate(Routes.splitEdit(id)) },
                    onSplitBill = { navController.navigate(Routes.splitNew(null)) }
                )
            }
            tab(Routes.GROUPS, bar) {
                GroupsScreen(onOpenGroup = { id -> navController.navigate(Routes.group(id)) { launchSingleTop = true } })
            }
            page(
                route = Routes.GROUP,
                arguments = listOf(navArgument("groupId") { type = NavType.StringType })
            ) { entry ->
                GroupScreen(onBack = { if (navController.currentBackStackEntry == entry) navController.popBackStack() })
            }
            page(
                route = Routes.PERSON,
                arguments = listOf(navArgument("personId") { type = NavType.StringType })
            ) { entry ->
                PersonScreen(
                    personId = entry.arguments?.getString("personId").orEmpty(),
                    onBack = { navController.popBackStack() },
                    onOpenSplit = { id -> navController.navigate(Routes.splitEdit(id)) }
                )
            }
            page(
                route = Routes.SPLIT_NEW,
                arguments = listOf(
                    navArgument("expenseId") {
                        type = NavType.StringType
                        nullable = true
                        defaultValue = null
                    }
                )
            ) {
                SplitEditorScreen(onBack = { navController.popBackStack() })
            }
            page(
                route = Routes.SPLIT_EDIT,
                arguments = listOf(navArgument("billId") { type = NavType.StringType })
            ) {
                SplitEditorScreen(onBack = { navController.popBackStack() })
            }
            page(Routes.PAYMENT_NEW) { entry ->
                PaymentScreen(
                    onClose = { message -> navController.closePayment(entry, message) },
                    onSplit = { id ->
                        if (navController.currentBackStackEntry == entry) {
                            navController.popBackStack()
                            navController.navigate(Routes.splitNew(id))
                        }
                    }
                )
            }
            page(
                route = Routes.PAYMENT_EDIT,
                arguments = listOf(navArgument("expenseId") { type = NavType.StringType })
            ) { entry ->
                PaymentScreen(
                    onClose = { message -> navController.closePayment(entry, message) },
                    onSplit = { id ->
                        if (navController.currentBackStackEntry == entry) {
                            navController.popBackStack()
                            navController.navigate(Routes.splitNew(id))
                        }
                    }
                )
            }
            page(Routes.CHECK) { entry ->
                CheckPaymentsScreen(onClose = {
                    if (navController.currentBackStackEntry == entry) navController.popBackStack()
                })
            }
            page(Routes.SETTINGS) {
                SettingsScreen(
                    onBack = { navController.popBackStack() },
                    onOpenNotificationDebug = {
                        navController.navigate(Routes.NOTIFICATION_DEBUG)
                    },
                    onOpenPaymentApps = { navController.navigate(Routes.PAYMENT_APPS) { launchSingleTop = true } }
                )
            }
            page(Routes.PAYMENT_APPS) { entry ->
                PaymentAppsScreen(onClose = {
                    if (navController.currentBackStackEntry == entry) navController.popBackStack()
                })
            }
            page(Routes.ONBOARDING) {
                OnboardingScreen(onFinished = { navController.popBackStack(Routes.HOME, inclusive = false) })
            }
            page(Routes.NOTIFICATION_DEBUG) {
                NotificationDebugScreen(onBack = { navController.popBackStack() })
            }
        }
    }
}
