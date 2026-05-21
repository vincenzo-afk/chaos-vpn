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

/**
 * VirtualMicService — Legacy V1/V2 mic-capture fallback service.
 *
 * Primary engine is ChaosProjectionService.
 * This service is kept as a fallback for devices where MediaProjection
 * is unavailable or the user hasn't accepted the projection permission.
 *
 * USES the unified high-fidelity stateful ChaosDSP engine.
 */
class VirtualMicService : Service() {

    companion object {
        private const val TAG = "VirtualMicService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "chaosvoice_channel"

        private const val SAMPLE_RATE = 48000
        private const val CHANNEL_IN  = AudioFormat.CHANNEL_IN_MONO
        private const val CHANNEL_OUT = AudioFormat.CHANNEL_OUT_MONO
        private const val ENCODING    = AudioFormat.ENCODING_PCM_16BIT

        // Volatile mirrored parameters (synced from Flutter via MethodChannel)
        @Volatile var gainFactor: Float           = 10.0f
        @Volatile var crackleIntensity: Float     = 0.03f
        @Volatile var dropoutRate: Float          = 0.04f
        @Volatile var clipThreshold: Float        = 0.30f
        @Volatile var bitCrushDepth: Int          = 4
        @Volatile var ringModFreq: Float          = 800.0f
        @Volatile var noiseAmount: Float          = 0.40f
        @Volatile var glitchRate: Float           = 0.15f
        @Volatile var pitchShiftSemitones: Float  = -5.0f
        @Volatile var sampleRateReduction: Int    = 8000
        @Volatile var intensityPreset: String     = "BRUTAL"

        @Volatile var isRunning: Boolean = false
            private set

        fun start(context: Context): Boolean {
            val intent = Intent(context, VirtualMicService::class.java).apply { action = "START" }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            return true
        }

        fun stop(context: Context) {
            val intent = Intent(context, VirtualMicService::class.java).apply { action = "STOP" }
            context.startService(intent)
        }

        fun applyParams(args: Map<String, Any>) {
            gainFactor           = (args["gain"] as? Double)?.toFloat()                  ?: gainFactor
            crackleIntensity     = (args["crackleIntensity"] as? Double)?.toFloat()      ?: crackleIntensity
            dropoutRate          = (args["dropoutRate"] as? Double)?.toFloat()           ?: dropoutRate
            bitCrushDepth        = (args["bitCrushDepth"] as? Int)                       ?: bitCrushDepth
            clipThreshold        = (args["clipThreshold"] as? Double)?.toFloat()         ?: clipThreshold
            ringModFreq          = (args["ringModFreq"] as? Double)?.toFloat()           ?: ringModFreq
            noiseAmount          = (args["noiseAmount"] as? Double)?.toFloat()           ?: noiseAmount
            glitchRate           = (args["glitchRate"] as? Double)?.toFloat()            ?: glitchRate
            pitchShiftSemitones  = (args["pitchShiftSemitones"] as? Double)?.toFloat()  ?: pitchShiftSemitones
            sampleRateReduction  = (args["sampleRateReduction"] as? Int)                 ?: sampleRateReduction
            intensityPreset      = (args["intensityPreset"] as? String)                  ?: intensityPreset

            // Mirror parameters to ChaosProjectionService
            ChaosProjectionService.applyParams(args)

            Log.d(TAG, "V3 params applied: gain=$gainFactor, bits=$bitCrushDepth, ring=$ringModFreq, preset=$intensityPreset")
        }
    }

    private val isRunningFlag = AtomicBoolean(false)
    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var processingThread: Thread? = null
    private var wakeLock: PowerManager.WakeLock? = null

