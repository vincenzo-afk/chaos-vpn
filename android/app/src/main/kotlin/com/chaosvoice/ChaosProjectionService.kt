package com.chaosvoice

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.*
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.*

/**
 * ChaosProjectionService — The core V3 engine.
 *
 * Architecture:
 *   [Option A — MediaProjection capture]
 *     MediaProjection → AudioPlaybackCapture → DSP → AudioTrack (SPEAKER MAX)
 *     The processed chaos plays through speaker/earphones → bleeds into mic → WhatsApp picks it up
 *
 *   [Option B — Direct mic capture (fallback when WhatsApp not running)]
 *     AudioRecord (MIC) → DSP → AudioTrack (SPEAKER MAX)
 *
 * The service auto-selects: if MediaProjection token is available, use A. Otherwise fall back to B.
 *
 * DSP Pipeline is managed by the unified ChaosDSP engine.
 */
class ChaosProjectionService : Service() {

    companion object {
        private const val TAG = "ChaosProjectionService"
        private const val NOTIFICATION_ID = 1002
        private const val CHANNEL_ID = "chaos_projection_channel"

        // V3 Audio config — 48kHz for maximum destruction fidelity
        const val SAMPLE_RATE = 48000
        private const val CHANNEL_IN  = AudioFormat.CHANNEL_IN_MONO
        private const val CHANNEL_OUT = AudioFormat.CHANNEL_OUT_MONO
        private const val ENCODING    = AudioFormat.ENCODING_PCM_16BIT

        // Buffer = 40ms at 48kHz  (1920 samples × 2 bytes = 3840 bytes)
        const val BUFFER_SAMPLES = 1920
        const val BUFFER_BYTES   = BUFFER_SAMPLES * 2

        // DSP parameters — V3 extreme defaults
        @Volatile var gainFactor: Float       = 10.0f
        @Volatile var bitCrushDepth: Int      = 4
        @Volatile var ringModFreq: Float      = 800.0f
        @Volatile var clipThreshold: Float    = 0.30f
        @Volatile var glitchRate: Float       = 0.15f
        @Volatile var noiseAmount: Float      = 0.40f
        @Volatile var pitchShiftSemitones: Float = -5.0f
        @Volatile var sampleRateReduction: Int   = 8000
        @Volatile var dropoutRate: Float      = 0.04f
        @Volatile var intensityPreset: String  = "BRUTAL"

        @Volatile var isRunning: Boolean = false
            private set

        // MediaProjection token provided by MainActivity after user acceptance
        @Volatile var projectionResultCode: Int = 0
        @Volatile var projectionData: Intent? = null

        fun start(context: Context) {
            val intent = Intent(context, ChaosProjectionService::class.java).apply {
                action = "START"
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /**
         * Start the service in foreground-only mode WITHOUT audio processing.
         *
         * MUST be called BEFORE showing the MediaProjection permission dialog on Android 10+.
         * Android 14 enforces that a foreground service with foregroundServiceType=mediaProjection
         * must already be running at the time the user grants the dialog; otherwise
         * getMediaProjection() throws SecurityException with "no active foreground service".
         *
         * Call sequence:
         *   1. startForegroundOnly()         ← service posts notification, enters foreground
         *   2. Show MediaProjection dialog    ← user grants permission
         *   3. startWithProjectionData()     ← pass token, start audio loop
         */
        fun startForegroundOnly(context: Context) {
            val intent = Intent(context, ChaosProjectionService::class.java).apply {
                action = "INIT"
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /**
         * Start audio processing using the MediaProjection token passed directly via Intent extras.
         * This avoids the static-variable race condition where the Intent can become stale
         * if the Activity is recreated between the dialog close and the service start.
         */
        fun startWithProjectionData(context: Context, resultCode: Int, data: Intent) {
            val intent = Intent(context, ChaosProjectionService::class.java).apply {
                action = "START_WITH_PROJECTION"
                putExtra("result_code", resultCode)
                putExtra("projection_data", data)
            }
            context.startService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, ChaosProjectionService::class.java).apply {
                action = "STOP"
            }
            context.startService(intent)
        }

        fun applyParams(args: Map<String, Any>) {
            gainFactor          = (args["gain"] as? Double)?.toFloat()              ?: gainFactor
            bitCrushDepth       = (args["bitCrushDepth"] as? Int)                  ?: bitCrushDepth
            ringModFreq         = (args["ringModFreq"] as? Double)?.toFloat()       ?: ringModFreq
            clipThreshold       = (args["clipThreshold"] as? Double)?.toFloat()     ?: clipThreshold
            glitchRate          = (args["glitchRate"] as? Double)?.toFloat()        ?: glitchRate
            noiseAmount         = (args["noiseAmount"] as? Double)?.toFloat()       ?: noiseAmount
            pitchShiftSemitones = (args["pitchShiftSemitones"] as? Double)?.toFloat() ?: pitchShiftSemitones
            sampleRateReduction = (args["sampleRateReduction"] as? Int)             ?: sampleRateReduction
            dropoutRate         = (args["dropoutRate"] as? Double)?.toFloat()       ?: dropoutRate
            intensityPreset     = (args["intensityPreset"] as? String)              ?: intensityPreset
            Log.d(TAG, "DSP params updated: gain=$gainFactor, bits=$bitCrushDepth, ringMod=$ringModFreq Hz, preset=$intensityPreset")
        }
    }

    private val running = AtomicBoolean(false)
    private var audioRecord: AudioRecord?  = null
    private var audioTrack: AudioTrack?    = null
    private var mediaProjection: MediaProjection? = null
    private var captureRecord: AudioRecord? = null
    private var processingThread: Thread?  = null
    private var wakeLock: PowerManager.WakeLock? = null

    // Stateful ChaosDSP engine
    private var dsp: ChaosDSP? = null

    // ─────────────────────── Service Lifecycle ───────────────────────────────

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ChaosVoice::ProjectionWakeLock")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            // INIT: post foreground notification WITHOUT starting audio.
            // Must be called BEFORE showing the MediaProjection dialog on Android 10+.
            "INIT" -> {
                val notification = buildNotification()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        NOTIFICATION_ID, notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION or
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                    )
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
                Log.d(TAG, "[INIT] Foreground notification posted, waiting for projection grant")
            }
            // START_WITH_PROJECTION: receives the MediaProjection token directly via Intent extras.
            // This is the preferred path — avoids the companion-static race condition.
            "START_WITH_PROJECTION" -> {
                val resultCode = intent.getIntExtra("result_code", 0)
                @Suppress("DEPRECATION")
                val data = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra("projection_data", Intent::class.java)
                } else {
                    intent.getParcelableExtra("projection_data")
                }
                if (resultCode != 0 && data != null) {
                    // Update companion statics as fallback reference
                    projectionResultCode = resultCode
                    projectionData = data
                    startChaosEngine(resultCode, data)
                } else {
                    Log.e(TAG, "[START_WITH_PROJECTION] Missing resultCode or data — falling back to MIC")
                    startChaosEngine()
                }
            }
            "START" -> startChaosEngine()
            "STOP"  -> stopChaosEngine()
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopChaosEngine()
        super.onDestroy()
    }

