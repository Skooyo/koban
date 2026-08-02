package com.expensetracker.app.data

import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class MerchantCategoryRepository @Inject constructor(
    private val merchantCategoryDao: MerchantCategoryDao
) {
    fun normalizeKey(merchant: String?): String? {
        val normalized = merchant?.trim()?.lowercase()?.takeIf { it.isNotEmpty() } ?: return null
        return normalized
    }

    suspend fun categoryIdForMerchant(merchant: String?): String? {
        val key = normalizeKey(merchant) ?: return null
        return merchantCategoryDao.getByKey(key)?.categoryId
    }

    suspend fun saveMapping(merchant: String?, categoryId: String?) {
        val key = normalizeKey(merchant) ?: return
        if (categoryId == null) return
        merchantCategoryDao.upsert(
            MerchantCategoryEntity(
                merchantKey = key,
                displayName = merchant!!.trim(),
                categoryId = categoryId,
                updatedAt = System.currentTimeMillis()
            )
        )
    }
}
