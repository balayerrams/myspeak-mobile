
package com.balayerrams.myspeak

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.speech.tts.TextToSpeech
import android.util.Log
import java.util.Locale
import android.os.Bundle
import android.speech.tts.UtteranceProgressListener
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.ServiceInfo
import android.os.Build

class ReminderSpeechService : Service(),
    TextToSpeech.OnInitListener {

    private var textToSpeech: TextToSpeech? = null
    private var reminderMessage = "Time to take your medicine"
    private var ttsReady = false
    private var announcementCount = 1
    private var currentIteration = 0
    private var reminderLanguage = "English"

    private val repeatHandler = android.os.Handler(
        android.os.Looper.getMainLooper()
    )

    override fun onCreate() {
            super.onCreate()
        }

    override fun onStartCommand(intent: Intent?,flags: Int,startId: Int): Int {

    startReminderForeground()

    reminderMessage = intent?.getStringExtra("message") ?: "Time to take your medicine"

    announcementCount = intent ?.getIntExtra("announcementCount", 1) ?.coerceIn(1, 4) ?: 1
    reminderLanguage = intent?.getStringExtra("language") ?: "English"

    currentIteration = 0

    if (textToSpeech == null) {
        textToSpeech = TextToSpeech(this, this)
    }


    Log.i(
        "MySpeakTTS",
        "Announcement iterations requested: $announcementCount"
    )

    if (ttsReady) {
        speakReminder()
    }

    return START_NOT_STICKY
}

    override fun onInit(status: Int) {
    if (status == TextToSpeech.SUCCESS) {

        val languageCode = when (reminderLanguage) {
        "Telugu" -> "te-IN"
        "Hindi" -> "hi-IN"
        else -> "en-IN"
        }

        val result = textToSpeech?.setLanguage(
            Locale.forLanguageTag(languageCode)
        )

        if (result == TextToSpeech.LANG_MISSING_DATA ||
            result == TextToSpeech.LANG_NOT_SUPPORTED
        ) {
            Log.e(
                "MySpeakTTS",
                "Voice unavailable for $reminderLanguage ($languageCode)"
            )
            stopSelf()
            return
        }

        Log.i(
            "MySpeakTTS",
            "Selected voice language: $reminderLanguage ($languageCode)"
        )

        ttsReady = true

        textToSpeech?.setOnUtteranceProgressListener(
            object : UtteranceProgressListener() {

                override fun onStart(utteranceId: String?) {
                    Log.i("MySpeakTTS", "Speech started")
                }

                override fun onDone(utteranceId: String?) {

                    Log.i(
                        "MySpeakTTS",
                        "Speech completed: iteration $currentIteration of $announcementCount"
                    )

                    if (currentIteration < announcementCount) {

                        repeatHandler.postDelayed(
                        {
                            if (ttsReady) {
                                speakReminder()
                            }
                        },
                        2000L
                    )

                    } else {

                        Log.i(
                            "MySpeakTTS",
                            "All $announcementCount announcements completed"
                        )

                        stopSelf()
                    }
                }

                override fun onError(utteranceId: String?) {
                    Log.e("MySpeakTTS", "Speech failed")
                    stopSelf()
                }
            }
        )

        Log.i("MySpeakTTS", "TTS initialized successfully")

        speakReminder()

    } else {
        Log.e("MySpeakTTS", "TTS initialization failed")
        stopSelf()
    }
}

    private fun speakReminder() {

    currentIteration++

    Log.i("MySpeakTTS","Playing announcement $currentIteration of $announcementCount")

    Log.i("MySpeakTTS", "Speaking: $reminderMessage")

    val result = textToSpeech?.speak(
        reminderMessage,
        TextToSpeech.QUEUE_FLUSH,
        Bundle(),
        "myspeak_reminder"
    )

    if (result == TextToSpeech.ERROR) {
        Log.e("MySpeakTTS", "Unable to start speech")
        stopSelf()
    }
}

private fun startReminderForeground() {

    val channelId = "myspeak_voice_reminders"

    val notificationManager =
        getSystemService(NotificationManager::class.java)

    val channel = NotificationChannel(
        channelId,
        "MySpeak Voice Reminders",
        NotificationManager.IMPORTANCE_LOW
    )

    notificationManager.createNotificationChannel(channel)

    val notification = Notification.Builder(this, channelId)
        .setContentTitle("MySpeak Reminder")
        .setContentText("Playing your scheduled reminder")
        .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
        .setOngoing(true)
        .build()

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        startForeground(
            1001,
            notification,
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
        )
    } else {
        startForeground(1001, notification)
    }
}

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
    repeatHandler.removeCallbacksAndMessages(null)
    textToSpeech?.stop()
    textToSpeech?.shutdown()
    super.onDestroy()
    }
}

