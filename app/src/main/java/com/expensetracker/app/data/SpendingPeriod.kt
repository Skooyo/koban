package com.expensetracker.app.data

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

enum class SpendingPeriod {
    DAY,
    WEEK,
    MONTH
}

object PeriodCalculator {
    private val dayLabelFormat = SimpleDateFormat("EEE, d MMM yyyy", Locale.getDefault())
    private val shortDateFormat = SimpleDateFormat("d MMM", Locale.getDefault())
    private val monthYearFormat = SimpleDateFormat("MMMM yyyy", Locale.getDefault())

    fun range(period: SpendingPeriod, anchor: Calendar = Calendar.getInstance()): Pair<Long, Long> {
        val start = startOfDay(anchor.clone() as Calendar)

        when (period) {
            SpendingPeriod.DAY -> Unit
            SpendingPeriod.WEEK -> alignToMonday(start)
            SpendingPeriod.MONTH -> start.set(Calendar.DAY_OF_MONTH, 1)
        }

        val end = start.clone() as Calendar
        when (period) {
            SpendingPeriod.DAY -> end.add(Calendar.DAY_OF_YEAR, 1)
            SpendingPeriod.WEEK -> end.add(Calendar.DAY_OF_YEAR, 7)
            SpendingPeriod.MONTH -> end.add(Calendar.MONTH, 1)
        }
        return start.timeInMillis to end.timeInMillis
    }

    fun rangeForMonth(year: Int, month: Int): Pair<Long, Long> {
        val start = Calendar.getInstance().apply {
            set(Calendar.YEAR, year)
            set(Calendar.MONTH, month)
            set(Calendar.DAY_OF_MONTH, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val end = start.clone() as Calendar
        end.add(Calendar.MONTH, 1)
        return start.timeInMillis to end.timeInMillis
    }

    fun weeksInMonth(year: Int, month: Int): List<Pair<Long, Long>> {
        val (monthStart, monthEnd) = rangeForMonth(year, month)
        val weeks = mutableListOf<Pair<Long, Long>>()
        val cursor = Calendar.getInstance().apply { timeInMillis = monthStart }
        alignToMonday(cursor)

        while (cursor.timeInMillis < monthEnd) {
            val weekStart = cursor.timeInMillis
            val weekEndCal = cursor.clone() as Calendar
            weekEndCal.add(Calendar.DAY_OF_YEAR, 7)
            if (weekEndCal.timeInMillis > monthStart && weekStart < monthEnd) {
                weeks.add(weekStart to weekEndCal.timeInMillis)
            }
            cursor.add(Calendar.DAY_OF_YEAR, 7)
        }
        return weeks
    }

    fun weekLabel(startMs: Long, endMs: Long): String {
        return "Mon ${shortDateFormat.format(startMs)} – Sun ${shortDateFormat.format(endMs - 1)}"
    }

    fun monthLabel(year: Int, month: Int): String {
        val cal = Calendar.getInstance().apply {
            set(Calendar.YEAR, year)
            set(Calendar.MONTH, month)
            set(Calendar.DAY_OF_MONTH, 1)
        }
        return monthYearFormat.format(cal.time)
    }

    fun title(period: SpendingPeriod): String = when (period) {
        SpendingPeriod.DAY -> "Today"
        SpendingPeriod.WEEK -> "This week"
        SpendingPeriod.MONTH -> "This month"
    }

    fun label(period: SpendingPeriod, anchor: Calendar = Calendar.getInstance()): String {
        return when (period) {
            SpendingPeriod.DAY -> dayLabelFormat.format(anchor.time)
            SpendingPeriod.WEEK -> {
                val (startMs, endMs) = range(SpendingPeriod.WEEK, anchor)
                weekLabel(startMs, endMs)
            }
            SpendingPeriod.MONTH -> monthYearFormat.format(anchor.time)
        }
    }

    fun decodeYearMonth(yearMonth: Int): Pair<Int, Int> {
        val year = yearMonth / 100
        val month = yearMonth % 100 - 1
        return year to month
    }

    private fun startOfDay(cal: Calendar): Calendar {
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal
    }

    private fun alignToMonday(cal: Calendar) {
        val dayOfWeek = cal.get(Calendar.DAY_OF_WEEK)
        val daysSinceMonday = (dayOfWeek - Calendar.MONDAY + 7) % 7
        cal.add(Calendar.DAY_OF_YEAR, -daysSinceMonday)
    }
}
