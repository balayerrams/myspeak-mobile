
package com.balayerrams.myspeak

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.example.myspeak/reminders"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "checkScheduler" -> {
                    result.success("Android scheduling bridge connected")
                }

                "canScheduleExactAlarms" -> {
                    val alarmManager =
                        getSystemService(Context.ALARM_SERVICE) as AlarmManager

                    val allowed =
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                        alarmManager.canScheduleExactAlarms()

                    result.success(allowed)
                }
                
                "openExactAlarmSettings" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        val intent = Intent(
                            Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM
                        ).apply {
                            data = android.net.Uri.parse("package:$packageName")
                        }

                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error(
                            "SETTINGS_ERROR",
                            "Unable to open alarm permission settings",
                            e.message
                        )
                    }
                } else {
                    result.success(true)
                }
            }

                "scheduleTestAlarm" -> {
                    val alarmManager =
                        getSystemService(Context.ALARM_SERVICE) as AlarmManager

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                        !alarmManager.canScheduleExactAlarms()
                    ) {
                        result.error(
                            "PERMISSION_DENIED",
                            "Exact alarm permission is not enabled",
                            null
                        )
                    } else {
                        try {
                            val intent = Intent(
                                this,
                                ReminderAlarmReceiver::class.java
                            ).apply {
                                putExtra(
                                    "message",
                                    "Time to take your medicine"
                                )
                            }

                            val pendingIntent = PendingIntent.getBroadcast(
                                this,
                                1001,
                                intent,
                                PendingIntent.FLAG_UPDATE_CURRENT or
                                    PendingIntent.FLAG_IMMUTABLE
                            )

                            val triggerTime =
                                System.currentTimeMillis() + 2 * 60 * 1000L

                            alarmManager.setExactAndAllowWhileIdle(
                                AlarmManager.RTC_WAKEUP,
                                triggerTime,
                                pendingIntent
                            )

                            result.success(
                                "Test alarm scheduled for 2 minutes from now"
                            )
                        } catch (e: SecurityException) {
                            result.error(
                                "ALARM_SECURITY_ERROR",
                                e.message,
                                null
                            )
                        }
                    }
                }
                
                "scheduleReminder" -> {
                    val message = call.argument<String>("message")
                    val speechMessage: String = call.argument<String>("speechMessage")
                    ?.takeIf { it.isNotBlank() }
                    ?: call.argument<String>("message").orEmpty()
                    val triggerTime = call.argument<Long>("triggerTime")
                    val reminderId = call.argument<Int>("reminderId")

                    if (message.isNullOrBlank() ||
                        triggerTime == null ||
                        reminderId == null ||
                        reminderId < 0
                    ) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "Valid message, triggerTime and reminderId are required",
                            null
                        )
                    } else if (triggerTime <= System.currentTimeMillis()) {
                        result.error(
                            "INVALID_TIME",
                            "Reminder time must be in the future",
                            null
                        )
                    } else {
                        val alarmManager =
                            getSystemService(Context.ALARM_SERVICE) as AlarmManager

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                            !alarmManager.canScheduleExactAlarms()
                        ) {
                            result.error(
                                "PERMISSION_DENIED",
                                "Exact alarm permission is not enabled",
                                null
                            )
                        } else {
                            try {
                                val announcementCount = (call.argument<Int>("announcementCount") ?: 1).coerceIn(1, 4)
                                val language = call.argument<String>("language") ?: "English"
                                val intent = Intent(this, ReminderAlarmReceiver::class.java).apply {
                                    putExtra("message", speechMessage)
                                    putExtra("reminderId", reminderId)
                                    putExtra("repeat", call.argument<String>("repeat") ?: "Once")
                                    putExtra("hour", call.argument<Int>("hour") ?: -1)
                                    putExtra("minute", call.argument<Int>("minute") ?: -1)
                                    putExtra("announcementCount", announcementCount)
                                    putExtra("language", language)
                                }

                                val pendingIntent = PendingIntent.getBroadcast(
                                    this,
                                    reminderId,
                                    intent,
                                    PendingIntent.FLAG_UPDATE_CURRENT or
                                        PendingIntent.FLAG_IMMUTABLE
                                )

                                alarmManager.setExactAndAllowWhileIdle(
                                    AlarmManager.RTC_WAKEUP,
                                    triggerTime,
                                    pendingIntent
                                )

                                ReminderScheduleStore.saveReminder(
                                    context = this,
                                    reminderId = reminderId,
                                    message = speechMessage,
                                    repeat = call.argument<String>("repeat") ?: "Once",
                                    hour = call.argument<Int>("hour") ?: -1,
                                    minute = call.argument<Int>("minute") ?: -1,
                                    announcementCount = announcementCount,
                                    triggerTime = triggerTime,
                                    language = language,
                                )

                                result.success(
                                    "Reminder #$reminderId scheduled successfully"
                                )
                            } catch (e: SecurityException) {
                                result.error(
                                    "ALARM_SECURITY_ERROR",
                                    e.message,
                                    null
                                )
                            }
                        }
                    }
                }
                
                "cancelReminder" -> {
                    val reminderId = call.argument<Int>("reminderId")

                    if (reminderId == null || reminderId < 0) {
                        result.error(
                            "INVALID_REMINDER_ID",
                            "A valid reminder ID is required",
                            null
                        )
                    } else {
                        try {
                            val alarmManager =
                                getSystemService(Context.ALARM_SERVICE) as AlarmManager

                            val intent = Intent(
                                this,
                                ReminderAlarmReceiver::class.java
                            )

                            val pendingIntent = PendingIntent.getBroadcast(
                                this,
                                reminderId,
                                intent,
                                PendingIntent.FLAG_NO_CREATE or
                                    PendingIntent.FLAG_IMMUTABLE
                            )

                           if (pendingIntent != null) {
                                alarmManager.cancel(pendingIntent)
                                pendingIntent.cancel()
                            }

                            // Remove the cancelled reminder from native storage.
                            // Do this even if Android has no pending alarm.
                            ReminderScheduleStore.removeReminder(
                                context = this,
                                reminderId = reminderId
                            )

                        result.success(
                            "Reminder #$reminderId cancelled and removed from native storage"
                        )
                        } catch (e: Exception) {
                            result.error(
                                "CANCEL_FAILED",
                                e.message ?: "Unable to cancel reminder",
                                null
                            )
                        }
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}

