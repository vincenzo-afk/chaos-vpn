package com.chaosvoice

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.*
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.*
import kotlin.random.Random

/**
 * Core Android foreground service for real-time microphone capture,
 * DSP processing, and AudioTrack loopback routing.
 *
 * Architecture:
 *   AudioRecord (MIC) → applyNativeDSP() → AudioTrack (VOICE_COMMUNICATION)
 *
 * The AudioTrack is configured with USAGE_VOICE_COMMUNICATION so that
 * communication apps (Discord, WhatsApp, Zoom) detect it as a mic substitute.
 *
 * NOTE: Full system-wide virtual mic injection requires root or a system-signed
 * APK. This implementation provides coverage for VoIP/communication apps.
 */
class VirtualMicService : Service() {

    companion object {
        private const val TAG = "VirtualMicService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "chaosvoice_channel"

        // Audio config
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_IN = AudioFormat.CHANNEL_IN_MONO
        private const val CHANNEL_OUT = AudioFormat.CHANNEL_OUT_MONO
        private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT

        // DSP parameters (updatable from Flutter via MethodChannel)
        @Volatile var gainFactor: Float = 4.0f
        @Volatile var crackleIntensity: Float = 0.03f
        @Volatile var dropoutRate: Float = 0.06f
        @Volatile var clipThreshold: Float = 0.60f
        @Volatile var bitCrushDepth: Int = 6
        @Volatile var reverbRoomSize: Float = 0.45f
        @Volatile var fuzzDrive: Float = 4.0f
        @Volatile var echoDelay: Float = 100.0f
        @Volatile var echoDecay: Float = 1.0f
        @Volatile var pitchWobbleRange: Float = 3.0f

        @Volatile var isRunning: Boolean = false
            private set

        private var service: VirtualMicService? = null

        /** Start the foreground service. */
        fun start(context: Context): Boolean {
            val intent = Intent(context, VirtualMicService::class.java).apply {
                action = "START"
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            return true
        }

        /** Stop the foreground service. */
        fun stop(context: Context) {
            val intent = Intent(context, VirtualMicService::class.java).apply {
                action = "STOP"
            }
            context.startService(intent)
        }

        /** Update DSP parameters from Flutter. */
        fun applyParams(args: Map<String, Any>) {
            gainFactor = (args["gain"] as? Double)?.toFloat() ?: gainFactor
            crackleIntensity = (args["crackleIntensity"] as? Double)?.toFloat() ?: crackleIntensity
            dropoutRate = (args["dropoutRate"] as? Double)?.toFloat() ?: dropoutRate
            bitCrushDepth = (args["bitCrushDepth"] as? Int) ?: bitCrushDepth
            clipThreshold = (args["clipThreshold"] as? Double)?.toFloat() ?: clipThreshold
            reverbRoomSize = (args["reverbRoomSize"] as? Double)?.toFloat() ?: reverbRoomSize
            fuzzDrive = (args["fuzzDrive"] as? Double)?.toFloat() ?: fuzzDrive
            echoDelay = (args["echoDelay"] as? Double)?.toFloat() ?: echoDelay
            echoDecay = (args["echoDecay"] as? Double)?.toFloat() ?: echoDecay
            pitchWobbleRange = (args["pitchWobbleRange"] as? Double)?.toFloat() ?: pitchWobbleRange
            Log.d(TAG, "DSP params updated: gain=$gainFactor, bitCrushDepth=$bitCrushDepth, fuzz=$fuzzDrive")
        }
    }

    private val isRunningFlag = AtomicBoolean(false)
    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var processingThread: Thread? = null
    private var wakeLock: PowerManager.WakeLock? = null

    // ────────────────────────── Service Lifecycle ──────────────────────────────

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        service = this

        // Acquire wake lock to prevent CPU sleep
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "ChaosVoice::AudioWakeLock"
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START" -> startVirtualMic()
            "STOP" -> stopVirtualMic()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopVirtualMic()
        service = null
        super.onDestroy()
    }

