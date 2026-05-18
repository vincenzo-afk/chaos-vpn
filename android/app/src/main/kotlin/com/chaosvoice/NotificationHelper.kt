package com.chaosvoice

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * Manages persistent foreground notification for ChaosVoice.
 */
object NotificationHelper {
    private const val CHANNEL_ID = "chaosvoice_channel"
    private const val NOTIFICATION_ID = 1001

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ChaosVoice Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "ChaosVoice is running and modifying your microphone"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    fun buildNotification(context: Context, isActive: Boolean): Notification {
        val stopIntent = Intent(context, VirtualMicService::class.java).apply {
            action = "STOP"
        }
        val stopPending = PendingIntent.getService(
            context, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val openIntent = Intent(context, MainActivity::class.java)
        val openPending = PendingIntent.getActivity(
            context, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(if (isActive) "☠️ ChaosVoice is ACTIVE" else "☠️ ChaosVoice")
            .setContentText(
                if (isActive) "Your voice is being chaotically transformed"
                else "Tap to open ChaosVoice"
            )
            .setSmallIcon(R.drawable.ic_mic_chaos)
            .setOngoing(isActive)
            .setContentIntent(openPending)
            .addAction(
                android.R.drawable.ic_media_pause,
                if (isActive) "Stop" else "Start",
                stopPending
            )
            .build()
    }
}