    // Stateful ChaosDSP engine
    private var dsp: ChaosDSP? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ChaosVoice::AudioWakeLock")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START" -> startVirtualMic()
            "STOP"  -> stopVirtualMic()
        }
        return START_NOT_STICKY // Use START_NOT_STICKY to avoid auto-restarting when closed
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopVirtualMic()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "ChaosVoice Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "ChaosVoice mic capture fallback"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val stopPi = PendingIntent.getService(
            this, 0,
            Intent(this, VirtualMicService::class.java).apply { action = "STOP" },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val openPi = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("☠️ ChaosVoice is ACTIVE")
            .setContentText("Your voice is being chaotically transformed")
            .setSmallIcon(R.drawable.ic_mic_chaos)
            .setOngoing(true)
            .setContentIntent(openPi)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stopPi)
            .build()
    }

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

        wakeLock?.acquire(4 * 60 * 60 * 1000L)

        // Initialize stateful ChaosDSP engine
        dsp = ChaosDSP(SAMPLE_RATE.toFloat()).apply {
            reset()
        }

        val bufSize = maxOf(
            AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_IN, ENCODING),
            ChaosProjectionService.BUFFER_BYTES
        )

        audioRecord = try {
            AudioRecord(MediaRecorder.AudioSource.MIC, SAMPLE_RATE, CHANNEL_IN, ENCODING, bufSize)
        } catch (e: Exception) {
            Log.e(TAG, "AudioRecord failed: ${e.message}"); stopVirtualMic(); return
        }

        audioTrack = try {
            AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(SAMPLE_RATE)
                        .setEncoding(ENCODING)
                        .setChannelMask(CHANNEL_OUT)
                        .build()
                )
                .setBufferSizeInBytes(maxOf(AudioTrack.getMinBufferSize(SAMPLE_RATE, CHANNEL_OUT, ENCODING), bufSize))
                .setTransferMode(AudioTrack.MODE_STREAM)
                .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
                .build()
                .apply { setVolume(AudioTrack.getMaxVolume()) }
        } catch (e: Exception) {
            Log.e(TAG, "AudioTrack failed: ${e.message}"); stopVirtualMic(); return
        }

        val am = getSystemService(AUDIO_SERVICE) as AudioManager
        am.mode = AudioManager.MODE_IN_COMMUNICATION
        val maxVol = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        am.setStreamVolume(AudioManager.STREAM_MUSIC, maxVol, 0)

        isRunningFlag.set(true)
        isRunning = true
        audioRecord?.startRecording()
        audioTrack?.play()

        processingThread = Thread {
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            runAudioLoop()
        }.apply { name = "ChaosV3-Mic"; start() }

        Log.d(TAG, "VirtualMicService V3 started")
    }

    private fun stopVirtualMic() {
        isRunningFlag.set(false)
        isRunning = false

        processingThread?.join(2000)
        processingThread = null

        try { audioRecord?.stop() } catch (_: Exception) {}
        audioRecord?.release(); audioRecord = null

        try { audioTrack?.stop() } catch (_: Exception) {}
        audioTrack?.release(); audioTrack = null

        try {
            val am = getSystemService(AUDIO_SERVICE) as AudioManager
            am.mode = AudioManager.MODE_NORMAL
        } catch (_: Exception) {}

        wakeLock?.let { if (it.isHeld) it.release() }
        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
        stopSelf()

        dsp = null

        Log.d(TAG, "VirtualMicService stopped")
    }

    private fun runAudioLoop() {
        val bufSamples = ChaosProjectionService.BUFFER_SAMPLES
        val buffer = ShortArray(bufSamples)
        val output = ShortArray(bufSamples)

        while (isRunningFlag.get()) {
            try {
                val read = audioRecord?.read(buffer, 0, bufSamples) ?: break
                if (read <= 0) { Thread.sleep(10); continue }

                // Apply dynamic preset selection to the DSP engine
                val presetEnum = when (intensityPreset.uppercase()) {
                    "MILD" -> ChaosDSP.IntensityPreset.MILD
                    "HEAVY" -> ChaosDSP.IntensityPreset.HEAVY
                    "BRUTAL" -> ChaosDSP.IntensityPreset.BRUTAL
                    "EXTREME" -> ChaosDSP.IntensityPreset.EXTREME
                    else -> ChaosDSP.IntensityPreset.BRUTAL
                }

                dsp?.let {
                    it.intensity = presetEnum
                    it.process(
                        buffer, output, read,
                        gainOverride = gainFactor,
                        bitCrushOverride = bitCrushDepth,
                        ringModOverride = ringModFreq,
                        clipOverride = clipThreshold,
                        glitchOverride = glitchRate,
                        noiseOverride = noiseAmount,
                        pitchOverride = pitchShiftSemitones,
                        srOverride = sampleRateReduction,
                        dropoutOverride = dropoutRate
                    )
                } ?: run {
                    System.arraycopy(buffer, 0, output, 0, read)
                }

                audioTrack?.write(output, 0, read, AudioTrack.WRITE_NON_BLOCKING)
            } catch (e: Exception) {
                if (!isRunningFlag.get()) break
                Thread.sleep(20)
            }
        }
    }
}
