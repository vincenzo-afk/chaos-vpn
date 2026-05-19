/// Immutable model for all DSP effect parameters.
/// Plain Dart class (no freezed/codegen dependency).
class EffectSettings {
  // ─── Master ───
  final bool masterEnabled;

  // ─── Gain Boost ───
  final bool gainEnabled;
  final double gainBoost;

  // ─── Echo Delay ───
  final bool echoEnabled;
  final double echoDelay;
  final double echoDecay;

  // ─── Reverb ───
  final bool reverbEnabled;
  final double reverbRoomSize;

  // ─── Crackle ───
  final bool crackleEnabled;
  final double crackleIntensity;

  // ─── Dropout ───
  final bool dropoutEnabled;
  final double dropoutRate;

  // ─── Fuzz (Soft Clip) ───
  final bool fuzzEnabled;
  final double fuzzDrive;

  // ─── Bit Crusher ───
  final bool bitCrushEnabled;
  final int bitCrushDepth;

  // ─── Pitch Wobble ───
  final bool pitchWobbleEnabled;
  final double pitchWobbleRange;

  // ─── Radio (Bandpass) ───
  final bool radioFilterEnabled;

  // ─── Hard Clip ───
  final bool clipEnabled;
  final double clipThreshold;

  // ─── Chorus / Flanger ───
  final bool chorusEnabled;
  final double chorusRate; // LFO rate in Hz (0.1–4.0)
  final double chorusDepth; // modulation depth in ms (1.0–20.0)
  final double chorusWetMix; // wet/dry mix (0.0–1.0)

  // ─── 5-Band Graphic EQ Gains (dB, -12 to +12) ───
  // Bands: 80 Hz, 300 Hz, 1000 Hz, 3400 Hz, 8000 Hz
  final List<double> eqBandGains;

  // ─── Convolution Reverb ───
  final bool convolutionReverbEnabled;
  final double convolutionReverbMix;

  // ─── Formant Shifter ───
  final bool formantShifterEnabled;
  final double formantShiftFactor; // 0.5–2.0 (1.0 = off)
  final double formantShiftMix;    // 0.0–1.0

  // ─── Low Power Mode ───
  final bool lowPowerMode;

  const EffectSettings({
    this.masterEnabled = true,
    this.gainEnabled = true,
    this.gainBoost = 4.0,
    this.echoEnabled = true,
    this.echoDelay = 100.0,
    this.echoDecay = 1.0,
    this.reverbEnabled = true,
    this.reverbRoomSize = 0.45,
    this.crackleEnabled = true,
    this.crackleIntensity = 0.03,
    this.dropoutEnabled = true,
    this.dropoutRate = 0.06,
    this.fuzzEnabled = true,
    this.fuzzDrive = 4.0,
    this.bitCrushEnabled = true,
    this.bitCrushDepth = 6,
    this.pitchWobbleEnabled = true,
    this.pitchWobbleRange = 3.0,
    this.radioFilterEnabled = true,
    this.clipEnabled = true,
    this.clipThreshold = 0.6,
    this.chorusEnabled = false,
    this.chorusRate = 0.25,
    this.chorusDepth = 10.0,
    this.chorusWetMix = 0.5,
    this.convolutionReverbEnabled = false,
    this.convolutionReverbMix = 0.45,
    this.formantShifterEnabled = false,
    this.formantShiftFactor = 1.0,
    this.formantShiftMix = 1.0,
    this.lowPowerMode = false,
    this.eqBandGains = const [0.0, 0.0, 0.0, 0.0, 0.0],
  });

