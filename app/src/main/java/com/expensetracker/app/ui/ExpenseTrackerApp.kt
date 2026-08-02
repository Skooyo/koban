package com.expensetracker.app.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.ui.theme.ExpenseTrackerTheme
import com.expensetracker.app.ui.viewmodel.AppViewModel

@Composable
fun ExpenseTrackerApp(modifier: Modifier = Modifier) {
    val appViewModel: AppViewModel = hiltViewModel()
    val darkMode by appViewModel.darkModeEnabled.collectAsStateWithLifecycle(initialValue = true)

    ExpenseTrackerTheme(darkTheme = darkMode) {
        ExpenseTrackerNavHost(modifier = modifier)
    }
}
