package com.chaosvoice

import kotlin.math.*
import kotlin.random.Random

/**
 * ChaosDSP — The red-zone, harsh-noise DSP processing engine.
 *
 * Implements a heavy real-time float-based nonlinear DSP chain.
 * By using float internally ([-1.0f, 1.0f]), it eliminates digital wrapping
 * and short integer overflow bugs, converting back to PCM16 at the final output.
 *
 * The chain consists of:
 *   1. Resonant EQ (emphasizes ear-piercing harsh bands in the 1.8kHz - 3.5kHz range)
 *   2. Filtered Noise (white noise generated and filtered through a bandpass filter, then mixed)
 *   3. Stage 1 Tanh Saturation (first stage of nonlinear drive)
 *   4. Modulated Feedback Delay (metallic comb filter / flanger with safety tanh feedback limit)
 *   5. Stage 2 Tanh Saturation (second stage of nonlinear drive)
 *   6. Ring Modulation (discordant metallic sidebands via high frequency sine wave)
 *   7. Bit Crusher & Downsampler (amplitude and time-domain quantization)
 *   8. Hard Clipper (squares off the waveform)
 *   9. Output Peak Limiter (smooth knee limiter to prevent any overflow/wrap clipping)
 *   10. Glitch Stutter (random buffer freeze repeats)
 *
 * Low-latency safety details:
 *   - No memory allocation occurs inside the audio process loop (zero GC pressure).
 *   - Uses a fast polynomial approximation for tanh() to save CPU cycles on mobile cores.
 *   - Underflow prevention clears subnormal floats to zero to avoid CPU microcode traps.
 */
class ChaosDSP(private val sampleRate: Float = 48000f) {

    /**
     * Presets governing the aggressiveness and parameters of the DSP engine.
     */
    enum class IntensityPreset {
        MILD, HEAVY, BRUTAL, EXTREME
    }

    // Default to BRUTAL for maximum screaming noise!
    @Volatile
    var intensity = IntensityPreset.BRUTAL

    // ─── DSP State & Pre-allocated Buffers ─────────────────────────────────────
    private var ringModPhase = 0.0
    private var lfoPhase = 0.0
    private val rng = Random(System.nanoTime())

    // Biquad Filters (pre-allocated to avoid GC pressure in audio thread)
    private val resonantEq = BiquadFilter()
    private val noiseFilter = BiquadFilter()

    // Delay line for feedback-style modulation (max 100ms at 48kHz = 4800 samples)
    private val delayLine = DelayLine(4800)

    // Stutter/Glitch state
    private val glitchBuffer = FloatArray(1920)
    private var glitchFrozen = false
    private var glitchCounter = 0

    // Downsampling state
    private var lastHeldSample = 0f

    // ─── Biquad Filter Helper Class ───────────────────────────────────────────
    class BiquadFilter {
        private var x1 = 0f
        private var x2 = 0f
        private var y1 = 0f
        private var y2 = 0f

        // Direct Form I normalized biquad coefficients.
        // Feed-forward: b0, b1, b2. Feedback: a1, a2. (a0 = 1 after normalization)
        private var b0 = 1f
        private var b1 = 0f
        private var b2 = 0f
        private var a1 = 0f
        private var a2 = 0f

        fun setBandpass(sampleRate: Float, centerFreq: Float, Q: Float) {
            val w0 = (2.0 * Math.PI * centerFreq / sampleRate).toFloat()
            val alpha = (sin(w0.toDouble()) / (2.0 * Q)).toFloat()
            val cosW0 = cos(w0)

            // a0_norm is the real denominator a0 used for normalization
            val a0_norm = 1.0f + alpha

            // Feed-forward coefficients (bandpass: b1=0, b2=-b0)
            this.b0 =  alpha / a0_norm
            this.b1 =  0f
            this.b2 = -alpha / a0_norm

            // Feedback coefficients (normalized: divide by a0_norm)
            this.a1 = (-2.0f * cosW0) / a0_norm
            this.a2 = (1.0f - alpha)  / a0_norm
        }

