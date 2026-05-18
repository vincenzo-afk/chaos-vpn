/// Effect parameter model — holds all adjustable DSP values.
class EffectSettings {
  final double gainFactor;
  final double crackleProb;
  final double dropoutProb;
  final double softDrive;
  final int bitDepth;
  final double hardClipThreshold;
  final double reverbMix;
  final double echoMixDry;
  final double echoMix100;
  final double echoMix250;
  final bool bandpassEnabled;
  final bool echoEnabled;
  final bool reverbEnabled;
  final bool crackleEnabled;
  final bool dropoutEnabled;
  final bool softClipEnabled;
  final bool hardClipEnabled;
  final bool bitCrushEnabled;
  final bool pitchWobbleEnabled;
  final bool gainEnabled;

  const EffectSettings({
    this.gainFactor = 4.0,
    this.crackleProb = 0.03,
    this.dropoutProb = 0.06,
    this.softDrive = 4.0,
    this.bitDepth = 6,
    this.hardClipThreshold = 0.60,
    this.reverbMix = 0.45,
    this.echoMixDry = 0.70,
    this.echoMix100 = 0.40,
    this.echoMix250 = 0.25,
    this.bandpassEnabled = true,
    this.echoEnabled = true,
    this.reverbEnabled = true,
    this.crackleEnabled = true,
    this.dropoutEnabled = true,
    this.softClipEnabled = true,
    this.hardClipEnabled = true,
    this.bitCrushEnabled = true,
    this.pitchWobbleEnabled = true,
    this.gainEnabled = true,
  });

  EffectSettings copyWith({
    double? gainFactor,
    double? crackleProb,
    double? dropoutProb,
    double? softDrive,
    int? bitDepth,
    double? hardClipThreshold,
    double? reverbMix,
    double? echoMixDry,
    double? echoMix100,
    double? echoMix250,
    bool? bandpassEnabled,
    bool? echoEnabled,
    bool? reverbEnabled,
    bool? crackleEnabled,
    bool? dropoutEnabled,
    bool? softClipEnabled,
    bool? hardClipEnabled,
    bool? bitCrushEnabled,
    bool? pitchWobbleEnabled,
    bool? gainEnabled,
  }) {
    return EffectSettings(
      gainFactor: gainFactor ?? this.gainFactor,
      crackleProb: crackleProb ?? this.crackleProb,
      dropoutProb: dropoutProb ?? this.dropoutProb,
      softDrive: softDrive ?? this.softDrive,
      bitDepth: bitDepth ?? this.bitDepth,
      hardClipThreshold: hardClipThreshold ?? this.hardClipThreshold,
      reverbMix: reverbMix ?? this.reverbMix,
      echoMixDry: echoMixDry ?? this.echoMixDry,
      echoMix100: echoMix100 ?? this.echoMix100,
      echoMix250: echoMix250 ?? this.echoMix250,
      bandpassEnabled: bandpassEnabled ?? this.bandpassEnabled,
      echoEnabled: echoEnabled ?? this.echoEnabled,
      reverbEnabled: reverbEnabled ?? this.reverbEnabled,
      crackleEnabled: crackleEnabled ?? this.crackleEnabled,
      dropoutEnabled: dropoutEnabled ?? this.dropoutEnabled,
      softClipEnabled: softClipEnabled ?? this.softClipEnabled,
      hardClipEnabled: hardClipEnabled ?? this.hardClipEnabled,
      bitCrushEnabled: bitCrushEnabled ?? this.bitCrushEnabled,
      pitchWobbleEnabled: pitchWobbleEnabled ?? this.pitchWobbleEnabled,
      gainEnabled: gainEnabled ?? this.gainEnabled,
    );
  }

  /// Reset all settings to defaults.
  static const EffectSettings defaults = EffectSettings();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EffectSettings &&
          runtimeType == other.runtimeType &&
          gainFactor == other.gainFactor &&
          crackleProb == other.crackleProb &&
          dropoutProb == other.dropoutProb &&
          softDrive == other.softDrive &&
          bitDepth == other.bitDepth &&
          hardClipThreshold == other.hardClipThreshold &&
          reverbMix == other.reverbMix &&
          bandpassEnabled == other.bandpassEnabled &&
          echoEnabled == other.echoEnabled &&
          reverbEnabled == other.reverbEnabled &&
          crackleEnabled == other.crackleEnabled &&
          dropoutEnabled == other.dropoutEnabled &&
          softClipEnabled == other.softClipEnabled &&
          hardClipEnabled == other.hardClipEnabled &&
          bitCrushEnabled == other.bitCrushEnabled &&
          pitchWobbleEnabled == other.pitchWobbleEnabled &&
          gainEnabled == other.gainEnabled;

  @override
  int get hashCode => Object.hash(
        gainFactor,
        crackleProb,
        dropoutProb,
        softDrive,
        bitDepth,
        hardClipThreshold,
        reverbMix,
        bandpassEnabled,
        echoEnabled,
        reverbEnabled,
        crackleEnabled,
        dropoutEnabled,
        softClipEnabled,
        hardClipEnabled,
        bitCrushEnabled,
        pitchWobbleEnabled,
        gainEnabled,
      );
}
