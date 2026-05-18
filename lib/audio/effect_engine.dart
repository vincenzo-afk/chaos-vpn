import 'dart:math';
import 'dart:typed_data';
import 'bandpass_filter.dart';
import 'echo_buffer.dart';
import 'reverb_processor.dart';
import 'pitch_wobble.dart';
import 'pcm_utils.dart';
import '../models/effect_settings.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// Master DSP effect engine — applies all 10 chaos effects to a raw PCM chunk.
/// Input: Int16List of raw mic samples (16-bit, mono, 16000 Hz)
/// Output: Int16List of processed samples ready for virtual mic injection.
class EffectEngine {
  final int sampleRate;
  final Random _rng = Random();

  // Effect parameters (adjustable from UI)
  double gainFactor = EffectDefaults.gainFactor;
  double crackleProb = EffectDefaults.crackleProb;
  double dropoutProb = EffectDefaults.dropoutProb;
  double softDrive = EffectDefaults.softDrive;
  int bitDepth = EffectDefaults.bitDepth;
  double hardClipThreshold = EffectDefaults.hardClipThreshold;
  double reverbMix = EffectDefaults.reverbMix;

  // Effect toggle flags
  bool gainEnabled = true;
  bool bandpassEnabled = true;
  bool bitCrushEnabled = true;
  bool softClipEnabled = true;
  bool hardClipEnabled = true;
  bool echoEnabled = true;
  bool reverbEnabled = true;
  bool crackleEnabled = true;
  bool dropoutEnabled = true;
  bool pitchWobbleEnabled = true;

  // Internal processors
  late final BandpassFilter _bandpass;
  late final EchoBuffer _echo;
  late final ReverbProcessor _reverb;
  late final PitchWobble _pitch;

  // Processing statistics
  int totalChunksProcessed = 0;
  int totalSamplesProcessed = 0;

  EffectEngine({this.sampleRate = AudioConstants.sampleRate}) {
    _bandpass = BandpassFilter(
      sampleRate: sampleRate,
      lowHz: 300.0,
      highHz: 3400.0,
    );
    _echo = EchoBuffer(
      sampleRate: sampleRate,
      maxDelayMs: 500,
    );
    _reverb = ReverbProcessor(sampleRate: sampleRate);
    _pitch = PitchWobble(sampleRate: sampleRate);
  }

  /// Update all effect parameters from a settings object.
  void updateFromSettings(EffectSettings settings) {
    gainFactor = settings.gainFactor;
    crackleProb = settings.crackleProb;
    dropoutProb = settings.dropoutProb;
    softDrive = settings.softDrive;
    bitDepth = settings.bitDepth;
    hardClipThreshold = settings.hardClipThreshold;
    reverbMix = settings.reverbMix;
    gainEnabled = settings.gainEnabled;
    bandpassEnabled = settings.bandpassEnabled;
    bitCrushEnabled = settings.bitCrushEnabled;
    softClipEnabled = settings.softClipEnabled;
    hardClipEnabled = settings.hardClipEnabled;
    echoEnabled = settings.echoEnabled;
    reverbEnabled = settings.reverbEnabled;
    crackleEnabled = settings.crackleEnabled;
    dropoutEnabled = settings.dropoutEnabled;
    pitchWobbleEnabled = settings.pitchWobbleEnabled;
  }

  /// Process one chunk of raw PCM samples through all 10 effects.
  Int16List process(Int16List input) {
    if (input.isEmpty) return input;

    // Convert to normalized double for processing
    final samples = PcmUtils.toDoubles(input);

    // Apply effects in order

    // Effect 1: Gain Boost (3x–5x volume amplification)
    if (gainEnabled) _applyGainBoost(samples);

    // Effect 8: Bandpass Filter (300–3400 Hz — telephone effect)
    if (bandpassEnabled) _bandpass.process(samples);

    // Effect 6: Bit Crusher (6-bit quantization)
    if (bitCrushEnabled) _applyBitCrusher(samples);

    // Effect 5: Soft Clip / Overdrive Distortion
    if (softClipEnabled) _applySoftClip(samples);

    // Effect 10: Hard Clipping at 60% threshold
    if (hardClipEnabled) _applyHardClip(samples);

    // Effect 2: Multi-tap Echo Delay (100ms + 250ms)
    if (echoEnabled) _applyEcho(samples);

    // Effect 9: Reverb (large room Schroeder network)
    if (reverbEnabled) _applyReverb(samples);

    // Effect 3: Crackle & Static Noise Injection
    if (crackleEnabled) _applyCrackleNoise(samples);

    // Effect 4: Voice Dropout (chunk-level silence)
    _dropoutActive = false;
    if (dropoutEnabled) _applyDropout(samples);

    // Effect 7: Pitch Wobble (±3 semitones random)
    if (pitchWobbleEnabled) {
      final wobbled = _pitch.process(samples);
      // Ensure output length matches input
      final padded = PcmUtils.padOrTrim(wobbled, input.length);
      totalSamplesProcessed += padded.length;
      totalChunksProcessed++;
      return PcmUtils.toInt16(padded);
    }

    totalSamplesProcessed += samples.length;
    totalChunksProcessed++;
    return PcmUtils.toInt16(samples);
  }

