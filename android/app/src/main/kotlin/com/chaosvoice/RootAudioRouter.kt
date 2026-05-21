package com.chaosvoice

import android.content.Context
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.media.AudioAttributes
import android.os.Build
import android.util.Log
import java.io.File

/**
 * Root-level audio router for system-wide mic injection on rooted Android devices.
 *
 * This provides HAL-level audio injection by interfacing with the Android Audio Policy
 * Service and audio HAL through shell commands available on rooted devices.
 *
 * **REQUIREMENTS:**
 * - Device must be rooted (su binary available)
 * - Requires a compatible Magisk module or system-signed APK
 * - Not available on non-rooted devices
 *
 * **CAPABILITIES (when root is available):**
 * - System-wide mic injection: ALL apps receive processed audio
 * - Phone calls (GSM/VoLTE): Telephony stack reads from the virtual device
 * - Games: Any audio source sees the processed input
 * - No app-level routing limitations
 *
 * **WARNING:**
 * - Root voids warranty on most devices
 * - Can cause system instability if misconfigured
 * - Requires the ChaosVoice Magisk module (Phase 5 roadmap)
 * - This file provides the scaffolding; the Magisk module is distributed separately.
 */
class RootAudioRouter(private val context: Context) {

    companion object {
        private const val TAG = "RootAudioRouter"
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_OUT = AudioFormat.CHANNEL_OUT_MONO
        private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
    }

    private var audioTrack: AudioTrack? = null
    private var isRootModeActive = false

    /**
     * Check if the device is rooted by verifying su path or executing which.
     */
    fun isDeviceRooted(): Boolean {
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) {
            return true
        }
        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su"
        )
        for (path in paths) {
            if (File(path).exists()) {
                return true
            }
        }
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("which", "su"))
            val reader = process.inputStream.bufferedReader()
            val line = reader.readLine()
            process.destroy()
            line != null
        } catch (e: Exception) {
            Log.d(TAG, "Root check failed: ${e.message}")
            false
        }
    }

    /**
     * Initialize root-mode audio routing.
     * Sets up AudioTrack with system-level attributes for HAL injection.
     */
    fun init(): Boolean {
        if (!isDeviceRooted()) {
            Log.w(TAG, "Device is not rooted — cannot initialize root audio router")
            return false
        }

        return try {
            val minBuffer = AudioTrack.getMinBufferSize(SAMPLE_RATE, CHANNEL_OUT, ENCODING)
            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .setFlags(AudioAttributes.FLAG_LOW_LATENCY)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(SAMPLE_RATE)
                        .setEncoding(ENCODING)
                        .setChannelMask(CHANNEL_OUT)
                        .build()
                )
                .setBufferSizeInBytes(maxOf(minBuffer, 3200))
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()

            Log.d(TAG, "Root audio router initialized")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize root audio router: ${e.message}")
            false
        }
    }

    /**
     * Activate root-level routing via AudioPolicyService.
     * This makes the processed audio available system-wide.
     */
    fun activate(): Boolean {
        if (!isDeviceRooted()) return false

        return try {
            // Set audio mode to communication
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION

            // Start AudioTrack
            audioTrack?.play()
            isRootModeActive = true

            // Attempt HAL-level routing via shell (requires Magisk module)
            try {
                val process = Runtime.getRuntime().exec(arrayOf(
                    "su", "-c",
                    "chaosvoice_hal_inject --start --rate $SAMPLE_RATE"
                ))
                process.waitFor()
                Log.d(TAG, "HAL injection command sent")
            } catch (e: Exception) {
                Log.w(TAG, "HAL injection command failed (Magisk module may not be installed): ${e.message}")
            }

            Log.d(TAG, "Root audio router activated")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to activate root audio router: ${e.message}")
            false
        }
    }

    /**
     * Write processed PCM data to the HAL-level audio output.
     */
    fun write(buffer: ShortArray, size: Int): Boolean {
        if (!isRootModeActive) return false
        return try {
            audioTrack?.write(buffer, 0, size) ?: -1 > 0
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write audio data: ${e.message}")
            false
        }
    }

    /**
     * Deactivate root routing and release resources.
     */
    fun deactivate() {
        if (!isRootModeActive) return

        try {
            Runtime.getRuntime().exec(arrayOf(
                "su", "-c", "chaosvoice_hal_inject --stop"
            ))
        } catch (e: Exception) {
            // Ignore — module may not be installed
        }

        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null
        isRootModeActive = false

        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.mode = AudioManager.MODE_NORMAL
        } catch (_: Exception) {}

        Log.d(TAG, "Root audio router deactivated")
    }

    fun isActive(): Boolean = isRootModeActive
}
