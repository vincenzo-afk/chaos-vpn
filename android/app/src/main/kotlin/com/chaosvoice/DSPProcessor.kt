package com.chaosvoice

import kotlin.math.*

/**
 * Fast native DSP routines for real-time PCM processing.
 * Used by VirtualMicService for low-latency effects.
 */
object DSPProcessor {

    /**
     * Apply a tanh soft-clipping waveshaper.
     * drive: overdrive factor (higher = more distortion).
     */
    fun softClip(sample: Float, drive: Float = 4.0f): Float {
        val driven = (sample / 32767.0f) * drive
        val clipped = tanh(driven.toDouble()).toFloat()
        return (clipped * 32767.0f).coerceIn(-32767.0f, 32767.0f)
    }

    /**
     * Hard clip at a given threshold (0.0–1.0 of max).
     */
    fun hardClip(sample: Float, threshold: Float = 0.60f): Float {
        val clipLevel = threshold * 32767.0f
        return sample.coerceIn(-clipLevel, clipLevel)
    }

    /**
     * Bit crush: reduce bit depth by quantizing the sample.
     */
    fun bitCrush(sample: Float, bitDepth: Int = 6): Float {
        val steps = (2.0.pow(bitDepth - 1)).toFloat()
        val normalized = sample / 32767.0f
        val crushed = (normalized * steps).roundToInt() / steps
        return (crushed * 32767.0f).coerceIn(-32767.0f, 32767.0f)
    }

    /**
     * Numerically stable tanh approximation.
     */
    fun tanh(x: Double): Double {
        if (x > 20.0) return 1.0
        if (x < -20.0) return -1.0
        val e2x = exp(2 * x)
        return (e2x - 1) / (e2x + 1)
    }

    /**
     * RMS (Root Mean Square) energy of a buffer.
     */
    fun rms(buffer: ShortArray, count: Int): Double {
        if (count <= 0) return 0.0
        var sum = 0.0
        for (i in 0 until count) {
            sum += (buffer[i] / 32767.0) * (buffer[i] / 32767.0)
        }
        return sqrt(sum / count)
    }

    /**
     * Peak amplitude of a buffer (0.0–1.0).
     */
    fun peak(buffer: ShortArray, count: Int): Float {
        var max = 0.0f
        for (i in 0 until count) {
            val abs = abs(buffer[i])
            if (abs > max) max = abs
        }
        return max / 32767.0f
    }
}
