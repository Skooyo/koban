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

val MIGRATION_5_6 = object : Migration(5, 6) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE expenses ADD COLUMN countedAmount TEXT")
        db.execSQL("CREATE TABLE IF NOT EXISTS split_bills (id TEXT NOT NULL, merchant TEXT, billTime INTEGER NOT NULL, currency TEXT NOT NULL, printedTotal TEXT, serviceCharge TEXT NOT NULL, tax TEXT NOT NULL, discount TEXT NOT NULL, rounding TEXT NOT NULL, linkedExpenseId TEXT, createdAt INTEGER NOT NULL, PRIMARY KEY(id))")
        db.execSQL("CREATE TABLE IF NOT EXISTS split_items (id TEXT NOT NULL, billId TEXT NOT NULL, name TEXT NOT NULL, quantity INTEGER NOT NULL, price TEXT NOT NULL, position INTEGER NOT NULL, PRIMARY KEY(id))")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_split_items_billId ON split_items (billId)")
        db.execSQL("CREATE TABLE IF NOT EXISTS split_people (id TEXT NOT NULL, name TEXT NOT NULL, lastUsedAt INTEGER NOT NULL, PRIMARY KEY(id))")
        db.execSQL("CREATE TABLE IF NOT EXISTS split_item_shares (itemId TEXT NOT NULL, personId TEXT NOT NULL, PRIMARY KEY(itemId, personId))")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_split_item_shares_personId ON split_item_shares (personId)")
        db.execSQL("CREATE TABLE IF NOT EXISTS split_debts (id TEXT NOT NULL, billId TEXT NOT NULL, personId TEXT NOT NULL, amount TEXT NOT NULL, status TEXT NOT NULL, repaymentExpenseId TEXT, suggestedRepaymentExpenseId TEXT, paidAt INTEGER, PRIMARY KEY(id))")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_split_debts_billId ON split_debts (billId)")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_split_debts_personId ON split_debts (personId)")
    }
}

val MIGRATION_6_7 = object : Migration(6, 7) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE split_people ADD COLUMN qrPath TEXT")
        db.execSQL("ALTER TABLE split_people ADD COLUMN archived INTEGER NOT NULL DEFAULT 0")
        db.execSQL("ALTER TABLE split_people ADD COLUMN suggestedSettleExpenseId TEXT")
        db.execSQL("CREATE TABLE IF NOT EXISTS owed_items (id TEXT NOT NULL, personId TEXT NOT NULL, description TEXT NOT NULL, amount TEXT NOT NULL, itemDate INTEGER NOT NULL, createdAt INTEGER NOT NULL, status TEXT NOT NULL, paidAt INTEGER, PRIMARY KEY(id))")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_owed_items_personId ON owed_items (personId)")
    }
}