        fun process(input: Float): Float {
            // Direct Form I: y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]
            val output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2

            // Underflow protection: clear tiny subnormal floats to zero to avoid CPU lag
            if (abs(output) < 1e-10f) {
                y1 = 0f; y2 = 0f; x1 = 0f; x2 = 0f
                return 0f
            }

            x2 = x1
            x1 = input
            y2 = y1
            y1 = output
            return output
        }

        fun reset() {
            x1 = 0f; x2 = 0f; y1 = 0f; y2 = 0f
        }
    }

    // ─── Delay Line Helper Class ──────────────────────────────────────────────
    class DelayLine(size: Int) {
        private val buffer = FloatArray(size)
        private var writeIndex = 0

        fun write(sample: Float) {
            buffer[writeIndex] = sample
            writeIndex = (writeIndex + 1) % buffer.size
        }

        fun read(delaySamples: Float): Float {
            val delayInt = delaySamples.toInt()
            val frac = delaySamples - delayInt
            
            val readIndex1 = (writeIndex - delayInt + buffer.size) % buffer.size
            val readIndex2 = (readIndex1 - 1 + buffer.size) % buffer.size
            
            // Linear interpolation for fractional delay to prevent clicking
            return buffer[readIndex1] * (1.0f - frac) + buffer[readIndex2] * frac
        }

        fun reset() {
            buffer.fill(0f)
            writeIndex = 0
        }
    }

    // ─── Fast Tanh Approximation ──────────────────────────────────────────────
    /**
     * Fast approximation of tanh(x) for real-time mobile audio.
     * Accurate within the critical range [-3.0f, 3.0f].
     */
    private fun fastTanh(x: Float): Float {
        if (x < -3.0f) return -1.0f
        if (x > 3.0f) return 1.0f
        val x2 = x * x
        return x * (27.0f + x2) / (27.0f + 9.0f * x2)
    }

    /**
     * Clear all filters and accumulators to prevent click sounds on engine start/stop.
     */
    fun reset() {
        ringModPhase = 0.0
        lfoPhase = 0.0
        resonantEq.reset()
        noiseFilter.reset()
        delayLine.reset()
        glitchFrozen = false
        glitchCounter = 0
        lastHeldSample = 0f
    }

