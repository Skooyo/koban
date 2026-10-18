package com.expensetracker.app.data

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverters

@Database(
    entities = [
        ExpenseEntity::class,
        CategoryEntity::class,
        MerchantCategoryEntity::class,
        SplitBillEntity::class,
        SplitItemEntity::class,
        SplitPersonEntity::class,
        SplitItemShareEntity::class,
        SplitDebtEntity::class
    ],
    version = 6,
    exportSchema = false
)
@TypeConverters(
    BigDecimalConverters::class,
    ExpenseStatusConverter::class,
    ParseConfidenceConverter::class,
    TransactionTypeConverter::class,
    DebtStatusConverter::class
)
abstract class ExpenseDatabase : RoomDatabase() {
    abstract fun expenseDao(): ExpenseDao
    abstract fun categoryDao(): CategoryDao
    abstract fun merchantCategoryDao(): MerchantCategoryDao
    abstract fun splitDao(): SplitDao
}
