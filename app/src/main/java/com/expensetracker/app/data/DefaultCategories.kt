package com.expensetracker.app.data

object DefaultCategories {
    val all = listOf(
        CategoryEntity("food", "Food & Dining", "#E53935", isDefault = true),
        CategoryEntity("transport", "Transport", "#1E88E5", isDefault = true),
        CategoryEntity("shopping", "Shopping", "#8E24AA", isDefault = true),
        CategoryEntity("bills", "Bills & Utilities", "#FB8C00", isDefault = true),
        CategoryEntity("entertainment", "Entertainment", "#43A047", isDefault = true),
        CategoryEntity("health", "Health", "#00ACC1", isDefault = true),
        CategoryEntity("other", "Other", "#757575", isDefault = true)
    )

    const val UNCATEGORIZED_NAME = "Uncategorized"
    const val UNCATEGORIZED_COLOR = "#9E9E9E"
}