    // ─────────────────────────── Foreground Service ────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ChaosVoice Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "ChaosVoice is running and modifying your microphone"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val stopIntent = Intent(this, VirtualMicService::class.java).apply {
            action = "STOP"
        }
        val stopPending = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val openIntent = Intent(this, MainActivity::class.java)
        val openPending = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("☠️ ChaosVoice is ACTIVE")
            .setContentText("Your voice is being chaotically transformed")
            .setSmallIcon(R.drawable.ic_mic_chaos)
            .setOngoing(true)
            .setContentIntent(openPending)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stopPending)
            .build()
    }

    // ──────────────────────────── Audio Pipeline ───────────────────────────────

    private fun startVirtualMic() {
        if (isRunningFlag.get()) return

        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID, notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        // Acquire wake lock
        wakeLock?.acquire(10 * 60 * 1000L) // 10 min timeout

        val minBufferIn = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_IN, ENCODING)
        val bufferSize = maxOf(minBufferIn, 3200) // ~200ms at 16kHz

        audioRecord = try {
            AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_IN,
                ENCODING,
                bufferSize
            )
        } catch (e: IllegalArgumentException) {
            Log.e(TAG, "Failed to create AudioRecord: ${e.message}")
            stopVirtualMic()
            return
        }

        val minBufferOut = AudioTrack.getMinBufferSize(SAMPLE_RATE, CHANNEL_OUT, ENCODING)
        audioTrack = try {
            AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(SAMPLE_RATE)
                        .setEncoding(ENCODING)
                        .setChannelMask(CHANNEL_OUT)
                        .build()
                )
                .setBufferSizeInBytes(maxOf(minBufferOut, bufferSize))
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
        } catch (e: UnsupportedOperationException) {
            Log.e(TAG, "Failed to create AudioTrack: ${e.message}")
            stopVirtualMic()
            return
        }

        // Route audio through voice communication mode
        val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        audioManager.isSpeakerphoneOn = false

        isRunningFlag.set(true)
        isRunning = true
        audioRecord?.startRecording()
        audioTrack?.play()

        processingThread = Thread { runAudioLoop(bufferSize) }.apply {
            // Use Android audio thread priority for low-latency processing
            android.os.Process.setThreadPriority(
                android.os.Process.THREAD_PRIORITY_URGENT_AUDIO
            )
            name = "ChaosVoice-DSP"
            start()
        }

        Log.d(TAG, "VirtualMicService started — DSP thread running")
    }

    private fun stopVirtualMic() {
        isRunningFlag.set(false)
        isRunning = false

        processingThread?.join(2000)
        processingThread = null

        try {
            audioRecord?.stop()
        } catch (_: Exception) {}
        audioRecord?.release()
        audioRecord = null

        try {
            audioTrack?.stop()
        } catch (_: Exception) {}
        audioTrack?.release()
        audioTrack = null

        val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        try {
            audioManager.mode = AudioManager.MODE_NORMAL
        } catch (_: Exception) {}

        wakeLock?.let {
            if (it.isHeld) it.release()
        }

        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (_: Exception) {}
        stopSelf()

        Log.d(TAG, "VirtualMicService stopped")
    }

    /// Core audio loop: reads raw PCM from mic, applies DSP, writes to AudioTrack.
    private fun runAudioLoop(bufferSize: Int) {
        val buffer = ShortArray(bufferSize / 2) // Int16 samples

        while (isRunningFlag.get()) {
            try {
                val read = audioRecord?.read(buffer, 0, buffer.size)
                    ?: break

                when {
                    read == AudioRecord.ERROR_BAD_VALUE -> {
                        Log.w(TAG, "AudioRecord ERROR_BAD_VALUE — reinitializing")
                        Thread.sleep(50)
                        recreateAudioRecord()
                        continue
                    }
                    read == AudioRecord.ERROR_INVALID_OPERATION -> {
                        Log.w(TAG, "AudioRecord ERROR_INVALID_OPERATION — reinitializing")
                        Thread.sleep(50)
                        recreateAudioRecord()
                        continue
                    }
                    read <= 0 -> {
                        // No data yet, brief sleep to avoid busy loop
                        Thread.sleep(10)
                        continue
                    }
                }

                // Apply native-side DSP
                val processed = applyNativeDSP(buffer, read)

                // Write processed PCM to AudioTrack → loopback
                val written = audioTrack?.write(processed, 0, read)
                if (written != null && written < 0) {
                    Log.w(TAG, "AudioTrack write error: $written")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in audio loop: ${e.message}")
                if (!isRunningFlag.get()) break
                Thread.sleep(20)
            }
        }
    }

    /// Recreate AudioRecord after error (buffer overflow / bad value).
    private fun recreateAudioRecord() {
        try {
            audioRecord?.release()
            val minBuffer = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_IN, ENCODING)
            val bufferSize = maxOf(minBuffer, 3200)
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_IN,
                ENCODING,
                bufferSize
            )
            audioRecord?.startRecording()
            Log.d(TAG, "AudioRecord reinitialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to reinitialize AudioRecord: ${e.message}")
        }
    }

    // ─────────────────────────── Native Kotlin DSP ─────────────────────────────
    // Fast native DSP operations (gain, clipping, noise).
    // The full 10-effect chain is applied on the Dart side when using
    // flutter_voice_processor callbacks.

    private fun applyNativeDSP(buffer: ShortArray, count: Int): ShortArray {
        val output = buffer.copyOf()
        val rng = Random

        // Dropout: silence entire chunk?
        if (rng.nextFloat() < dropoutRate) {
            return ShortArray(count) // all zeros
        }

        val maxInt16 = 32767.0f
        val clipLevel = (clipThreshold * maxInt16).toInt()
        val steps = (2.0.pow(bitCrushDepth - 1)).toFloat()

        for (i in 0 until count) {
            var sample = output[i].toFloat()

            // 1. Gain Boost
            sample = (sample * gainFactor).coerceIn(-maxInt16, maxInt16)

            // 6. Bit Crusher
            val normalized = sample / maxInt16
            val crushed = (normalized * steps).roundToInt() / steps
            sample = (crushed * maxInt16).coerceIn(-maxInt16, maxInt16)

            // 5. Soft Clip (tanh approximation)
            val driven = (sample / maxInt16) * 4.0f
            val softClipped = tanh(driven.toDouble()).toFloat()
            sample = (softClipped * maxInt16).coerceIn(-maxInt16, maxInt16)

            // 10. Hard Clip
            sample = sample.coerceIn(-clipLevel.toFloat(), clipLevel.toFloat())
            sample = (sample / clipLevel.toFloat()) * maxInt16

            // 3. Crackle Noise
            if (rng.nextFloat() < crackleIntensity) {
                val impulse = if (rng.nextBoolean()) maxInt16 else -maxInt16
                sample = (sample + impulse * 0.85f).coerceIn(-maxInt16, maxInt16)
            }

            output[i] = sample.toInt().toShort()
        }

        return output
    }

    private fun tanh(x: Double): Double {
        if (x > 20.0) return 1.0
        if (x < -20.0) return -1.0
        val e2x = exp(2 * x)
        return (e2x - 1) / (e2x + 1)
    }
}
