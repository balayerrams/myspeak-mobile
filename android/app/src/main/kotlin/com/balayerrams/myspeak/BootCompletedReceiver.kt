package com.balayerrams.myspeak

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar

class BootCompletedReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        Log.i("MySpeakBoot", "Phone reboot detected")

        val alarmManager =
            context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !alarmManager.canScheduleExactAlarms()
        ) {
            Log.e("MySpeakBoot", "Exact alarm permission unavailable")
            return
        }

        try {
            val reminders = ReminderScheduleStore.getAllReminders(context)
            val ids = reminders.keys()

            var restored = 0

            while (ids.hasNext()) {
                val id = ids.next()
                val reminderId = id.toIntOrNull() ?: continue
                val data = reminders.optJSONObject(id) ?: continue

                val repeat = data.optString("repeat", "Once")

                if (repeat != "Once" &&
                    repeat != "Daily" &&
                    repeat != "Weekdays"
                ) continue

                val hour = data.optInt("hour", -1)
                val minute = data.optInt("minute", -1)

                val now = System.currentTimeMillis()

                val nextTriggerTime: Long

                if (repeat == "Once") {

                    val savedTriggerTime = data.optLong("triggerTime", 0L)

                    if (savedTriggerTime <= now) {
                        Log.i(
                            "MySpeakBoot",
                            "Skipping expired or legacy Once reminder #$reminderId"
                        )
                        continue
                    }

                    nextTriggerTime = savedTriggerTime

                } else {

                    if (hour !in 0..23 || minute !in 0..59) continue

                    val calendar = Calendar.getInstance().apply {
                        set(Calendar.HOUR_OF_DAY, hour)
                        set(Calendar.MINUTE, minute)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                    }

                    if (calendar.timeInMillis <= now) {
                        calendar.add(Calendar.DAY_OF_YEAR, 1)
                    }

                    if (repeat == "Weekdays") {
                        while (
                            calendar.get(Calendar.DAY_OF_WEEK) == Calendar.SATURDAY ||
                            calendar.get(Calendar.DAY_OF_WEEK) == Calendar.SUNDAY
                        ) {
                            calendar.add(Calendar.DAY_OF_YEAR, 1)
                        }
                    }

                    nextTriggerTime = calendar.timeInMillis
                }

                val alarmIntent =
                    Intent(context, ReminderAlarmReceiver::class.java).apply {
                        putExtra("reminderId", reminderId)
                        putExtra("message", data.optString("message"))
                        putExtra("repeat", repeat)
                        putExtra("hour", hour)
                        putExtra("minute", minute)
                        putExtra("announcementCount",data.optInt("announcementCount", 1).coerceIn(1, 4))
                        putExtra("language", data.optString("language", "English"))
                    }

                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    reminderId,
                    alarmIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or
                        PendingIntent.FLAG_IMMUTABLE
                )

                try {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        nextTriggerTime,
                        pendingIntent
                    )

                    restored++

                    Log.i(
                    "MySpeakBoot",
                    "Restored reminder #$reminderId for $nextTriggerTime"
                )
                } catch (e: SecurityException) {
                    Log.e(
                        "MySpeakBoot",
                        "Unable to restore reminder #$reminderId",
                        e
                    )
                }
            }

            Log.i(
                "MySpeakBoot",
                "Restored $restored reminders after reboot"
            )

        } catch (e: Exception) {
            Log.e("MySpeakBoot", "Reminder recovery failed", e)
        }
    }
}