    // ─────────────────────── Foreground Setup ────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "ChaosVoice Engine",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Real-time voice chaos engine"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        }
    }

    private fun buildNotification(): Notification {
        val pi = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopPi = PendingIntent.getService(
            this, 0,
            Intent(this, ChaosProjectionService::class.java).apply { action = "STOP" },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("☠️ ChaosVoice ACTIVE")
            .setContentText("Your voice is being destroyed in real-time")
            .setSmallIcon(R.drawable.ic_mic_chaos)
            .setOngoing(true)
            .setContentIntent(pi)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stopPi)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    // ─────────────────────── Engine Start/Stop ───────────────────────────────

    private fun startChaosEngine(
        explicitResultCode: Int? = null,
        explicitProjectionData: Intent? = null
    ) {
        if (running.get()) {
            Log.d(TAG, "Engine already running — ignoring duplicate start")
            return
        }

        // Post foreground notification immediately (if not already posted by INIT)
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+: must specify types for media projection and microphone
            startForeground(
                NOTIFICATION_ID, notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION or
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

        // Set audio manager to communication mode for max priority
        val am = getSystemService(AUDIO_SERVICE) as AudioManager
        am.mode = AudioManager.MODE_IN_COMMUNICATION
        // Max out speaker volume for feedback loop
        val maxVol = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        am.setStreamVolume(AudioManager.STREAM_MUSIC, maxVol, 0)

        // Try MediaProjection capture first (prefer explicit params over companion statics)
        val useProjection = setupMediaProjectionCapture(
            resultCode = explicitResultCode ?: projectionResultCode,
            data       = explicitProjectionData ?: projectionData
        )
        if (!useProjection) {
            Log.d(TAG, "MediaProjection unavailable — falling back to MIC capture")
            setupMicCapture()
        }

        setupAudioTrack()

        running.set(true)
        isRunning = true

        audioRecord?.startRecording()
        captureRecord?.startRecording()
        audioTrack?.play()

        processingThread = Thread {
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            runChaosLoop()
        }.apply {
            name = "ChaosV3-DSP"
            start()
        }

        Log.d(TAG, "Chaos engine started (projection=${useProjection})")
    }

    private fun stopChaosEngine() {
        running.set(false)
        isRunning = false

        processingThread?.join(2000)
        processingThread = null

        try { audioRecord?.stop()  } catch (_: Exception) {}
        audioRecord?.release(); audioRecord = null

        try { captureRecord?.stop() } catch (_: Exception) {}
        captureRecord?.release(); captureRecord = null

        mediaProjection?.stop(); mediaProjection = null

        try { audioTrack?.stop()  } catch (_: Exception) {}
        audioTrack?.release(); audioTrack = null

        try {
            val am = getSystemService(AUDIO_SERVICE) as AudioManager
            am.mode = AudioManager.MODE_NORMAL
        } catch (_: Exception) {}

        wakeLock?.let { if (it.isHeld) it.release() }

        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
        stopSelf()

        dsp = null

        Log.d(TAG, "Chaos engine stopped")
    }

    // ──────────────────── Audio Setup ────────────────────────────────────────

    /**
     * Attempt to create an AudioPlaybackCapture record using MediaProjection.
     * Prefers explicitly passed resultCode+data (avoids static-var race condition).
     * Falls back to companion statics if explicit params are null.
     * Returns true if successful.
     */
    private fun setupMediaProjectionCapture(
        resultCode: Int = projectionResultCode,
        data: Intent? = projectionData
    ): Boolean {
        if (data == null || resultCode == 0) return false

        return try {
            val projMgr = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = projMgr.getMediaProjection(resultCode, data)

            val captureConfig = AudioPlaybackCaptureConfiguration.Builder(mediaProjection!!)
                .addMatchingUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                .build()

            val minBuf = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_IN, ENCODING)
            val bufSize = maxOf(minBuf, BUFFER_BYTES)

            captureRecord = AudioRecord.Builder()
                .setAudioPlaybackCaptureConfig(captureConfig)
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(SAMPLE_RATE)
                        .setEncoding(ENCODING)
                        .setChannelMask(CHANNEL_IN)
                        .build()
                )
                .setBufferSizeInBytes(bufSize)
                .build()

            Log.d(TAG, "AudioPlaybackCapture configured successfully")
            true
        } catch (e: Exception) {
            Log.e(TAG, "MediaProjection setup failed: ${e.message}")
            mediaProjection?.stop()
            mediaProjection = null
            false
        }
    }

    /**
     * Fall back to direct MIC capture.
     */
    private fun setupMicCapture() {
        val minBuf = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_IN, ENCODING)
        val bufSize = maxOf(minBuf, BUFFER_BYTES)
        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_IN,
                ENCODING,
                bufSize
            )
        } catch (e: Exception) {
            Log.e(TAG, "Mic capture setup failed: ${e.message}")
        }
    }

    /**
     * Set up AudioTrack output to SPEAKER with low latency.
     * USAGE_MEDIA ensures it comes out of speaker even in call mode.
     */
    private fun setupAudioTrack() {
        val minBuf = AudioTrack.getMinBufferSize(SAMPLE_RATE, CHANNEL_OUT, ENCODING)
        val bufSize = maxOf(minBuf, BUFFER_BYTES * 2)
        try {
            audioTrack = AudioTrack.Builder()
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
                .setBufferSizeInBytes(bufSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
                .build()

            audioTrack?.setVolume(AudioTrack.getMaxVolume())
        } catch (e: Exception) {
            Log.e(TAG, "AudioTrack setup failed: ${e.message}")
        }
    }

    // ──────────────────── Core Audio Loop ────────────────────────────────────

    private fun runChaosLoop() {
        val buffer  = ShortArray(BUFFER_SAMPLES)
        val output  = ShortArray(BUFFER_SAMPLES)

        while (running.get()) {
            try {
                // Pick whichever record source is active (projection preferred, mic fallback)
                val rec = captureRecord ?: audioRecord
                if (rec == null) {
                    Thread.sleep(20)
                    continue
                }

                val read = rec.read(buffer, 0, BUFFER_SAMPLES)

                when {
                    read == AudioRecord.ERROR_BAD_VALUE ||
                    read == AudioRecord.ERROR_INVALID_OPERATION -> {
                        Thread.sleep(30); continue
                    }
                    read <= 0 -> {
                        Thread.sleep(10); continue
                    }
                }

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
                    // Fallback to bypass if DSP isn't initialized yet
                    System.arraycopy(buffer, 0, output, 0, read)
                }

                // Write to speaker
                audioTrack?.write(output, 0, read, AudioTrack.WRITE_NON_BLOCKING)

            } catch (e: Exception) {
                if (!running.get()) break
                Log.e(TAG, "Loop error: ${e.message}")
                Thread.sleep(20)
            }
        }
    }

}
