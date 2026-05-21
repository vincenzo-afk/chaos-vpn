package com.chaosvoice

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * BootReceiver — restarts ChaosVoice V3 services after device reboot.
 *
 * V3 restarts both the Fake VPN and the Chaos Projection engine so the
 * app stays protected from the moment Android finishes booting.
 *
 * Note: MediaProjection token is NOT persisted across reboots (Android security
 * requirement). The VPN service restarts, but MediaProjection will require the
 * user to accept the dialog again. The fallback MIC service is started instead.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d(TAG, "Boot completed — restarting ChaosVoice V3 services")

            // Start fake VPN first (survival engine)
            val vpnIntent = Intent(context, ChaosVpnService::class.java).apply {
                action = "START_VPN"
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(vpnIntent)
            } else {
                context.startService(vpnIntent)
            }

            // Start fallback mic service (projection token not available on boot)
            val micIntent = Intent(context, VirtualMicService::class.java).apply {
                action = "START"
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(micIntent)
            } else {
                context.startService(micIntent)
            }

            Log.d(TAG, "V3 services restart initiated")
        }
    }
}