  /// Create a copy with modified fields.
  EffectSettings copyWith({
    bool? masterEnabled,
    bool? gainEnabled,
    double? gainBoost,
    bool? echoEnabled,
    double? echoDelay,
    double? echoDecay,
    bool? reverbEnabled,
    double? reverbRoomSize,
    bool? crackleEnabled,
    double? crackleIntensity,
    bool? dropoutEnabled,
    double? dropoutRate,
    bool? fuzzEnabled,
    double? fuzzDrive,
    bool? bitCrushEnabled,
    int? bitCrushDepth,
    bool? pitchWobbleEnabled,
    double? pitchWobbleRange,
    bool? radioFilterEnabled,
    bool? clipEnabled,
    double? clipThreshold,
    bool? chorusEnabled,
    double? chorusRate,
    double? chorusDepth,
    double? chorusWetMix,
    List<double>? eqBandGains,
    bool? lowPowerMode,
    bool? convolutionReverbEnabled,
    double? convolutionReverbMix,
    bool? formantShifterEnabled,
    double? formantShiftFactor,
    double? formantShiftMix,
  }) {
    return EffectSettings(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      gainEnabled: gainEnabled ?? this.gainEnabled,
      gainBoost: gainBoost ?? this.gainBoost,
      echoEnabled: echoEnabled ?? this.echoEnabled,
      echoDelay: echoDelay ?? this.echoDelay,
      echoDecay: echoDecay ?? this.echoDecay,
      reverbEnabled: reverbEnabled ?? this.reverbEnabled,
      reverbRoomSize: reverbRoomSize ?? this.reverbRoomSize,
      crackleEnabled: crackleEnabled ?? this.crackleEnabled,
      crackleIntensity: crackleIntensity ?? this.crackleIntensity,
      dropoutEnabled: dropoutEnabled ?? this.dropoutEnabled,
      dropoutRate: dropoutRate ?? this.dropoutRate,
      fuzzEnabled: fuzzEnabled ?? this.fuzzEnabled,
      fuzzDrive: fuzzDrive ?? this.fuzzDrive,
      bitCrushEnabled: bitCrushEnabled ?? this.bitCrushEnabled,
      bitCrushDepth: bitCrushDepth ?? this.bitCrushDepth,
      pitchWobbleEnabled: pitchWobbleEnabled ?? this.pitchWobbleEnabled,
      pitchWobbleRange: pitchWobbleRange ?? this.pitchWobbleRange,
      radioFilterEnabled: radioFilterEnabled ?? this.radioFilterEnabled,
      clipEnabled: clipEnabled ?? this.clipEnabled,
      clipThreshold: clipThreshold ?? this.clipThreshold,
      chorusEnabled: chorusEnabled ?? this.chorusEnabled,
      chorusRate: chorusRate ?? this.chorusRate,
      chorusDepth: chorusDepth ?? this.chorusDepth,
      chorusWetMix: chorusWetMix ?? this.chorusWetMix,
      eqBandGains: eqBandGains ?? this.eqBandGains,
      lowPowerMode: lowPowerMode ?? this.lowPowerMode,
      convolutionReverbEnabled:
          convolutionReverbEnabled ?? this.convolutionReverbEnabled,
      convolutionReverbMix:
          convolutionReverbMix ?? this.convolutionReverbMix,
      formantShifterEnabled:
          formantShifterEnabled ?? this.formantShifterEnabled,
      formantShiftFactor:
          formantShiftFactor ?? this.formantShiftFactor,
      formantShiftMix:
          formantShiftMix ?? this.formantShiftMix,
    );
  }

  /// Number of total available effects.
  static const int totalEffects = 13;

  /// Number of enabled effects.
  int get activeCount => [
        if (gainEnabled && gainBoost > 0 && masterEnabled) 1,
        if (echoEnabled) 1,
        if (reverbEnabled) 1,
        if (crackleEnabled) 1,
        if (dropoutEnabled) 1,
        if (fuzzEnabled) 1,
        if (bitCrushEnabled) 1,
        if (pitchWobbleEnabled) 1,
        if (radioFilterEnabled) 1,
        if (clipEnabled) 1,
        if (chorusEnabled) 1,
        if (convolutionReverbEnabled) 1,
        if (formantShifterEnabled) 1,
      ].length;

  // ─── Serialization ───

  Map<String, dynamic> toJson() => {
        'masterEnabled': masterEnabled,
        'gainEnabled': gainEnabled,
        'gainBoost': gainBoost,
        'echoEnabled': echoEnabled,
        'echoDelay': echoDelay,
        'echoDecay': echoDecay,
        'reverbEnabled': reverbEnabled,
        'reverbRoomSize': reverbRoomSize,
        'crackleEnabled': crackleEnabled,
        'crackleIntensity': crackleIntensity,
        'dropoutEnabled': dropoutEnabled,
        'dropoutRate': dropoutRate,
        'fuzzEnabled': fuzzEnabled,
        'fuzzDrive': fuzzDrive,
        'bitCrushEnabled': bitCrushEnabled,
        'bitCrushDepth': bitCrushDepth,
        'pitchWobbleEnabled': pitchWobbleEnabled,
        'pitchWobbleRange': pitchWobbleRange,
        'radioFilterEnabled': radioFilterEnabled,
        'clipEnabled': clipEnabled,
        'clipThreshold': clipThreshold,
        'chorusEnabled': chorusEnabled,
        'chorusRate': chorusRate,
        'chorusDepth': chorusDepth,
        'chorusWetMix': chorusWetMix,
        'eqBandGains': eqBandGains,
        'lowPowerMode': lowPowerMode,
        'convolutionReverbEnabled': convolutionReverbEnabled,
        'convolutionReverbMix': convolutionReverbMix,
        'formantShifterEnabled': formantShifterEnabled,
        'formantShiftFactor': formantShiftFactor,
        'formantShiftMix': formantShiftMix,
      };

