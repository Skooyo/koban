package com.expensetracker.app.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ReceiptLong
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.People
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavBackStackEntry
import androidx.navigation.NavController
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.expensetracker.app.ui.navigation.Routes
import com.expensetracker.app.ui.screens.ActivityScreen
import com.expensetracker.app.ui.screens.HomeScreen
import com.expensetracker.app.ui.screens.NotificationDebugScreen
import com.expensetracker.app.ui.screens.PaymentScreen
import com.expensetracker.app.ui.screens.PeopleScreen
import com.expensetracker.app.ui.screens.PersonScreen
import com.expensetracker.app.ui.screens.SettingsScreen
import com.expensetracker.app.ui.screens.SplitEditorScreen
import com.expensetracker.app.ui.viewmodel.AppViewModel

private data class BottomNavItem(val route: String, val label: String, val icon: androidx.compose.ui.graphics.vector.ImageVector)

private val bottomNavItems = listOf(
    BottomNavItem(Routes.HOME, "Home", Icons.Default.Home),
    BottomNavItem(Routes.ACTIVITY, "Activity", Icons.AutoMirrored.Filled.ReceiptLong),
    BottomNavItem(Routes.PEOPLE, "People", Icons.Default.People)
)

private val topLevelRoutes = setOf(Routes.HOME, Routes.ACTIVITY, Routes.PEOPLE)

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
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route
    val showBottomBar = currentRoute in topLevelRoutes

    Scaffold(
        modifier = modifier,
        bottomBar = {
            if (showBottomBar) {
                NavigationBar {
                    bottomNavItems.forEach { item ->
                        NavigationBarItem(
                            icon = {
                                if (item.route == Routes.PEOPLE && openPeopleCount > 0) {
                                    BadgedBox(badge = { Badge { Text("$openPeopleCount") } }) {
                                        Icon(item.icon, contentDescription = item.label)
                                    }
                                } else {
                                    Icon(item.icon, contentDescription = item.label)
                                }
                            },
                            label = { Text(item.label) },
                            selected = navBackStackEntry?.destination?.hierarchy?.any {
                                it.route == item.route
                            } == true,
                            onClick = { navController.navigateToTab(item.route) }
                        )
                    }
                }
            }
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Routes.HOME,
            modifier = Modifier.padding(innerPadding)
        ) {
            composable(Routes.HOME) { entry ->
                val message by entry.savedStateHandle.getStateFlow<String?>(PAYMENT_MESSAGE, null)
                    .collectAsStateWithLifecycle()
                HomeScreen(
                    onOpenActivity = { navController.navigateToTab(Routes.ACTIVITY) },
                    onAddPayment = { navController.navigate(Routes.PAYMENT_NEW) { launchSingleTop = true } },
                    onEditPayment = { id -> navController.navigate(Routes.paymentEdit(id)) { launchSingleTop = true } },
                    onOpenSettings = { navController.navigate(Routes.SETTINGS) { launchSingleTop = true } },
                    message = message,
                    onMessageShown = { entry.savedStateHandle[PAYMENT_MESSAGE] = null }
                )
            }
            composable(Routes.ACTIVITY) { entry ->
                val message by entry.savedStateHandle.getStateFlow<String?>(PAYMENT_MESSAGE, null)
                    .collectAsStateWithLifecycle()
                ActivityScreen(
                    onAddPayment = { navController.navigate(Routes.PAYMENT_NEW) { launchSingleTop = true } },
                    onEditPayment = { id -> navController.navigate(Routes.paymentEdit(id)) { launchSingleTop = true } },
                    message = message,
                    onMessageShown = { entry.savedStateHandle[PAYMENT_MESSAGE] = null }
                )
            }
            composable(Routes.PEOPLE) {
                PeopleScreen(
                    onOpenPerson = { id -> navController.navigate(Routes.person(id)) },
                    onOpenSplit = { id -> navController.navigate(Routes.splitEdit(id)) },
                    onSplitBill = { navController.navigate(Routes.splitNew(null)) }
                )
            }
            composable(
                route = Routes.PERSON,
                arguments = listOf(navArgument("personId") { type = NavType.StringType })
            ) { entry ->
                PersonScreen(
                    personId = entry.arguments?.getString("personId").orEmpty(),
                    onBack = { navController.popBackStack() },
                    onOpenSplit = { id -> navController.navigate(Routes.splitEdit(id)) }
                )
            }
            composable(
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
            composable(
                route = Routes.SPLIT_EDIT,
                arguments = listOf(navArgument("billId") { type = NavType.StringType })
            ) {
                SplitEditorScreen(onBack = { navController.popBackStack() })
            }
            composable(Routes.PAYMENT_NEW) { entry ->
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
            composable(
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
            composable(Routes.SETTINGS) {
                SettingsScreen(
                    onBack = { navController.popBackStack() },
                    onOpenNotificationDebug = {
                        navController.navigate(Routes.NOTIFICATION_DEBUG)
                    }
                )
            }
            composable(Routes.NOTIFICATION_DEBUG) {
                NotificationDebugScreen(onBack = { navController.popBackStack() })
            }
        }
    }
}
