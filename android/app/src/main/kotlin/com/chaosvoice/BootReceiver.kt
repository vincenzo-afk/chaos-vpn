package com.chaosvoice

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Broadcast receiver that restarts the ChaosVoice service
 * when the device finishes booting.
 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d(TAG, "Boot completed — restarting ChaosVoice service")
            // Start the VirtualMicService via the standard Intent action
            val serviceIntent = Intent(context, VirtualMicService::class.java).apply {
                action = "START"
            }
            context.startForegroundService(serviceIntent)
        }
    }
}