  // ═══════════════════════════ Effect 1: Gain Boost ═══════════════════════════
  void _applyGainBoost(List<double> samples) {
    for (int i = 0; i < samples.length; i++) {
      samples[i] = (samples[i] * gainFactor).clamp(-1.0, 1.0);
    }
  }

  // ═══════════════════════════ Effect 6: Bit Crusher ══════════════════════════
  void _applyBitCrusher(List<double> samples) {
    final steps = pow(2, bitDepth - 1).toDouble();
    for (int i = 0; i < samples.length; i++) {
      samples[i] = (samples[i] * steps).roundToDouble() / steps;
    }
  }

  // ══════════════════════════ Effect 5: Soft Clip ══════════════════════════════
  void _applySoftClip(List<double> samples) {
    for (int i = 0; i < samples.length; i++) {
      final driven = samples[i] * softDrive;
      samples[i] = PcmUtils.tanh(driven).clamp(-1.0, 1.0);
    }
  }

  // ══════════════════════════ Effect 10: Hard Clip ══════════════════════════════
  void _applyHardClip(List<double> samples) {
    for (int i = 0; i < samples.length; i++) {
      samples[i] = samples[i].clamp(-hardClipThreshold, hardClipThreshold);
      samples[i] /= hardClipThreshold;
    }
  }

  // ══════════════════════════ Effect 2: Multi-tap Echo ═════════════════════════
  void _applyEcho(List<double> samples) {
    for (int i = 0; i < samples.length; i++) {
      final echo100 = _echo.readAt(i, delayMs: 100);
      final echo250 = _echo.readAt(i, delayMs: 250);
      final mixed = (samples[i] * EffectDefaults.echoMixDry) +
          (echo100 * EffectDefaults.echoMix100) +
          (echo250 * EffectDefaults.echoMix250);
      _echo.write(i, samples[i]);
      samples[i] = mixed.clamp(-1.0, 1.0);
    }
    _echo.advance(samples.length);
  }

  // ══════════════════════════ Effect 9: Reverb ══════════════════════════════════
  void _applyReverb(List<double> samples) {
    final wet = _reverb.process(List<double>.from(samples));
    for (int i = 0; i < samples.length; i++) {
      samples[i] =
          ((1.0 - reverbMix) * samples[i] + reverbMix * wet[i]).clamp(-1.0, 1.0);
    }
  }

  // ══════════════════════════ Effect 3: Crackle Noise ═══════════════════════════
  void _applyCrackleNoise(List<double> samples) {
    for (int i = 0; i < samples.length; i++) {
      if (_rng.nextDouble() < crackleProb) {
        final impulse = _rng.nextBool() ? 1.0 : -1.0;
        samples[i] = (samples[i] + impulse * 0.85).clamp(-1.0, 1.0);
      }
    }
  }

  // Dropout state
  bool _dropoutActive = false;

  // ══════════════════════════ Effect 4: Dropout Silence ═════════════════════════
  void _applyDropout(List<double> samples) {
    _dropoutActive = _rng.nextDouble() < dropoutProb;
    if (_dropoutActive) {
      for (int i = 0; i < samples.length; i++) {
        samples[i] = 0.0;
      }
    }
  }

  /// Reset all internal processor states.
  void reset() {
    _bandpass.reset();
    _echo.reset();
    _reverb.reset();
    _pitch.reset();
    totalChunksProcessed = 0;
    totalSamplesProcessed = 0;
  }

  void dispose() {
    _echo.dispose();
    _reverb.dispose();
    _pitch.dispose();
  }
}
