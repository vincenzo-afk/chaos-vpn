import 'dart:math';
import 'dart:typed_data';
import 'bandpass_filter.dart';
import 'echo_buffer.dart';
import 'reverb_processor.dart';
import 'pitch_wobble.dart';
import 'pcm_utils.dart';
import 'graphic_eq.dart';
import 'chorus_flanger.dart';
import 'convolution_reverb.dart';
import 'formant_shifter.dart';
import 'vocoder_scream.dart';
import 'telephone_overload.dart';
import 'reverse_glitch.dart';
import 'stutter_freezer.dart';
import 'bit_scrambler.dart';
import '../models/effect_settings.dart';
import '../utils/constants.dart';

/// Master DSP effect engine — applies all 10 core chaos effects to raw PCM chunks.
/// Input: Int16List of raw mic samples (16-bit, mono, 16000 Hz)
/// Output: Int16List of processed samples ready for virtual mic injection.
///
/// Pipeline order (matching README2.MD Table of Effects):
///   1. Gain Boost → 2. Radio/Telephone Bandpass → 3. Bit Crusher
///   4. Soft Clip/Overdrive → 5. Hard Clip → 6. Echo Delay
///   7. Room Reverb → 8. Crackle/Static → 9. Voice Dropout → 10. Pitch Wobble
///
/// Additional Phase 3 effects (disabled by default): GraphicEQ, Chorus/Flanger,
/// Convolution Reverb, Formant Shifter — slotted between Hard Clip and Echo.
class EffectEngine {
  final int sampleRate;
  final Random _rng = Random();

  // Effect parameters (adjustable from UI)
  double gainBoost = EffectDefaults.gainBoost;
  double crackleIntensity = EffectDefaults.crackleIntensity;
  double dropoutRate = EffectDefaults.dropoutRate;
  double fuzzDrive = EffectDefaults.fuzzDrive;
  int bitCrushDepth = EffectDefaults.bitCrushDepth;
  double clipThreshold = EffectDefaults.clipThreshold;
  double reverbRoomSize = EffectDefaults.reverbRoomSize;
  double echoDelay = EffectDefaults.echoDelay;
  double echoDecay = EffectDefaults.echoDecay;
  double pitchWobbleRange = EffectDefaults.pitchWobbleRange;

  // Effect toggle flags
  bool masterEnabled = true;
  bool gainEnabled = true;
  bool radioFilterEnabled = true;
  bool bitCrushEnabled = true;
  bool fuzzEnabled = true;
  bool clipEnabled = true;
  bool echoEnabled = true;
  bool reverbEnabled = true;
  bool crackleEnabled = true;
  bool dropoutEnabled = true;
  bool pitchWobbleEnabled = true;

  // Low power mode: disables most expensive effects (reverb, pitch wobble)
  bool lowPowerMode = false;

  // Echo pre-warm flag: ensures echo buffer has signal on first call
  bool _echoPreWarmed = false;

