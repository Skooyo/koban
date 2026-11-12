package com.expensetracker.app.di

import android.content.Context
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import com.expensetracker.app.BuildConfig
import com.expensetracker.app.data.ExpenseDao
import com.expensetracker.app.data.ExpenseDatabase
import com.expensetracker.app.data.MIGRATION_1_2
import com.expensetracker.app.data.MIGRATION_2_3
import com.expensetracker.app.data.MIGRATION_3_4
import com.expensetracker.app.data.MIGRATION_4_5
import com.expensetracker.app.data.MIGRATION_5_6
import com.expensetracker.app.data.MIGRATION_6_7
import com.expensetracker.app.data.MIGRATION_7_8
import com.expensetracker.app.data.MIGRATION_8_9
import com.expensetracker.app.data.MIGRATION_9_10
import com.expensetracker.app.data.MIGRATION_10_11
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit
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
            .addMigrations(MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4, MIGRATION_4_5, MIGRATION_5_6, MIGRATION_6_7, MIGRATION_7_8, MIGRATION_8_9, MIGRATION_9_10, MIGRATION_10_11)
            .addCallback(object : RoomDatabase.Callback() {
                // ponytail: one-time fix for the import from com.expensetracker.app; delete after every friend installs the new app ID.
                override fun onOpen(db: SupportSQLiteDatabase) {
                    db.execSQL(
                        "UPDATE split_people SET qrPath = REPLACE(qrPath, '/com.expensetracker.app/', '/' || ? || '/') " +
                            "WHERE qrPath LIKE '%/com.expensetracker.app/%'",
                        arrayOf<Any?>(BuildConfig.APPLICATION_ID)
                    )
                }
            })
            .build()
    }

    @Provides
    fun provideExpenseDao(database: ExpenseDatabase): ExpenseDao = database.expenseDao()

    @Provides
    fun provideCategoryDao(database: ExpenseDatabase) = database.categoryDao()

    @Provides
    fun provideMerchantCategoryDao(database: ExpenseDatabase) = database.merchantCategoryDao()

    @Provides
    fun provideSplitDao(database: ExpenseDatabase) = database.splitDao()

    @Provides
    fun providePendingPaymentDao(database: ExpenseDatabase) = database.pendingPaymentDao()

    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient =
        OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(18, TimeUnit.SECONDS)
            .writeTimeout(15, TimeUnit.SECONDS)
            .callTimeout(20, TimeUnit.SECONDS)
            .build()
}