  static EffectSettings fromJson(Map<String, dynamic> json) {
    return EffectSettings(
      masterEnabled: json['masterEnabled'] as bool? ?? true,
      gainEnabled: json['gainEnabled'] as bool? ?? true,
      gainBoost: (json['gainBoost'] as num?)?.toDouble() ?? 4.0,
      echoEnabled: json['echoEnabled'] as bool? ?? true,
      echoDelay: (json['echoDelay'] as num?)?.toDouble() ?? 100.0,
      echoDecay: (json['echoDecay'] as num?)?.toDouble() ?? 1.0,
      reverbEnabled: json['reverbEnabled'] as bool? ?? true,
      reverbRoomSize: (json['reverbRoomSize'] as num?)?.toDouble() ?? 0.45,
      crackleEnabled: json['crackleEnabled'] as bool? ?? true,
      crackleIntensity:
          (json['crackleIntensity'] as num?)?.toDouble() ?? 0.03,
      dropoutEnabled: json['dropoutEnabled'] as bool? ?? true,
      dropoutRate: (json['dropoutRate'] as num?)?.toDouble() ?? 0.06,
      fuzzEnabled: json['fuzzEnabled'] as bool? ?? true,
      fuzzDrive: (json['fuzzDrive'] as num?)?.toDouble() ?? 4.0,
      bitCrushEnabled: json['bitCrushEnabled'] as bool? ?? true,
      bitCrushDepth: json['bitCrushDepth'] as int? ?? 6,
      pitchWobbleEnabled: json['pitchWobbleEnabled'] as bool? ?? true,
      pitchWobbleRange:
          (json['pitchWobbleRange'] as num?)?.toDouble() ?? 3.0,
      radioFilterEnabled: json['radioFilterEnabled'] as bool? ?? true,
      clipEnabled: json['clipEnabled'] as bool? ?? true,
      clipThreshold: (json['clipThreshold'] as num?)?.toDouble() ?? 0.6,
      chorusEnabled: json['chorusEnabled'] as bool? ?? false,
      chorusRate: (json['chorusRate'] as num?)?.toDouble() ?? 0.25,
      chorusDepth: (json['chorusDepth'] as num?)?.toDouble() ?? 10.0,
      chorusWetMix: (json['chorusWetMix'] as num?)?.toDouble() ?? 0.5,
      eqBandGains: json['eqBandGains'] != null
          ? (json['eqBandGains'] as List<dynamic>)
              .map((e) => (e as num).toDouble())
              .toList()
          : [0.0, 0.0, 0.0, 0.0, 0.0],
      lowPowerMode: json['lowPowerMode'] as bool? ?? false,
      convolutionReverbEnabled:
          json['convolutionReverbEnabled'] as bool? ?? false,
      convolutionReverbMix:
          (json['convolutionReverbMix'] as num?)?.toDouble() ?? 0.45,
      formantShifterEnabled:
          json['formantShifterEnabled'] as bool? ?? false,
      formantShiftFactor:
          (json['formantShiftFactor'] as num?)?.toDouble() ?? 1.0,
      formantShiftMix:
          (json['formantShiftMix'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EffectSettings &&
          runtimeType == other.runtimeType &&
          masterEnabled == other.masterEnabled &&
          gainEnabled == other.gainEnabled &&
          gainBoost == other.gainBoost &&
          echoEnabled == other.echoEnabled &&
          echoDelay == other.echoDelay &&
          echoDecay == other.echoDecay &&
          reverbEnabled == other.reverbEnabled &&
          reverbRoomSize == other.reverbRoomSize &&
          crackleEnabled == other.crackleEnabled &&
          crackleIntensity == other.crackleIntensity &&
          dropoutEnabled == other.dropoutEnabled &&
          dropoutRate == other.dropoutRate &&
          fuzzEnabled == other.fuzzEnabled &&
          fuzzDrive == other.fuzzDrive &&
          bitCrushEnabled == other.bitCrushEnabled &&
          bitCrushDepth == other.bitCrushDepth &&
          pitchWobbleEnabled == other.pitchWobbleEnabled &&
          pitchWobbleRange == other.pitchWobbleRange &&
          radioFilterEnabled == other.radioFilterEnabled &&
          clipEnabled == other.clipEnabled &&
          clipThreshold == other.clipThreshold &&
          chorusEnabled == other.chorusEnabled &&
          chorusRate == other.chorusRate &&
          chorusDepth == other.chorusDepth &&
          chorusWetMix == other.chorusWetMix &&
          _listEquals(eqBandGains, other.eqBandGains) &&
          lowPowerMode == other.lowPowerMode &&
          convolutionReverbEnabled == other.convolutionReverbEnabled &&
          convolutionReverbMix == other.convolutionReverbMix &&
          formantShifterEnabled == other.formantShifterEnabled &&
          formantShiftFactor == other.formantShiftFactor &&
          formantShiftMix == other.formantShiftMix;

  @override
  int get hashCode => Object.hashAll([
        masterEnabled,
        gainEnabled,
        gainBoost,
        echoEnabled,
        echoDelay,
        echoDecay,
        reverbEnabled,
        reverbRoomSize,
        crackleEnabled,
        crackleIntensity,
        dropoutEnabled,
        dropoutRate,
        fuzzEnabled,
        fuzzDrive,
        bitCrushEnabled,
        bitCrushDepth,
        pitchWobbleEnabled,
        pitchWobbleRange,
        radioFilterEnabled,
        clipEnabled,
        clipThreshold,
        chorusEnabled,
        chorusRate,
        chorusDepth,
        chorusWetMix,
        ...eqBandGains,
        lowPowerMode,
        convolutionReverbEnabled,
        convolutionReverbMix,
        formantShifterEnabled,
        formantShiftFactor,
        formantShiftMix,
      ]);

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'EffectSettings(${toJson()})';
}
