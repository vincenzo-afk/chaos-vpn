package com.chaosvoice

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * ChaosVpnService — "Fake VPN" survival engine.
 *
 * This is NOT a real VPN. It does NOT route real internet traffic.
 * It holds a VpnService foreground service for its survival superpowers:
 *   - Higher process priority (system treats it as critical infrastructure)
 *   - START_NOT_STICKY so Android does NOT restart it after task removal
 *   - onTaskRemoved() guarantees full teardown when the user swipes the app away
 *   - onRevoke() handles system-initiated VPN permission revocation
 *
 * VPN tunnel routes only the private dummy subnet 10.255.255.0/30.
 * No default route is added, so ALL real internet traffic bypasses the tunnel.
 *
 * Lifecycle sequence (start):
 *   startForegroundService → onCreate → onStartCommand("START_VPN") →
 *   startForeground() → establish VPN tunnel → isVpnRunning = true
 *
 * Lifecycle sequence (stop):
 *   any of: stopFakeVpn() / onTaskRemoved() / onRevoke() / onDestroy()
 *   → guard against double-stop → close FD → release wake lock →
 *   stopForeground(REMOVE) → stopSelf()
 */
class ChaosVpnService : VpnService() {

    companion object {
        private const val TAG = "ChaosVpnService"
        private const val NOTIFICATION_ID = 2001
        private const val CHANNEL_ID = "chaos_vpn_channel"

        /** Reflects whether the VPN tunnel is currently established. */
        @Volatile
        var isVpnRunning: Boolean = false
            private set

        fun start(context: Context) {
            Log.i(TAG, "[LIFECYCLE] start() called from ${context.javaClass.simpleName}")
            val intent = Intent(context, ChaosVpnService::class.java).apply {
                action = "START_VPN"
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            Log.i(TAG, "[LIFECYCLE] stop() called from ${context.javaClass.simpleName}")
            val intent = Intent(context, ChaosVpnService::class.java).apply {
                action = "STOP_VPN"
            }
            // startService is safe here even if service isn't running (it's a no-op)
            context.startService(intent)
        }
    }

    // ── State ──────────────────────────────────────────────────────────────────

    private var vpnInterface: ParcelFileDescriptor? = null
    private var wakeLock: PowerManager.WakeLock? = null

    /**
     * Guards against the double-stop loop:
     *   stopFakeVpn() → stopSelf() → onDestroy() → stopFakeVpn() again
     * Set to true immediately when teardown begins; checked at the top of stopFakeVpn().
     */
    @Volatile
    private var isStopping = false

    // ── Service Lifecycle ──────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "[LIFECYCLE] onCreate")
        createNotificationChannel()

        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "ChaosVoice::VpnWakeLock"
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "[LIFECYCLE] onStartCommand action=${intent?.action}")
        when (intent?.action) {
            "START_VPN" -> startFakeVpn()
            "STOP_VPN"  -> stopFakeVpn()
            // null intent = Android restarted us via START_STICKY after being killed.
            // Re-establish the VPN tunnel to keep the survival engine alive.
            null -> {
                Log.i(TAG, "[LIFECYCLE] null intent (START_STICKY restart) — re-establishing VPN")
                startFakeVpn()
            }
        }
        // START_STICKY: Android WILL restart this service after it is killed.
        // This is essential for the "survival engine" — the VPN must auto-recover.
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        // VpnService requires passing through its own binder for the prepare() flow
        return super.onBind(intent)
    }

    /**
     * Called when the USER swipes the app away from recents.
     * This is the primary entry point for app-close cleanup.
     * We stop everything here so the notification disappears immediately.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.i(TAG, "[LIFECYCLE] onTaskRemoved — user closed app, stopping VPN service")
        stopFakeVpn()
        super.onTaskRemoved(rootIntent)
    }

    /**
     * Called when Android revokes the VPN permission (e.g., user enables another VPN).
     * Must stop and clean up here; the notification will persist if we don't.
     */
    override fun onRevoke() {
        Log.i(TAG, "[LIFECYCLE] onRevoke — VPN permission revoked by system")
        stopFakeVpn()
        super.onRevoke()
    }

    /**
     * Called after stopSelf() completes. By the time this is called,
     * stopFakeVpn() has already run (via either explicit call or onTaskRemoved/onRevoke).
     * The isStopping guard ensures no double execution.
     */
    override fun onDestroy() {
        Log.i(TAG, "[LIFECYCLE] onDestroy")
        stopFakeVpn() // safe — isStopping guard prevents double execution
        super.onDestroy()
    }

    // ── VPN Lifecycle ──────────────────────────────────────────────────────────

    private fun startFakeVpn() {
        if (isVpnRunning) {
            Log.d(TAG, "[VPN] Already running, ignoring duplicate start")
            return
        }
        isStopping = false

        // CRITICAL: call startForeground() IMMEDIATELY after onStartCommand returns,
        // otherwise Android will ANR/crash the service on API 26+.
        Log.i(TAG, "[FOREGROUND] Posting foreground notification id=$NOTIFICATION_ID")
        startForeground(NOTIFICATION_ID, buildNotification())

        // Acquire partial wake lock so CPU doesn't sleep while VPN is "active"
        wakeLock?.acquire(4 * 60 * 60 * 1000L)
        Log.d(TAG, "[WAKELOCK] Acquired")

        // Establish the dummy VPN tunnel
        try {
            val builder = Builder()
                .setSession("ChaosVoice")
                // Dummy address in a /30 subnet (only 4 addresses, nothing real uses these)
                .addAddress("10.255.255.2", 30)
                // Route ONLY our dummy /30 subnet — no default route, so real internet is unaffected
                .addRoute("10.255.255.0", 30)
                .setMtu(1500)
                .setBlocking(false) // non-blocking so we never get stuck on reads

            // Exclude our own app from the VPN tunnel — audio routing stays normal
            builder.addDisallowedApplication(packageName)

            Log.i(TAG, "[VPN] Calling Builder.establish()")
            vpnInterface = builder.establish()
            Log.i(TAG, "[VPN] Tunnel established. FD=${vpnInterface?.fd}, internet unaffected")

            isVpnRunning = true
        } catch (e: Exception) {
            Log.e(TAG, "[VPN] Failed to establish tunnel: ${e.message} — service stays as foreground only")
            // Note: we do NOT set isVpnRunning = true here.
            // The service is still a foreground service, which still gives some protection,
            // but the VPN tunnel is not active.
        }
    }

    private fun stopFakeVpn() {
        // Guard against the double-stop loop: stopFakeVpn → stopSelf → onDestroy → stopFakeVpn
        if (isStopping) {
            Log.d(TAG, "[VPN] stopFakeVpn() called again while stopping — ignoring")
            return
        }
        isStopping = true
        isVpnRunning = false

        Log.i(TAG, "[VPN] Beginning graceful teardown...")

        // Step 1: Close the VPN tunnel file descriptor.
        // This is the root cause of the notification persisting:
        // if the FD is still open, Android keeps the VPN session alive,
        // which keeps the foreground service alive, which keeps the notification.
        val fd = vpnInterface
        vpnInterface = null
        if (fd != null) {
            try {
                fd.close()
                Log.i(TAG, "[VPN] ParcelFileDescriptor closed (fd=${fd.fd})")
            } catch (e: Exception) {
                Log.e(TAG, "[VPN] Error closing FD: ${e.message}")
            }
        } else {
            Log.d(TAG, "[VPN] No FD to close (tunnel was never established or already closed)")
        }

        // Step 2: Release the wake lock BEFORE stopping foreground
        // (holding it past stopForeground can cause battery leaks)
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
                Log.d(TAG, "[WAKELOCK] Released")
            }
        }

        // Step 3: Remove the foreground notification.
        // STOP_FOREGROUND_REMOVE guarantees the notification is cancelled.
        // This MUST be called before stopSelf() or the notification may linger.
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            Log.i(TAG, "[FOREGROUND] stopForeground(REMOVE) called")
        } catch (e: Exception) {
            Log.e(TAG, "[FOREGROUND] stopForeground failed: ${e.message}")
        }

        // Step 4: Stop the service. This triggers onDestroy(), but isStopping guards re-entry.
        Log.i(TAG, "[LIFECYCLE] Calling stopSelf()")
        stopSelf()
    }

    // ── Notification ───────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ChaosVoice Protection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "ChaosVoice background protection service"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
            Log.d(TAG, "[NOTIFICATION] Channel created: $CHANNEL_ID")
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopIntent = PendingIntent.getService(
            this, 1,
            Intent(this, ChaosVpnService::class.java).apply { action = "STOP_VPN" },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🔒 ChaosVoice Protected")
            .setContentText("Audio chaos engine running in background")
            .setSmallIcon(R.drawable.ic_mic_chaos)
            .setOngoing(true)
            .setContentIntent(openIntent)
            .addAction(android.R.drawable.ic_delete, "Stop", stopIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
