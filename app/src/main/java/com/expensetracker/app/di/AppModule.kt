package com.expensetracker.app.di

import android.content.Context
import androidx.room.Room
import com.expensetracker.app.data.ExpenseDao
import com.expensetracker.app.data.ExpenseDatabase
import com.expensetracker.app.data.MIGRATION_1_2
import com.expensetracker.app.data.MIGRATION_2_3
import com.expensetracker.app.data.MIGRATION_3_4
import com.expensetracker.app.data.MIGRATION_4_5
import com.expensetracker.app.parser.OpenRouterClient
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): ExpenseDatabase {
        return Room.databaseBuilder(
            context,
            ExpenseDatabase::class.java,
            "expense_tracker.db"
        )
            .addMigrations(MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4, MIGRATION_4_5)
            .build()
    }

    @Provides
    fun provideExpenseDao(database: ExpenseDatabase): ExpenseDao = database.expenseDao()

    @Provides
    fun provideCategoryDao(database: ExpenseDatabase) = database.categoryDao()

    @Provides
    fun provideMerchantCategoryDao(database: ExpenseDatabase) = database.merchantCategoryDao()

    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient = OpenRouterClient.createDefaultHttpClient()
}
