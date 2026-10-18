package com.expensetracker.app.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.expensetracker.app.ui.navigation.Routes
import com.expensetracker.app.ui.screens.DebtsScreen
import com.expensetracker.app.ui.screens.ExpensesScreen
import com.expensetracker.app.ui.screens.FilteredExpensesScreen
import com.expensetracker.app.ui.screens.HistoryMonthsScreen
import com.expensetracker.app.ui.screens.HistoryWeeksScreen
import com.expensetracker.app.ui.screens.HomeScreen
import com.expensetracker.app.ui.screens.NotificationDebugScreen
import com.expensetracker.app.ui.screens.SettingsScreen
import com.expensetracker.app.ui.screens.SplitEditorScreen

private data class BottomNavItem(val route: String, val label: String, val icon: androidx.compose.ui.graphics.vector.ImageVector)

private val bottomNavItems = listOf(
    BottomNavItem(Routes.HOME, "Home", Icons.Default.Home),
    BottomNavItem(Routes.EXPENSES, "Expenses", Icons.Default.List),
    BottomNavItem(Routes.HISTORY, "History", Icons.Default.CalendarMonth),
    BottomNavItem(Routes.SETTINGS, "Settings", Icons.Default.Settings)
)

private val topLevelRoutes = setOf(Routes.HOME, Routes.EXPENSES, Routes.HISTORY, Routes.SETTINGS)

@Composable
fun ExpenseTrackerNavHost(modifier: Modifier = Modifier) {
    val navController = rememberNavController()
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
                            icon = { Icon(item.icon, contentDescription = item.label) },
                            label = { Text(item.label) },
                            selected = navBackStackEntry?.destination?.hierarchy?.any {
                                it.route == item.route
                            } == true,
                            onClick = {
                                navController.navigate(item.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            }
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
            composable(Routes.HOME) {
                HomeScreen(
                    onNavigateToFiltered = { route -> navController.navigate(route) }
                )
            }
            composable(Routes.EXPENSES) {
                ExpensesScreen(
                    onSplit = { id -> navController.navigate(Routes.splitNew(id)) },
                    onDebts = { navController.navigate(Routes.DEBTS) }
                )
            }
            composable(Routes.DEBTS) {
                DebtsScreen(
                    onBack = { navController.popBackStack() },
                    onOpenSplit = { id -> navController.navigate(Routes.splitEdit(id)) }
                )
            }
            composable(Routes.HISTORY) {
                HistoryMonthsScreen(
                    onMonthClick = { yearMonth ->
                        navController.navigate(Routes.historyMonth(yearMonth))
                    }
                )
            }
            composable(
                route = Routes.HISTORY_MONTH,
                arguments = listOf(navArgument("yearMonth") { type = NavType.IntType })
            ) {
                HistoryWeeksScreen(
                    onBack = { navController.popBackStack() },
                    onWeekClick = { start, end, label ->
                        navController.navigate(Routes.expensesFilter(start, end, label))
                    }
                )
            }
            composable(
                route = Routes.EXPENSES_FILTER,
                arguments = listOf(
                    navArgument("start") { type = NavType.StringType },
                    navArgument("end") { type = NavType.StringType },
                    navArgument("title") { type = NavType.StringType }
                )
            ) {
                FilteredExpensesScreen(
                    onBack = { navController.popBackStack() },
                    onSplit = { id -> navController.navigate(Routes.splitNew(id)) }
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
            composable(Routes.SETTINGS) {
                SettingsScreen(
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
