package com.expensetracker.app.data

import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS categories (
                id TEXT NOT NULL PRIMARY KEY,
                name TEXT NOT NULL,
                colorHex TEXT NOT NULL,
                isDefault INTEGER NOT NULL DEFAULT 0
            )
            """.trimIndent()
        )
        db.execSQL("ALTER TABLE expenses ADD COLUMN categoryId TEXT")
        db.execSQL("ALTER TABLE expenses ADD COLUMN notes TEXT")

        DefaultCategories.all.forEach { category ->
            db.execSQL(
                "INSERT OR IGNORE INTO categories (id, name, colorHex, isDefault) VALUES (?, ?, ?, ?)",
                arrayOf(category.id, category.name, category.colorHex, if (category.isDefault) 1 else 0)
            )
        }
    }
}

val MIGRATION_2_3 = object : Migration(2, 3) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            "ALTER TABLE expenses ADD COLUMN transactionType TEXT NOT NULL DEFAULT 'WITHDRAW'"
        )
    }
}

val MIGRATION_3_4 = object : Migration(3, 4) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS merchant_category_map (
                merchantKey TEXT NOT NULL PRIMARY KEY,
                displayName TEXT NOT NULL,
                categoryId TEXT NOT NULL,
                updatedAt INTEGER NOT NULL
            )
            """.trimIndent()
        )
    }
}

val MIGRATION_4_5 = object : Migration(4, 5) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            """
            DELETE FROM expenses
            WHERE rowid NOT IN (
                SELECT MIN(rowid) FROM expenses GROUP BY dedupKey
            )
            """.trimIndent()
        )
        db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS index_expenses_dedupKey ON expenses(dedupKey)")
    }
}
