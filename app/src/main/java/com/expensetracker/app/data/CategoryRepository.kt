package com.expensetracker.app.data

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.runBlocking
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class CategoryRepository @Inject constructor(
    private val categoryDao: CategoryDao
) {
    init {
        runBlocking { seedIfEmpty() }
    }

    fun observeAll(): Flow<List<CategoryEntity>> = categoryDao.observeAll()

    suspend fun seedIfEmpty() {
        if (categoryDao.count() == 0) {
            categoryDao.insertAll(DefaultCategories.all)
        }
    }

    suspend fun addCategory(name: String, colorHex: String) {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return
        categoryDao.insert(
            CategoryEntity(
                id = UUID.randomUUID().toString(),
                name = trimmed,
                colorHex = colorHex,
                isDefault = false
            )
        )
    }

    suspend fun deleteCategory(id: String): Boolean {
        return categoryDao.deleteCustom(id) > 0
    }

    suspend fun getById(id: String?): CategoryEntity? {
        if (id == null) return null
        return categoryDao.getById(id)
    }

    suspend fun resolveName(categoryId: String?): String {
        if (categoryId == null) return DefaultCategories.UNCATEGORIZED_NAME
        return categoryDao.getById(categoryId)?.name ?: DefaultCategories.UNCATEGORIZED_NAME
    }

    suspend fun resolveColor(categoryId: String?): String {
        if (categoryId == null) return DefaultCategories.UNCATEGORIZED_COLOR
        return categoryDao.getById(categoryId)?.colorHex ?: DefaultCategories.UNCATEGORIZED_COLOR
    }
}
