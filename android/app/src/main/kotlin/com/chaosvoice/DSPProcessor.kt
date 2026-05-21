package com.chaosvoice

import kotlin.math.*

/**
 * V3 Extreme DSP Routines.
 *
 * All methods operate on normalized Float samples [-32767, 32767].
 * The full 8-stage pipeline is implemented in ChaosProjectionService.
 * This object provides standalone helpers for testing / reuse.
 */
object DSPProcessor {

    private const val MAX_I16 = 32767.0f

    // ─── Stage 1: Extreme Gain ────────────────────────────────────────────────

    /** Apply gain and hard-saturate to INT16 range. 10x recommended for V3. */
    fun extremeGain(sample: Float, gain: Float = 10.0f): Float =
        (sample * gain).coerceIn(-MAX_I16, MAX_I16)

    // ─── Stage 2: Bit Crush ───────────────────────────────────────────────────

    /**
     * Reduce to bitDepth bits of resolution.
     * bitDepth=4 → 16 quantization levels → extreme digital distortion.
     * bitDepth=6 → 64 levels (less extreme).
     */
    fun bitCrush(sample: Float, bitDepth: Int = 4): Float {
        val steps = (2.0.pow(bitDepth - 1)).toFloat()
        val normalized = sample / MAX_I16
        val crushed = (normalized * steps).roundToInt() / steps
        return (crushed * MAX_I16).coerceIn(-MAX_I16, MAX_I16)
    }

    // ─── Stage 3: Ring Modulation ─────────────────────────────────────────────

    /**
     * Multiply signal by a sine wave at [carrierHz].
     * 800Hz creates metallic/robotic timbre.
     * [phase] is the running phase accumulator (update externally).
     */
    fun ringModulate(sample: Float, phase: Double): Float =
        (sample * sin(phase).toFloat()).coerceIn(-MAX_I16, MAX_I16)

    fun ringModPhaseIncrement(carrierHz: Float, sampleRate: Int = 48000): Double =
        2.0 * Math.PI * carrierHz / sampleRate

    // ─── Stage 4: Hard Clip ───────────────────────────────────────────────────

    /**
     * Hard clip at [threshold] fraction of max (0.0–1.0).
     * threshold=0.30 → clips to 30% → effectively a square wave.
     * Normalizes clipped signal back to full amplitude.
     */
    fun hardClip(sample: Float, threshold: Float = 0.30f): Float {
        val clipLevel = threshold * MAX_I16
        val clipped = sample.coerceIn(-clipLevel, clipLevel)
        return if (clipLevel > 0f) (clipped / clipLevel) * MAX_I16 else clipped
    }

    // ─── Stage 5: Glitch Stutter — handled per-buffer in ChaosProjectionService

    // ─── Stage 6: White Noise Injection ──────────────────────────────────────

    /**
     * Mix white noise at [amount] ratio (0.0–1.0).
     * amount=0.40 → 40% noise, 60% signal.
     */
    fun injectNoise(sample: Float, amount: Float = 0.40f): Float {
        val noise = (Math.random().toFloat() * 2.0f - 1.0f) * MAX_I16 * amount
        return (sample * (1.0f - amount) + noise).coerceIn(-MAX_I16, MAX_I16)
    }

    // ─── Stage 7: Pitch Shift ─────────────────────────────────────────────────

    /** Compute the resampling ratio for a given semitone shift. */
    fun pitchRatio(semitones: Float): Double = 2.0.pow(semitones / 12.0)

    // ─── Stage 8: Sample Rate Reduction ──────────────────────────────────────

    /**
     * The factor by which to sub-sample.
     * reductionHz=8000 at sampleRate=48000 → factor=6 → lo-fi 8kHz simulation.
     */
    fun srReductionFactor(reductionHz: Int, sampleRate: Int = 48000): Int =
        maxOf(1, sampleRate / reductionHz)

    // ─── Legacy helpers (V1/V2 compat) ────────────────────────────────────────

    fun softClip(sample: Float, drive: Float = 4.0f): Float {
        val driven = (sample / MAX_I16) * drive
        val clipped = tanh(driven.toDouble()).toFloat()
        return (clipped * MAX_I16).coerceIn(-MAX_I16, MAX_I16)
    }

    fun rms(buffer: ShortArray, count: Int): Double {
        if (count <= 0) return 0.0
        var sum = 0.0
        for (i in 0 until count) {
            sum += (buffer[i] / 32767.0) * (buffer[i] / 32767.0)
        }
        return sqrt(sum / count)
    }

    fun peak(buffer: ShortArray, count: Int): Float {
        var max = 0.0f
        for (i in 0 until count) {
            val v = abs(buffer[i].toInt()).toFloat()
            if (v > max) max = v
        }
        return max / MAX_I16
    }

    private fun tanh(x: Double): Double {
        if (x > 20.0) return 1.0
        if (x < -20.0) return -1.0
        val e2x = exp(2 * x)
        return (e2x - 1) / (e2x + 1)
    }
}
