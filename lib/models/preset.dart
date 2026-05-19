/// A named snapshot of all effect settings that can be saved and loaded.
class Preset {
  final String name;
  final String description;
  final double gainBoost;
  final bool echoEnabled;
  final double echoDelay;
  final double echoDecay;
  final bool reverbEnabled;
  final double reverbRoomSize;
  final bool crackleEnabled;
  final double crackleIntensity;
  final bool dropoutEnabled;
  final double dropoutRate;
  final bool fuzzEnabled;
  final double fuzzDrive;
  final bool bitCrushEnabled;
  final int bitCrushDepth;
  final bool pitchWobbleEnabled;
  final double pitchWobbleRange;
  final bool radioFilterEnabled;
  final bool clipEnabled;
  final double clipThreshold;
  final bool lowPowerMode;
  // Chorus / Flanger
  final bool chorusEnabled;
  final double chorusRate;
  final double chorusDepth;
  final double chorusWetMix;
  // 5-Band Graphic EQ gains (in dB, -12 to +12)
  final List<double> eqBandGains;
  // Convolution Reverb
  final bool convolutionReverbEnabled;
  final double convolutionReverbMix;
  // Formant Shifter
  final bool formantShifterEnabled;
  final double formantShiftFactor;
  final double formantShiftMix;

  const Preset({
    required this.name,
    this.description = '',
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
    this.lowPowerMode = false,
    this.chorusEnabled = false,
    this.chorusRate = 0.25,
    this.chorusDepth = 10.0,
    this.chorusWetMix = 0.5,
    this.eqBandGains = const [0.0, 0.0, 0.0, 0.0, 0.0],
    this.convolutionReverbEnabled = false,
    this.convolutionReverbMix = 0.45,
    this.formantShifterEnabled = false,
    this.formantShiftFactor = 1.0,
    this.formantShiftMix = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
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
        'lowPowerMode': lowPowerMode,
        'chorusEnabled': chorusEnabled,
        'chorusRate': chorusRate,
        'chorusDepth': chorusDepth,
        'chorusWetMix': chorusWetMix,
        'eqBandGains': eqBandGains,
    'convolutionReverbEnabled': convolutionReverbEnabled,
    'convolutionReverbMix': convolutionReverbMix,
    'formantShifterEnabled': formantShifterEnabled,
    'formantShiftFactor': formantShiftFactor,
    'formantShiftMix': formantShiftMix,
      };

  factory Preset.fromJson(Map<String, dynamic> json) => Preset(
        name: json['name'] as String? ?? 'Unnamed',
        description: json['description'] as String? ?? '',
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
        lowPowerMode: json['lowPowerMode'] as bool? ?? false,
        chorusEnabled: json['chorusEnabled'] as bool? ?? false,
        chorusRate: (json['chorusRate'] as num?)?.toDouble() ?? 0.25,
        chorusDepth: (json['chorusDepth'] as num?)?.toDouble() ?? 10.0,
        chorusWetMix: (json['chorusWetMix'] as num?)?.toDouble() ?? 0.5,
        eqBandGains: json['eqBandGains'] != null
            ? (json['eqBandGains'] as List<dynamic>)
                .map((e) => (e as num).toDouble())
                .toList()
            : [0.0, 0.0, 0.0, 0.0, 0.0],
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Preset &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          description == other.description &&
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
          lowPowerMode == other.lowPowerMode &&
          chorusEnabled == other.chorusEnabled &&
          chorusRate == other.chorusRate &&
          chorusDepth == other.chorusDepth &&
          chorusWetMix == other.chorusWetMix &&
          _listEquals(eqBandGains, other.eqBandGains) &&
          convolutionReverbEnabled == other.convolutionReverbEnabled &&
          convolutionReverbMix == other.convolutionReverbMix &&
          formantShifterEnabled == other.formantShifterEnabled &&
          formantShiftFactor == other.formantShiftFactor &&
          formantShiftMix == other.formantShiftMix;

  @override
  int get hashCode => Object.hashAll([
        name,
        description,
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
        lowPowerMode,
        chorusEnabled,
        chorusRate,
        chorusDepth,
        chorusWetMix,
        ...eqBandGains,
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

  /// Built-in presets matching README phase 4 descriptions.
  static const List<Preset> builtIns = [
    // ── Default ──
    Preset(
      name: 'Default',
      description: 'All 10 effects at standard intensity',
    ),
    // ── Demon ──
    Preset(
      name: 'Demon',
      description: 'Deep growl — max gain, heavy fuzz, low pitch wobble',
      gainBoost: 6.0,
      echoDelay: 150.0,
      echoDecay: 0.6,
      reverbRoomSize: 0.7,
      crackleIntensity: 0.05,
      dropoutRate: 0.04,
      fuzzDrive: 8.0,
      bitCrushDepth: 4,
      pitchWobbleRange: 5.0,
      clipThreshold: 0.4,
    ),
    // ── Robot ──
    Preset(
      name: 'Robot',
      description: 'Mechanical — high bit crush, moderate pitch wobble, no echo',
      gainBoost: 3.0,
      echoEnabled: false,
      reverbRoomSize: 0.2,
      crackleIntensity: 0.02,
      dropoutRate: 0.03,
      fuzzDrive: 2.0,
      bitCrushDepth: 3,
      pitchWobbleRange: 6.0,
      clipThreshold: 0.5,
    ),
    // ── Ghost Radio ──
    Preset(
      name: 'Ghost Radio',
      description: 'Distant — heavy bandpass, lots of crackle + dropout, reverb',
      gainBoost: 5.0,
      echoDelay: 200.0,
      echoDecay: 0.5,
      reverbRoomSize: 0.85,
      crackleIntensity: 0.08,
      dropoutRate: 0.10,
      fuzzDrive: 3.0,
      bitCrushDepth: 5,
      pitchWobbleRange: 2.0,
      clipThreshold: 0.6,
      radioFilterEnabled: true,
    ),
    // ── Dial-up Modem ──
    Preset(
      name: 'Dial-up Modem',
      description: 'Screeching — max crackle, intense dropout, extreme clip',
      gainBoost: 7.0,
      echoEnabled: false,
      reverbEnabled: false,
      crackleIntensity: 0.12,
      dropoutRate: 0.15,
      fuzzDrive: 6.0,
      bitCrushDepth: 2,
      pitchWobbleEnabled: false,
      clipThreshold: 0.3,
    ),
    // ── Underwater ──
    Preset(
      name: 'Underwater',
      description: 'Muffled — heavy reverb, no crackle, no dropout, soft clip',
      gainBoost: 2.0,
      echoDelay: 300.0,
      echoDecay: 0.8,
      reverbRoomSize: 0.95,
      crackleEnabled: false,
      dropoutEnabled: false,
      fuzzDrive: 1.5,
      bitCrushEnabled: false,
      pitchWobbleRange: 1.0,
      radioFilterEnabled: false,
      clipThreshold: 0.7,
    ),
  ];
}