    /**
     * Process a block of PCM16 audio samples in place.
     * Takes input, applies float-based nonlinear DSP chain, writes to output.
     */
    fun process(
        input: ShortArray,
        output: ShortArray,
        count: Int,
        // Manual override inputs from Flutter sliders (if not using pure presets)
        gainOverride: Float? = null,
        bitCrushOverride: Int? = null,
        ringModOverride: Float? = null,
        clipOverride: Float? = null,
        glitchOverride: Float? = null,
        noiseOverride: Float? = null,
        pitchOverride: Float? = null,
        srOverride: Int? = null,
        dropoutOverride: Float? = null
    ) {
        // ─── STAGE 0: Configure Parameters by Intensity Preset or Overrides ───
        val pGain1: Float
        val pGain2: Float
        val pSoftClipDrive: Float
        val pResonanceFreq: Float
        val pResonanceQ: Float
        val pNoiseMix: Float
        val pNoiseFilterFreq: Float
        val pFeedbackDelayMs: Float
        val pFeedbackAmt: Float
        val pLfoRateHz: Float
        val pLfoDepthMs: Float
        val pBitCrush: Int
        val pSrReduction: Int
        val pHardClip: Float
        val pGlitch: Float
        val pDropout: Float
        val pPitchShift: Float

        when (intensity) {
            IntensityPreset.MILD -> {
                pGain1 = gainOverride ?: 2.0f
                pGain2 = 1.2f
                pSoftClipDrive = 1.5f
                pResonanceFreq = 1800f
                pResonanceQ = 1.5f
                pNoiseMix = noiseOverride ?: 0.08f
                pNoiseFilterFreq = 2000f
                pFeedbackDelayMs = 12f
                pFeedbackAmt = 0.2f
                pLfoRateHz = 0.5f
                pLfoDepthMs = 2.0f
                pBitCrush = bitCrushOverride ?: 8
                pSrReduction = srOverride ?: 16000
                pHardClip = clipOverride ?: 0.8f
                pGlitch = glitchOverride ?: 0.02f
                pDropout = dropoutOverride ?: 0.01f
                pPitchShift = pitchOverride ?: -1.5f
            }
            IntensityPreset.HEAVY -> {
                pGain1 = gainOverride ?: 5.0f
                pGain2 = 2.0f
                pSoftClipDrive = 3.5f
                pResonanceFreq = 2200f
                pResonanceQ = 3.0f
                pNoiseMix = noiseOverride ?: 0.20f
                pNoiseFilterFreq = 2500f
                pFeedbackDelayMs = 18f
                pFeedbackAmt = 0.4f
                pLfoRateHz = 1.2f
                pLfoDepthMs = 4.0f
                pBitCrush = bitCrushOverride ?: 5
                pSrReduction = srOverride ?: 8000
                pHardClip = clipOverride ?: 0.5f
                pGlitch = glitchOverride ?: 0.08f
                pDropout = dropoutOverride ?: 0.04f
                pPitchShift = pitchOverride ?: -3.5f
            }
            IntensityPreset.BRUTAL -> {
                pGain1 = gainOverride ?: 12.0f
                pGain2 = 4.0f
                pSoftClipDrive = 8.0f
                pResonanceFreq = 2600f
                pResonanceQ = 5.0f
                pNoiseMix = noiseOverride ?: 0.35f
                pNoiseFilterFreq = 3000f
                pFeedbackDelayMs = 25f
                pFeedbackAmt = 0.65f
                pLfoRateHz = 2.5f
                pLfoDepthMs = 8.0f
                pBitCrush = bitCrushOverride ?: 4
                pSrReduction = srOverride ?: 5000
                pHardClip = clipOverride ?: 0.3f
                pGlitch = glitchOverride ?: 0.15f
                pDropout = dropoutOverride ?: 0.07f
                pPitchShift = pitchOverride ?: -6.0f
            }
            IntensityPreset.EXTREME -> {
                pGain1 = gainOverride ?: 30.0f
                pGain2 = 10.0f
                pSoftClipDrive = 20.0f
                pResonanceFreq = 2800f
                pResonanceQ = 8.0f
                pNoiseMix = noiseOverride ?: 0.55f
                pNoiseFilterFreq = 3500f
                pFeedbackDelayMs = 35f
                pFeedbackAmt = 0.85f
                pLfoRateHz = 4.0f
                pLfoDepthMs = 12.0f
                pBitCrush = bitCrushOverride ?: 2
                pSrReduction = srOverride ?: 3000
                pHardClip = clipOverride ?: 0.15f
                pGlitch = glitchOverride ?: 0.25f
                pDropout = dropoutOverride ?: 0.12f
                pPitchShift = pitchOverride ?: -10.0f
            }
        }

        // Dynamically update filters with current parameter frequencies
        resonantEq.setBandpass(sampleRate, pResonanceFreq, pResonanceQ)
        noiseFilter.setBandpass(sampleRate, pNoiseFilterFreq, 2.0f)

        // Stutter / Glitch pre-check
        if (pGlitch > 0f && rng.nextFloat() < pGlitch) {
            glitchFrozen = true
            glitchCounter = count
        }
        if (glitchFrozen) {
            // Write frozen stutter loop to output
            for (i in 0 until count) {
                output[i] = (glitchBuffer[i % glitchBuffer.size] * 32767.0f).toInt().toShort()
            }
            glitchCounter -= count
            if (glitchCounter <= 0) {
                glitchFrozen = false
            }
            return
        }

        val rModFreq = ringModOverride ?: 800f
        val ringModInc = 2.0 * Math.PI * rModFreq / sampleRate

        val centerDelaySamples = pFeedbackDelayMs * (sampleRate / 1000f)
        val lfoRangeSamples = pLfoDepthMs * (sampleRate / 1000f)
        val lfoInc = 2.0 * Math.PI * pLfoRateHz / sampleRate

        val srFactor = maxOf(1, (sampleRate / pSrReduction).toInt())
        val pitchRatio = 2.0.pow(pPitchShift.toDouble() / 12.0)

        // ─── MAIN SAMPLES RENDER LOOP ──────────────────────────────────────────
        for (i in 0 until count) {
            // Stage 11: Voice Dropout (simulates network dropouts)
            if (pDropout > 0f && rng.nextFloat() < pDropout) {
                output[i] = 0
                continue
            }

            // Convert raw PCM16 short to normalized float [-1.0f, 1.0f]
            var s = input[i].toFloat() / 32768.0f

            // Pitch shift resampling simulation
            val srcIdx = (i * pitchRatio).toInt().coerceIn(0, count - 1)
            val sPitched = input[srcIdx].toFloat() / 32768.0f
            s = s * 0.5f + sPitched * 0.5f

            // Stage 1: Resonant EQ Emphasis (pushes harsh mids before distortion)
            s = resonantEq.process(s)

            // Stage 2: Filtered Noise Injection (harsh static interference)
            if (pNoiseMix > 0f) {
                val rawNoise = rng.nextFloat() * 2.0f - 1.0f
                val filteredNoise = noiseFilter.process(rawNoise)
                s = s * (1.0f - pNoiseMix) + filteredNoise * pNoiseMix
            }

            // Stage 3: Multi-Stage Gain A + Tanh Saturation (soft clipping)
            s = fastTanh(s * pGain1)

            // Stage 4: Feedback Comb Modulation (modulates metal flanger/delay resonance)
            val lfo = sin(lfoPhase).toFloat()
            lfoPhase += lfoInc
            if (lfoPhase >= 2.0 * Math.PI) lfoPhase -= 2.0 * Math.PI

            val modulatedDelay = centerDelaySamples + lfo * lfoRangeSamples
            val delayedSample = delayLine.read(modulatedDelay)
            
            // Safety Limiting feedback path with fast tanh
            val feedback = fastTanh(delayedSample * pFeedbackAmt)
            val cleanInput = s
            s = cleanInput + feedback
            delayLine.write(cleanInput + feedback * 0.7f)

            // Stage 5: Multi-Stage Gain B + Tanh Saturation
            s = fastTanh(s * pGain2)

            // Stage 6: Ring Modulation (robotic metallic sidebands)
            if (rModFreq > 0f) {
                val carrier = sin(ringModPhase).toFloat()
                ringModPhase += ringModInc
                if (ringModPhase >= 2.0 * Math.PI) ringModPhase -= 2.0 * Math.PI
                s *= carrier
            }

            // Stage 7: Bit Crush & Sample Rate Reduction
            if (pBitCrush in 2..15) {
                val steps = (2.0.pow(pBitCrush - 1)).toFloat()
                s = (s * steps).roundToInt() / steps
            }
            if (i % srFactor == 0) {
                lastHeldSample = s
            } else {
                s = lastHeldSample
            }

            // Stage 8: Hard Clipping (forces severe squaring)
            s = s.coerceIn(-pHardClip, pHardClip)
            if (pHardClip > 0f) {
                s /= pHardClip
            }

            // Stage 9: Output Knee Peak Limiter (prevents digital overflow wrapping)
            val absS = abs(s)
            if (absS > 0.85f) {
                val sign = if (s < 0f) -1.0f else 1.0f
                s = sign * (0.85f + (absS - 0.85f) / (1.0f + (absS - 0.85f) * 2.0f))
            }
            s = s.coerceIn(-1.0f, 1.0f)

            // Save to buffer for stuttering repeats
            glitchBuffer[i % glitchBuffer.size] = s

            // Stage 10: Convert back to PCM16 Short and save to output buffer
            output[i] = (s * 32767.0f).toInt().toShort()
        }
    }
}
