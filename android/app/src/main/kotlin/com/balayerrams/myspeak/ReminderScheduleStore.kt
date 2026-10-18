
package com.balayerrams.myspeak

import android.content.Context
import org.json.JSONObject

object ReminderScheduleStore {

    private const val PREFS_NAME = "myspeak_reminder_schedules"
    private const val KEY_REMINDERS = "reminders"

    fun saveReminder(
        context: Context,
        reminderId: Int,
        message: String,
        repeat: String,
        hour: Int,
        minute: Int,
        announcementCount: Int = 1,
        triggerTime: Long = 0L,
        language: String = "English"
    ) {
        val preferences = context.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        )

        val reminders = JSONObject(
            preferences.getString(KEY_REMINDERS, "{}") ?: "{}"
        )

        val reminder = JSONObject().apply {
            put("message", message)
            put("repeat", repeat)
            put("hour", hour)
            put("minute", minute)
            put("announcementCount", announcementCount.coerceIn(1, 4))
            put("triggerTime", triggerTime)
            put("language", language)
        }

        reminders.put(reminderId.toString(), reminder)

        check(
            preferences.edit()
                .putString(KEY_REMINDERS, reminders.toString())
                .commit()
        ) {
            "Unable to save native reminder schedule"
        }
    }

    fun removeReminder(context: Context, reminderId: Int) {
        val preferences = context.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        )

        val reminders = JSONObject(
            preferences.getString(KEY_REMINDERS, "{}") ?: "{}"
        )

        reminders.remove(reminderId.toString())

        check(
            preferences.edit()
                .putString(KEY_REMINDERS, reminders.toString())
                .commit()
        ) {
            "Unable to remove native reminder schedule"
        }
    }

    fun getAllReminders(context: Context): JSONObject {
        val preferences = context.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        )

        return JSONObject(
            preferences.getString(KEY_REMINDERS, "{}") ?: "{}"
        )
    }
}

