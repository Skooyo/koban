package com.expensetracker.app.di

import com.expensetracker.app.data.ExpenseRepository
import com.expensetracker.app.data.SettingsRepository
import com.expensetracker.app.parser.ExpenseNotificationParser
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

@EntryPoint
@InstallIn(SingletonComponent::class)
interface NotificationListenerEntryPoint {
    fun expenseRepository(): ExpenseRepository
    fun settingsRepository(): SettingsRepository
    fun expenseNotificationParser(): ExpenseNotificationParser
}
