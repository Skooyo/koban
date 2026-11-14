package com.expensetracker.app.listener

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/** One notification that waits for the Dart engine to parse it. */
data class QueuedNotification(
    val id: Long = 0,
    val logId: String,
    val packageName: String,
    val title: String?,
    val text: String,
    val postTime: Long,
    val notificationKey: String?,
    val attempts: Int = 0,
)

/** Persistent queue. A row stays on disk until the engine commits it or a final skip is decided. */
class CaptureQueue internal constructor(context: Context, name: String = "capture_queue.db") :
    SQLiteOpenHelper(context.applicationContext, name, null, 1) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            "CREATE TABLE queue(id INTEGER PRIMARY KEY AUTOINCREMENT, logId TEXT NOT NULL, " +
                "packageName TEXT NOT NULL, title TEXT, text TEXT NOT NULL, postTime INTEGER NOT NULL, " +
                "notificationKey TEXT, uniqueKey TEXT NOT NULL UNIQUE, attempts INTEGER NOT NULL DEFAULT 0)",
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit

    /** Returns false when the same post is already in the queue. */
    fun add(item: QueuedNotification): Boolean {
        val values = ContentValues().apply {
            put("logId", item.logId)
            put("packageName", item.packageName)
            put("title", item.title)
            put("text", item.text)
            put("postTime", item.postTime)
            put("notificationKey", item.notificationKey)
            put("uniqueKey", "${item.notificationKey ?: item.packageName}|${item.postTime}|${item.text.hashCode()}")
            put("attempts", item.attempts)
        }
        return writableDatabase.insertWithOnConflict("queue", null, values, SQLiteDatabase.CONFLICT_IGNORE) != -1L
    }

    /** Returns rows with id above [afterId], oldest first. Adds 1 to the attempts of each row.
     * The default limit is 1, so a row that kills the process does not use the tries of other rows. */
    fun take(afterId: Long, limit: Int = 1): List<QueuedNotification> {
        val db = writableDatabase
        val rows = mutableListOf<QueuedNotification>()
        db.beginTransaction()
        try {
            db.query("queue", null, "id > ?", arrayOf(afterId.toString()), null, null, "id ASC", limit.toString()).use { c ->
                while (c.moveToNext()) {
                    rows += QueuedNotification(
                        id = c.getLong(c.getColumnIndexOrThrow("id")),
                        logId = c.getString(c.getColumnIndexOrThrow("logId")),
                        packageName = c.getString(c.getColumnIndexOrThrow("packageName")),
                        title = c.getString(c.getColumnIndexOrThrow("title")),
                        text = c.getString(c.getColumnIndexOrThrow("text")),
                        postTime = c.getLong(c.getColumnIndexOrThrow("postTime")),
                        notificationKey = c.getString(c.getColumnIndexOrThrow("notificationKey")),
                        attempts = c.getInt(c.getColumnIndexOrThrow("attempts")) + 1,
                    )
                }
            }
            for (r in rows) {
                db.execSQL("UPDATE queue SET attempts = attempts + 1 WHERE id = ?", arrayOf<Any>(r.id))
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
        return rows
    }

    /** Removes and returns the rows that reached [MAX_ATTEMPTS]. */
    fun giveUp(): List<QueuedNotification> {
        val db = writableDatabase
        val rows = mutableListOf<QueuedNotification>()
        db.beginTransaction()
        try {
            db.query("queue", null, "attempts >= ?", arrayOf(MAX_ATTEMPTS.toString()), null, null, "id ASC").use { c ->
                while (c.moveToNext()) {
                    rows += QueuedNotification(
                        id = c.getLong(c.getColumnIndexOrThrow("id")),
                        logId = c.getString(c.getColumnIndexOrThrow("logId")),
                        packageName = c.getString(c.getColumnIndexOrThrow("packageName")),
                        title = c.getString(c.getColumnIndexOrThrow("title")),
                        text = c.getString(c.getColumnIndexOrThrow("text")),
                        postTime = c.getLong(c.getColumnIndexOrThrow("postTime")),
                        notificationKey = c.getString(c.getColumnIndexOrThrow("notificationKey")),
                        attempts = c.getInt(c.getColumnIndexOrThrow("attempts")),
                    )
                }
            }
            db.delete("queue", "attempts >= ?", arrayOf(MAX_ATTEMPTS.toString()))
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
        return rows
    }

    fun remove(id: Long) {
        writableDatabase.delete("queue", "id = ?", arrayOf(id.toString()))
    }

    fun size(): Int =
        readableDatabase.rawQuery("SELECT COUNT(*) FROM queue", null).use { it.moveToFirst(); it.getInt(0) }

    companion object {
        const val MAX_ATTEMPTS = 5

        @Volatile private var instance: CaptureQueue? = null

        fun get(context: Context): CaptureQueue =
            instance ?: synchronized(this) { instance ?: CaptureQueue(context).also { instance = it } }
    }
}
