package com.expensetracker.app.data

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverters

@Database(
    entities = [
        ExpenseEntity::class,
        CategoryEntity::class,
        MerchantCategoryEntity::class
    ],
    version = 5,
    exportSchema = false
)
@TypeConverters(
    BigDecimalConverters::class,
    ExpenseStatusConverter::class,
    ParseConfidenceConverter::class,
    TransactionTypeConverter::class
)
abstract class ExpenseDatabase : RoomDatabase() {
    abstract fun expenseDao(): ExpenseDao
    abstract fun categoryDao(): CategoryDao
    abstract fun merchantCategoryDao(): MerchantCategoryDao
}
