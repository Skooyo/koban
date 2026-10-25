package com.expensetracker.app.di

import com.expensetracker.app.data.ExpenseRepository
import com.expensetracker.app.data.MerchantCategoryRepository
import com.expensetracker.app.data.PendingPaymentRepository
import com.expensetracker.app.data.SettingsRepository
import com.expensetracker.app.parser.GeminiClient
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

@EntryPoint
@InstallIn(SingletonComponent::class)
interface NotificationListenerEntryPoint {
    fun expenseRepository(): ExpenseRepository
    fun pendingPaymentRepository(): PendingPaymentRepository
    fun settingsRepository(): SettingsRepository
    fun geminiClient(): GeminiClient
    fun merchantCategoryRepository(): MerchantCategoryRepository
}
