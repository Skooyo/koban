package com.expensetracker.app.data

import androidx.room.TypeConverter
import com.expensetracker.app.parser.AmountFormatter
import java.math.BigDecimal

class BigDecimalConverters {
    @TypeConverter
    fun fromBigDecimal(value: BigDecimal?): String? =
        value?.let { AmountFormatter.toMoney(it).toPlainString() }

    @TypeConverter
    fun toBigDecimal(value: String?): BigDecimal? =
        value?.let { AmountFormatter.toMoney(BigDecimal(it)) }
}

class ExpenseStatusConverter {
    @TypeConverter
    fun fromStatus(status: ExpenseStatus): String = status.name

    @TypeConverter
    fun toStatus(value: String): ExpenseStatus = ExpenseStatus.valueOf(value)
}

class ParseConfidenceConverter {
    @TypeConverter
    fun fromConfidence(confidence: ParseConfidence): String = confidence.name

    @TypeConverter
    fun toConfidence(value: String): ParseConfidence = ParseConfidence.valueOf(value)
}

class DebtStatusConverter {
    @TypeConverter
    fun fromStatus(status: DebtStatus): String = status.name

    @TypeConverter
    fun toStatus(value: String): DebtStatus = DebtStatus.valueOf(value)
}

class TransactionTypeConverter {
    @TypeConverter
    fun fromType(type: TransactionType): String = type.name

    @TypeConverter
    fun toType(value: String): TransactionType = TransactionType.valueOf(value)
}
