package com.chaosvoice

import android.media.*
import android.util.Log

/**
 * Manages the AudioRecord → AudioTrack loopback routing on Android.
 *
 * This creates a real-time loop: microphone input is captured, sent to
 * the DSP engine, and then written to an AudioTrack configured with
 * USAGE_VOICE_COMMUNICATION so that communication apps can detect it.
 *
 * NOTE: Full system-wide virtual mic injection requires root or a system-signed
 * APK. On non-root devices, this works with VoIP/communication apps (Discord,
 * WhatsApp, Teams, Zoom) that use AudioSource.VOICE_COMMUNICATION.
 */
class AudioLoopbackManager(
    private val sampleRate: Int = 16000
) {
    companion object {
        private const val TAG = "AudioLoopbackManager"
        private const val CHANNEL_IN = AudioFormat.CHANNEL_IN_MONO
        private const val CHANNEL_OUT = AudioFormat.CHANNEL_OUT_MONO
        private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
    }

    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var isActive = false

    /**
     * Initialize AudioRecord and AudioTrack instances.
     * Returns the buffer size used, or -1 on failure.
     */
    fun init(): Int {
        val minBufferIn = AudioRecord.getMinBufferSize(sampleRate, CHANNEL_IN, ENCODING)
        val bufferSize = maxOf(minBufferIn, 3200)

        audioRecord = try {
            AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                CHANNEL_IN,
                ENCODING,
                bufferSize
            )
        } catch (e: SecurityException) {
            Log.e(TAG, "Missing RECORD_AUDIO permission: ${e.message}")
            return -1
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create AudioRecord: ${e.message}")
            return -1
        }

        val minBufferOut = AudioTrack.getMinBufferSize(sampleRate, CHANNEL_OUT, ENCODING)
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
                        .setSampleRate(sampleRate)
                        .setEncoding(ENCODING)
                        .setChannelMask(CHANNEL_OUT)
                        .build()
                )
                .setBufferSizeInBytes(maxOf(minBufferOut, bufferSize))
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create AudioTrack: ${e.message}")
            return -1
        }

        return bufferSize
    }

    /**
     * Start recording and playback.
     */
    fun start(): Boolean {
        if (isActive) return true
        val record = audioRecord ?: return false
        val track = audioTrack ?: return false

        try {
            record.startRecording()
            track.play()
            isActive = true
            Log.d(TAG, "Loopback started")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start loopback: ${e.message}")
            return false
        }
    }

    /**
     * Read one buffer of raw PCM from the microphone.
     */
    fun read(buffer: ShortArray): Int {
        return audioRecord?.read(buffer, 0, buffer.size) ?: -1
    }

    /**
     * Write processed PCM to the AudioTrack output.
     */
    fun write(buffer: ShortArray, size: Int) {
        audioTrack?.write(buffer, 0, size)
    }

    /**
     * Stop and release all resources.
     */
    fun stop() {
        isActive = false
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

        Log.d(TAG, "Loopback stopped")
    }

    fun isActive(): Boolean = isActive
}
