package com.expensetracker.app.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface MerchantCategoryDao {
    @Query("SELECT * FROM merchant_category_map WHERE merchantKey = :key LIMIT 1")
    suspend fun getByKey(key: String): MerchantCategoryEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(mapping: MerchantCategoryEntity)
}
