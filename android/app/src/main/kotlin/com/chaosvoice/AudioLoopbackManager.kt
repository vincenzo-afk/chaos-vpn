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
     * Optional DSP hook. When set, [readAndProcess] passes captured PCM through
     * this processor (e.g. the unified ChaosDSP engine) before output. When
     * null, audio passes through unchanged.
     */
    var processor: ((ShortArray, ShortArray, Int) -> Unit)? = null

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
     *
     * Bug fix: previously this started recording even if the underlying
     * AudioRecord was never initialized (e.g. when [init] had failed), which
     * threw IllegalStateException and left the loopback in a half-started state.
     */
    fun start(): Boolean {
        if (isActive) return true
        val record = audioRecord ?: return false
        val track = audioTrack ?: return false
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            Log.e(TAG, "Cannot start loopback: AudioRecord not initialized")
            return false
        }

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
        val record = audioRecord ?: return -1
        val result = record.read(buffer, 0, buffer.size)
        return when (result) {
            AudioRecord.ERROR_BAD_VALUE,
            AudioRecord.ERROR_INVALID_OPERATION -> -1
            else -> result
        }
    }

    /**
     * Capture, process and play out one buffer.
     *
     * Bug fix: this replaces the missing DSP wiring — previously there was no
     * way to route captured mic audio through the chaos engine on the
     * loopback path, so callers could only do raw passthrough. With [processor]
     * set (e.g. `processor = { inBuf, outBuf, n -> dsp?.process(inBuf, outBuf, n) }`),
     * the modified voice is written out and heard by the remote party.
     *
     * @param input scratch input buffer
     * @param output scratch output buffer (may equal [input] for in-place processors)
     * @return number of processed samples played out, or -1 on failure
     */
    fun readAndProcess(input: ShortArray, output: ShortArray): Int {
        val read = read(input)
        if (read <= 0) return -1

        val proc = processor
        if (proc != null) {
            proc(input, output, read)
        } else {
            System.arraycopy(input, 0, output, 0, read)
        }
        return write(output, read)
    }

    /**
     * Write processed PCM to the AudioTrack output.
     *
     * Bug fix: the previous implementation ignored [size] validation, so a
     * negative or oversized size caused exceptions or corrupted playback.
     *
     * @return number of samples written, or -1 on failure
     */
    fun write(buffer: ShortArray, size: Int): Int {
        if (!isActive || buffer.isEmpty() || size <= 0 || size > buffer.size) return -1
        return audioTrack?.write(buffer, 0, size) ?: -1
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

    /**
     * Check whether the underlying AudioRecord was initialized successfully.
     */
    fun isInitialized(): Boolean {
        val record = audioRecord ?: return false
        return record.state == AudioRecord.STATE_INITIALIZED
    }
}
