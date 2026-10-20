package com.expensetracker.app.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow
import java.math.BigDecimal

/** An open debt with the names the debts screen shows. */
data class OpenDebtRow(
    val debtId: String,
    val billId: String,
    val personId: String,
    val personName: String,
    val merchant: String?,
    val billTime: Long,
    val amount: BigDecimal
)

@Dao
interface SplitDao {
    @Query("SELECT * FROM split_bills ORDER BY billTime DESC")
    fun observeBills(): Flow<List<SplitBillEntity>>

    @Query("SELECT * FROM split_bills WHERE id = :billId")
    suspend fun getBill(billId: String): SplitBillEntity?

    @Query("SELECT * FROM split_bills WHERE linkedExpenseId = :expenseId LIMIT 1")
    suspend fun getBillByLinkedExpense(expenseId: String): SplitBillEntity?

    @Query("SELECT * FROM split_items WHERE billId = :billId ORDER BY position")
    suspend fun getItems(billId: String): List<SplitItemEntity>

    @Query(
        """
        SELECT s.* FROM split_item_shares s
        JOIN split_items i ON i.id = s.itemId
        WHERE i.billId = :billId
        """
    )
    suspend fun getShares(billId: String): List<SplitItemShareEntity>

    @Query("SELECT * FROM split_debts WHERE billId = :billId")
    suspend fun getDebts(billId: String): List<SplitDebtEntity>

    @Query("SELECT * FROM split_debts WHERE repaymentExpenseId = :expenseId")
    suspend fun getDebtsByRepayment(expenseId: String): List<SplitDebtEntity>

    @Query("SELECT * FROM split_debts WHERE id = :debtId")
    suspend fun getDebt(debtId: String): SplitDebtEntity?

    @Query(
        """
        SELECT d.id AS debtId, d.billId AS billId, d.personId AS personId,
               p.name AS personName, b.merchant AS merchant, b.billTime AS billTime,
               d.amount AS amount
        FROM split_debts d
        JOIN split_people p ON p.id = d.personId
        JOIN split_bills b ON b.id = d.billId
        WHERE d.status = 'OPEN'
        ORDER BY b.billTime ASC
        """
    )
    fun observeOpenDebts(): Flow<List<OpenDebtRow>>

    @Query("SELECT * FROM split_debts WHERE status = 'OPEN'")
    suspend fun getOpenDebts(): List<SplitDebtEntity>

    @Query("SELECT * FROM split_people WHERE archived = 0 ORDER BY lastUsedAt DESC")
    fun observePeople(): Flow<List<SplitPersonEntity>>

    @Query("SELECT * FROM split_people WHERE archived = 0 ORDER BY lastUsedAt DESC")
    suspend fun getPeople(): List<SplitPersonEntity>

    @Query("SELECT * FROM split_people")
    suspend fun getAllPeopleIncludingArchived(): List<SplitPersonEntity>

    @Query("SELECT * FROM split_people WHERE archived = 0 ORDER BY name COLLATE NOCASE")
    fun observeAllPeople(): Flow<List<SplitPersonEntity>>

    @Query("SELECT * FROM split_people WHERE id = :id")
    suspend fun getPerson(id: String): SplitPersonEntity?

    @Query("SELECT * FROM split_people WHERE id = :id")
    fun observePerson(id: String): Flow<SplitPersonEntity?>

    @Query(
        """
        SELECT d.id AS debtId, d.billId AS billId, d.personId AS personId,
               p.name AS personName, b.merchant AS merchant, b.billTime AS billTime,
               d.amount AS amount
        FROM split_debts d
        JOIN split_people p ON p.id = d.personId
        JOIN split_bills b ON b.id = d.billId
        WHERE d.status = 'OPEN' AND d.personId = :personId
        ORDER BY b.billTime ASC
        """
    )
    fun observeOpenDebtsFor(personId: String): Flow<List<OpenDebtRow>>

    @Query("SELECT * FROM split_debts WHERE status = 'OPEN' AND personId = :personId")
    suspend fun getOpenDebtsFor(personId: String): List<SplitDebtEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertOwedItem(item: OwedItemEntity)

    @Update
    suspend fun updateOwedItem(item: OwedItemEntity)

    @Query("DELETE FROM owed_items WHERE id = :id")
    suspend fun deleteOwedItem(id: String)

    @Query("SELECT * FROM owed_items WHERE id = :id")
    suspend fun getOwedItem(id: String): OwedItemEntity?

    @Query("SELECT * FROM owed_items WHERE personId = :personId AND status = 'OPEN' ORDER BY itemDate")
    fun observeOwedItems(personId: String): Flow<List<OwedItemEntity>>

    @Query("SELECT * FROM owed_items WHERE personId = :personId AND status = 'OPEN'")
    suspend fun getOpenOwedItems(personId: String): List<OwedItemEntity>

    @Query("SELECT * FROM owed_items WHERE status = 'OPEN'")
    fun observeAllOpenOwedItems(): Flow<List<OwedItemEntity>>

    @Query("DELETE FROM owed_items WHERE personId = :personId AND status = 'PAID'")
    suspend fun deletePaidOwedItems(personId: String)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertBill(bill: SplitBillEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertItems(items: List<SplitItemEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertShares(shares: List<SplitItemShareEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDebts(debts: List<SplitDebtEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertPerson(person: SplitPersonEntity)

    @Update
    suspend fun updateDebt(debt: SplitDebtEntity)

    @Query("DELETE FROM split_item_shares WHERE itemId IN (SELECT id FROM split_items WHERE billId = :billId)")
    suspend fun deleteSharesByBill(billId: String)

    @Query("DELETE FROM split_items WHERE billId = :billId")
    suspend fun deleteItemsByBill(billId: String)

    @Query("DELETE FROM split_debts WHERE billId = :billId")
    suspend fun deleteDebtsByBill(billId: String)

    @Query("DELETE FROM split_bills WHERE id = :billId")
    suspend fun deleteBill(billId: String)
}
