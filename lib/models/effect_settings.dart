import 'package:freezed_annotation/freezed_annotation.dart';

part 'effect_settings.freezed.dart';
part 'effect_settings.g.dart';

/// Immutable model for all 20 DSP effect parameters.
@freezed
class EffectSettings with _$EffectSettings {
  const EffectSettings._();

  const factory EffectSettings({
    // ─── Master ───
    @Default(true) bool masterEnabled,

    // ─── Gain Boost ───
    @Default(4.0) double gainBoost,

    // ─── Echo Delay ───
    @Default(false) bool echoEnabled,
    @Default(100.0) double echoDelay,
    @Default(1.0) double echoDecay,

    // ─── Reverb ───
    @Default(false) bool reverbEnabled,
    @Default(0.45) double reverbRoomSize,

    // ─── Crackle ───
    @Default(false) bool crackleEnabled,
    @Default(0.03) double crackleIntensity,

    // ─── Dropout ───
    @Default(false) bool dropoutEnabled,
    @Default(0.06) double dropoutRate,

    // ─── Fuzz (Soft Clip) ───
    @Default(false) bool fuzzEnabled,
    @Default(4.0) double fuzzDrive,

    // ─── Bit Crusher ───
    @Default(false) bool bitCrushEnabled,
    @Default(6) int bitCrushDepth,

    // ─── Pitch Wobble ───
    @Default(false) bool pitchWobbleEnabled,
    @Default(3.0) double pitchWobbleRange,

    // ─── Radio (Bandpass) ───
    @Default(false) bool radioFilterEnabled,

    // ─── Hard Clip ───
    @Default(false) bool clipEnabled,
    @Default(0.6) double clipThreshold,
  }) = _EffectSettings;

  factory EffectSettings.fromJson(Map<String, dynamic> json) =>
      _$EffectSettingsFromJson(json);

  /// Number of enabled effects.
  int get activeCount => [
        if (gainBoost > 0 && masterEnabled) 1,
        if (echoEnabled) 1,
        if (reverbEnabled) 1,
        if (crackleEnabled) 1,
        if (dropoutEnabled) 1,
        if (fuzzEnabled) 1,
        if (bitCrushEnabled) 1,
        if (pitchWobbleEnabled) 1,
        if (radioFilterEnabled) 1,
        if (clipEnabled) 1,
      ].length;
}