  // Internal processors
  late final BandpassFilter _bandpass;
  late final EchoBuffer _echo;
  late final ReverbProcessor _reverb;
  late final PitchWobble _pitch;
  late final GraphicEQ _graphicEq;
  late final ChorusFlanger _chorus;
  late final ConvolutionReverb _convolutionReverb;
  late final FormantShifter _formantShifter;
  late final VocoderScream _vocoderScream;
  late final TelephoneOverload _telephoneOverload;
  late final ReverseGlitch _reverseGlitch;
  late final StutterFreezer _stutterFreezer;
  late final BitScrambler _bitScrambler;

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
      maxDelayMs: AudioConstants.echoMaxDelayMs,
    );
    _reverb = ReverbProcessor(sampleRate: sampleRate);
    _pitch = PitchWobble(sampleRate: sampleRate);
    _graphicEq = GraphicEQ(sampleRate: sampleRate);
    _chorus = ChorusFlanger(sampleRate: sampleRate);
    _convolutionReverb = ConvolutionReverb(sampleRate: sampleRate);
    _formantShifter = FormantShifter(sampleRate: sampleRate);
    _vocoderScream = VocoderScream(sampleRate: sampleRate);
    _telephoneOverload = TelephoneOverload(sampleRate: sampleRate);
    _reverseGlitch = ReverseGlitch(sampleRate: sampleRate);
    _stutterFreezer = StutterFreezer(sampleRate: sampleRate);
    _bitScrambler = BitScrambler(sampleRate: sampleRate);
  }

  /// Update all effect parameters from a settings object.
  void updateFromSettings(EffectSettings settings) {
    masterEnabled = settings.masterEnabled;
    gainBoost = settings.gainBoost;
    crackleIntensity = settings.crackleIntensity;
    dropoutRate = settings.dropoutRate;
    fuzzDrive = settings.fuzzDrive;
    bitCrushDepth = settings.bitCrushDepth;
    clipThreshold = settings.clipThreshold;
    reverbRoomSize = settings.reverbRoomSize;
    echoDelay = settings.echoDelay;
    echoDecay = settings.echoDecay;
    gainEnabled = settings.gainEnabled && settings.gainBoost > 0;
    radioFilterEnabled = settings.radioFilterEnabled;
    bitCrushEnabled = settings.bitCrushEnabled;
    fuzzEnabled = settings.fuzzEnabled;
    clipEnabled = settings.clipEnabled;
    echoEnabled = settings.echoEnabled;
    reverbEnabled = settings.reverbEnabled;
    crackleEnabled = settings.crackleEnabled;
    dropoutEnabled = settings.dropoutEnabled;
    pitchWobbleEnabled = settings.pitchWobbleEnabled;
    lowPowerMode = settings.lowPowerMode;

    // Chorus params
    _chorus.enabled = settings.chorusEnabled;
    _chorus.rate = settings.chorusRate;
    _chorus.depth = settings.chorusDepth;
    _chorus.wetMix = settings.chorusWetMix;

    // Graphic EQ band gains
    for (int i = 0; i < settings.eqBandGains.length && i < 5; i++) {
      _graphicEq.setBand(i, settings.eqBandGains[i]);
    }

    // Convolution Reverb params
    _convolutionReverb.enabled = settings.convolutionReverbEnabled;
    _convolutionReverb.wetMix = settings.convolutionReverbMix;

    // Formant Shifter params
    _formantShifter.enabled = settings.formantShifterEnabled;
    _formantShifter.shiftFactor = settings.formantShiftFactor;
    _formantShifter.mix = settings.formantShiftMix;

    // Chaos Overload effects (v1.1) — five destructive stages
    _vocoderScream.enabled = settings.vocoderScreamEnabled;
    _vocoderScream.carrierFrequency = settings.vocoderCarrierFreq;
    _vocoderScream.sweepRate = settings.vocoderSweepRate;

    _telephoneOverload.enabled = settings.telephoneOverloadEnabled;
    _telephoneOverload.centerFrequency = settings.telephoneOverloadFreq;
    _telephoneOverload.drive = settings.telephoneOverloadDrive;

    _reverseGlitch.enabled = settings.reverseGlitchEnabled;
    _reverseGlitch.reversalProbability = settings.reverseGlitchProbability;
    _reverseGlitch.windowLengthMs = settings.reverseGlitchWindowMs;

    _stutterFreezer.enabled = settings.stutterFreezeEnabled;
    _stutterFreezer.freezeProbability = settings.stutterFreezeProbability;
    _stutterFreezer.freezeDurationMs = settings.stutterFreezeDurationMs;

    _bitScrambler.enabled = settings.bitScramblerEnabled;
    _bitScrambler.scrambleDepth = settings.bitScrambleDepth;
    _bitScrambler.scrambleProbability = settings.bitScrambleProbability;

    // Low power mode overrides: disable reverb + pitch (most CPU-heavy)
    if (lowPowerMode) {
      reverbEnabled = false;
      pitchWobbleEnabled = false;
    }
  }

  /// Process one chunk of raw PCM samples through all DSP effects.
  ///
  /// Pipeline order (matching BOTH README.md & README2.MD):
  ///   1. Gain Boost
  ///   2. Radio/Telephone Bandpass Filter (300-3400 Hz)
  ///      → GraphicEQ (Phase 3, runs alongside bandpass)
  ///   3. Bit Crusher
  ///   4. Soft Clip / Overdrive
  ///   5. Hard Clip
  ///      → Chorus/Flanger (Phase 3)
  ///   6. Echo Delay (multi-tap)
  ///   7. Room Reverb
  ///      → Convolution Reverb (Phase 3)
  ///   8. Crackle / Static Noise
  ///   9. Voice Dropout
  ///      → Formant Shifter (Phase 3)
  ///   10. Pitch Wobble
  Int16List process(Int16List input) {
    if (input.isEmpty) return input;

    // Convert to normalized double for processing
    final samples = PcmUtils.toDoubles(input);

    // Master Enable gate: if master is OFF, bypass ALL effects
    if (!masterEnabled) {
      totalSamplesProcessed += samples.length;
      totalChunksProcessed++;
      return PcmUtils.toInt16(samples);
    }

    // ────── Stage 1: Gain Boost (3x–5x volume amplification) ──────
    if (gainEnabled) _applyGainBoost(samples);

    // ────── Stage 2: Radio / Telephone Bandpass Filter (300–3400 Hz) ──────
    if (radioFilterEnabled) _bandpass.process(samples);
    // GraphicEQ runs alongside but only when the radio/telephone chain
    // is enabled — previously it always ran, applying EQ even when the
    // chain was toggled off.
    _graphicEq.setRadioFilter(radioFilterEnabled);
    if (radioFilterEnabled) _graphicEq.process(samples);

    // ────── Stage 3: Bit Crusher (reduced bit-depth quantization) ──────
    if (bitCrushEnabled) _applyBitCrusher(samples);

    // ────── Stage 4: Soft Clip / Overdrive Distortion ──────
    if (fuzzEnabled) _applySoftClip(samples);

    // ────── Stage 5: Hard Clipping at threshold ──────
    if (clipEnabled) _applyHardClip(samples);

    // ────── Stage 5b: Chorus / Flanger (Phase 3 — modulation) ──────
    if (_chorus.enabled) _chorus.process(samples);

    // ────── Stage 6: Multi-tap Echo Delay ──────
    if (echoEnabled) _applyEcho(samples);

    // Mark echo as pre-warmed after first chunk processed
    if (!_echoPreWarmed && echoEnabled) _echoPreWarmed = true;

    // ────── Stage 7: Room Reverb (Schroeder network) ──────
    if (reverbEnabled) _applyReverb(samples);

    // ────── Stage 7b: Convolution Reverb (Phase 3 — FFT-based) ──────
    if (_convolutionReverb.enabled) {
      _convolutionReverb.process(samples);
    }

    // ────── Stage 8: Crackle & Static Noise Injection ──────
    if (crackleEnabled) _applyCrackleNoise(samples);

    // ────── Stage 9: Voice Dropout (chunk-level silence) ──────
    if (dropoutEnabled) _applyDropout(samples);

    // ────── Stage 9b: Formant Shifter (Phase 3 — LPC-based) ──────
    if (_formantShifter.enabled) {
      _formantShifter.process(samples);
    }

    // ────── Stage 11: Vocoder Scream (harmonically-rich ring modulation) ──────
    if (_vocoderScream.enabled) _vocoderScream.process(samples);

    // ────── Stage 12: Telephone Overload (resonant crunch) ──────
    if (_telephoneOverload.enabled) _telephoneOverload.process(samples);

    // ────── Stage 13: Reverse Glitch (tape-reverse fragments) ──────
    if (_reverseGlitch.enabled) _reverseGlitch.process(samples);

    // ────── Stage 14: Stutter Freeze (broken-record repeats) ──────
    if (_stutterFreezer.enabled) _stutterFreezer.process(samples);

    // ────── Stage 15: Bit Scrambler (raw data corruption) ──────
    if (_bitScrambler.enabled) _bitScrambler.process(samples);

    // ────── Stage 10b: Pitch Wobble (randomized resampling) ──────
    if (pitchWobbleEnabled) {
      _pitch.range = pitchWobbleRange;
      final wobbled = _pitch.process(samples);
      final padded = PcmUtils.padOrTrim(wobbled, input.length);
      totalSamplesProcessed += padded.length;
      totalChunksProcessed++;
      return PcmUtils.toInt16(padded);
    }

    totalSamplesProcessed += samples.length;
    totalChunksProcessed++;
    return PcmUtils.toInt16(samples);
  }

  /// Access the GraphicEQ module for fine-grained band control.
  GraphicEQ get graphicEq => _graphicEq;

  /// Access the ChorusFlanger module.
  ChorusFlanger get chorus => _chorus;

  /// Access the ConvolutionReverb module.
  ConvolutionReverb get convolutionReverb => _convolutionReverb;

  /// Access the FormantShifter module.
  FormantShifter get formantShifter => _formantShifter;

  /// Access the VocoderScream module.
  VocoderScream get vocoderScream => _vocoderScream;

  /// Access the TelephoneOverload module.
  TelephoneOverload get telephoneOverload => _telephoneOverload;

  /// Access the ReverseGlitch module.
  ReverseGlitch get reverseGlitch => _reverseGlitch;

  /// Access the StutterFreezer module.
  StutterFreezer get stutterFreezer => _stutterFreezer;

  /// Access the BitScrambler module.
  BitScrambler get bitScrambler => _bitScrambler;

  // ═══════════════════════════ Effect 1: Gain Boost ═══════════════════════════
  void _applyGainBoost(List<double> samples) {
    for (int i = 0; i < samples.length; i++) {
      samples[i] = (samples[i] * gainBoost).clamp(-1.0, 1.0);
    }
  }

  // ═══════════════════════════ Effect 6: Bit Crusher ══════════════════════════
  void _applyBitCrusher(List<double> samples) {
    final steps = pow(2, bitCrushDepth - 1).toDouble();
    for (int i = 0; i < samples.length; i++) {
      samples[i] = (samples[i] * steps).roundToDouble() / steps;
    }
  }

  // ══════════════════════════ Effect 5: Soft Clip ══════════════════════════════
  void _applySoftClip(List<double> samples) {
    for (int i = 0; i < samples.length; i++) {
      final driven = samples[i] * fuzzDrive;
      samples[i] = PcmUtils.tanh(driven).clamp(-1.0, 1.0);
    }
  }

  // ══════════════════════════ Effect 10: Hard Clip ══════════════════════════════
  void _applyHardClip(List<double> samples) {
    // Bug fix: the previous implementation clamped to the threshold and then
    // divided by it, mapping the threshold back to ±1.0 — which amplified the
    // signal to full scale AFTER clipping, defeating the purpose of a hard
    // clip and causing harsh square-wave distortion at maximum amplitude.
    // Hard clipping now simply flattens peaks at [clipThreshold] and leaves
    // the overall level in place; final limiting happens at PCM conversion.
    for (int i = 0; i < samples.length; i++) {
      samples[i] = samples[i].clamp(-clipThreshold, clipThreshold);
    }
  }

  // ══════════════════════════ Effect 2: Multi-tap Echo ═════════════════════════
  /// Configurable multi-tap echo. Primary delay at [echoDelay] ms,
  /// second tap at [echoDelay * 2.5] ms (clamped to buffer capacity).
  /// [echoDecay] scales the wet mix volume (1.0 = full, 0.0 = none).
  void _applyEcho(List<double> samples) {
    final tap1Delay = echoDelay.round();
    final tap2Delay = (echoDelay * 2.5).round().clamp(0, AudioConstants.echoMaxDelayMs);
    final wet = echoDecay;

    // Pre-warm: on first call, prime the echo buffer with input signal
    // so the first echo taps produce audible output instead of silence.
    if (!_echoPreWarmed) {
      for (int i = 0; i < samples.length; i++) {
        _echo.write(i, samples[i]);
      }
      _echo.advance(samples.length);
    }

    for (int i = 0; i < samples.length; i++) {
      final echoTap1 = _echo.readAt(i, delayMs: tap1Delay);
      final echoTap2 = _echo.readAt(i, delayMs: tap2Delay);
      final mixed = (samples[i] * EffectDefaults.echoMixDry) +
          (echoTap1 * EffectDefaults.echoMix100 * wet) +
          (echoTap2 * EffectDefaults.echoMix250 * wet);
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
          ((1.0 - reverbRoomSize) * samples[i] + reverbRoomSize * wet[i]).clamp(-1.0, 1.0);
    }
  }

  // ══════════════════════════ Effect 3: Crackle Noise ═══════════════════════════
  void _applyCrackleNoise(List<double> samples) {
    for (int i = 0; i < samples.length; i++) {
      if (_rng.nextDouble() < crackleIntensity) {
        final impulse = _rng.nextBool() ? 1.0 : -1.0;
        samples[i] = (samples[i] + impulse * 0.85).clamp(-1.0, 1.0);
      }
    }
  }

  // ══════════════════════════ Effect 4: Dropout Silence ═════════════════════════
  void _applyDropout(List<double> samples) {
    if (_rng.nextDouble() < dropoutRate) {
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
    _graphicEq.reset();
    _chorus.reset();
    _convolutionReverb.reset();
    _formantShifter.reset();
    _vocoderScream.reset();
    _telephoneOverload.reset();
    _reverseGlitch.reset();
    _stutterFreezer.reset();
    _bitScrambler.reset();
    _echoPreWarmed = false;
    totalChunksProcessed = 0;
    totalSamplesProcessed = 0;
  }

  void dispose() {
    _echo.dispose();
    _reverb.dispose();
    _pitch.dispose();
    _graphicEq.dispose();
    _chorus.dispose();
    _convolutionReverb.dispose();
    _formantShifter.dispose();
    _vocoderScream.dispose();
    _telephoneOverload.dispose();
    _reverseGlitch.dispose();
    _stutterFreezer.dispose();
    _bitScrambler.dispose();
  }
}
