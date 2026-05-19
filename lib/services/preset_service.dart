import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../models/effect_settings.dart';
import '../models/preset.dart';
import '../utils/logger.dart';

/// Service for managing ChaosVoice effect presets.
/// Handles save/load from local JSON storage and provides built-in presets.
class PresetService {
  static final PresetService _instance = PresetService._();
  factory PresetService() => _instance;
  PresetService._();

  static const String _fileName = 'chaosvoice_presets.json';

  /// Convert a Preset to EffectSettings.
  EffectSettings presetToSettings(Preset preset) {
    return EffectSettings(
      masterEnabled: true,
      gainBoost: preset.gainBoost,
      echoEnabled: preset.echoEnabled,
      echoDelay: preset.echoDelay,
      echoDecay: preset.echoDecay,
      reverbEnabled: preset.reverbEnabled,
      reverbRoomSize: preset.reverbRoomSize,
      crackleEnabled: preset.crackleEnabled,
      crackleIntensity: preset.crackleIntensity,
      dropoutEnabled: preset.dropoutEnabled,
      dropoutRate: preset.dropoutRate,
      fuzzEnabled: preset.fuzzEnabled,
      fuzzDrive: preset.fuzzDrive,
      bitCrushEnabled: preset.bitCrushEnabled,
      bitCrushDepth: preset.bitCrushDepth,
      pitchWobbleEnabled: preset.pitchWobbleEnabled,
      pitchWobbleRange: preset.pitchWobbleRange,
      radioFilterEnabled: preset.radioFilterEnabled,
      clipEnabled: preset.clipEnabled,
      clipThreshold: preset.clipThreshold,
      lowPowerMode: preset.lowPowerMode,
      chorusEnabled: preset.chorusEnabled,
      chorusRate: preset.chorusRate,
      chorusDepth: preset.chorusDepth,
      chorusWetMix: preset.chorusWetMix,
      eqBandGains: preset.eqBandGains,
    );
  }

  /// Convert current EffectSettings to a named Preset.
  Preset settingsToPreset(String name, EffectSettings settings, {String description = ''}) {
    return Preset(
      name: name,
      description: description,
      gainBoost: settings.gainBoost,
      echoEnabled: settings.echoEnabled,
      echoDelay: settings.echoDelay,
      echoDecay: settings.echoDecay,
      reverbEnabled: settings.reverbEnabled,
      reverbRoomSize: settings.reverbRoomSize,
      crackleEnabled: settings.crackleEnabled,
      crackleIntensity: settings.crackleIntensity,
      dropoutEnabled: settings.dropoutEnabled,
      dropoutRate: settings.dropoutRate,
      fuzzEnabled: settings.fuzzEnabled,
      fuzzDrive: settings.fuzzDrive,
      bitCrushEnabled: settings.bitCrushEnabled,
      bitCrushDepth: settings.bitCrushDepth,
      pitchWobbleEnabled: settings.pitchWobbleEnabled,
      pitchWobbleRange: settings.pitchWobbleRange,
      radioFilterEnabled: settings.radioFilterEnabled,
      clipEnabled: settings.clipEnabled,
      clipThreshold: settings.clipThreshold,
      lowPowerMode: settings.lowPowerMode,
      chorusEnabled: settings.chorusEnabled,
      chorusRate: settings.chorusRate,
      chorusDepth: settings.chorusDepth,
      chorusWetMix: settings.chorusWetMix,
      eqBandGains: settings.eqBandGains,
      convolutionReverbEnabled: settings.convolutionReverbEnabled,
      convolutionReverbMix: settings.convolutionReverbMix,
      formantShifterEnabled: settings.formantShifterEnabled,
      formantShiftFactor: settings.formantShiftFactor,
      formantShiftMix: settings.formantShiftMix,
    );
  }

  /// Generate a fully randomized EffectSettings.
  EffectSettings randomize() {
    final rng = Random();
    return EffectSettings(
      masterEnabled: true,
      gainBoost: 1.0 + rng.nextDouble() * 7.0, // 1.0–8.0
      echoEnabled: rng.nextBool(),
      echoDelay: 20.0 + rng.nextDouble() * 480.0, // 20–500ms
      echoDecay: rng.nextDouble() * 0.9, // 0–90%
      reverbEnabled: rng.nextBool(),
      reverbRoomSize: rng.nextDouble(), // 0–100%
      crackleEnabled: rng.nextBool(),
      crackleIntensity: rng.nextDouble() * 0.15, // 0–15%
      dropoutEnabled: rng.nextBool(),
      dropoutRate: rng.nextDouble() * 0.20, // 0–20%
      fuzzEnabled: rng.nextBool(),
      fuzzDrive: 1.0 + rng.nextDouble() * 9.0, // 1–10x
      bitCrushEnabled: rng.nextBool(),
      bitCrushDepth: 2 + rng.nextInt(15), // 2–16 bit
      pitchWobbleEnabled: rng.nextBool(),
      pitchWobbleRange: rng.nextDouble() * 12.0, // 0–12 st
      radioFilterEnabled: rng.nextBool(),
      clipEnabled: rng.nextBool(),
      clipThreshold: 0.1 + rng.nextDouble() * 0.9, // 10–100%
      lowPowerMode: rng.nextDouble() < 0.3, // 30% chance
      chorusEnabled: rng.nextBool(),
      chorusRate: 0.1 + rng.nextDouble() * 3.9, // 0.1–4.0 Hz
      chorusDepth: 1.0 + rng.nextDouble() * 19.0, // 1–20 ms
      chorusWetMix: rng.nextDouble(), // 0–100%
      convolutionReverbEnabled: rng.nextBool(),
      convolutionReverbMix: rng.nextDouble(), // 0–100%
      formantShifterEnabled: rng.nextBool(),
      formantShiftFactor: 0.5 + rng.nextDouble() * 1.5, // 0.5–2.0
      formantShiftMix: rng.nextDouble(), // 0–100%
    );
  }

  /// Load user saved presets from local file.
  Future<List<Preset>> loadUserPresets() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        return [];
      }
      final dir = await _getStorageDir();
      final file = File('${dir.path}/$_fileName');
      if (!file.existsSync()) return [];

      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list.map((e) => Preset.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      AppLogger.error('Failed to load presets: $e');
      return [];
    }
  }

  /// Save a user preset to local file.
  Future<void> savePreset(Preset preset) async {
    try {
      final presets = await loadUserPresets();
      // Replace if name already exists
      presets.removeWhere((p) => p.name == preset.name);
      presets.add(preset);
      await _writePresets(presets);
      AppLogger.info('[Presets] Saved preset: ${preset.name}');
    } catch (e) {
      AppLogger.error('Failed to save preset: $e');
    }
  }

  /// Delete a user preset by name.
  Future<void> deletePreset(String name) async {
    try {
      final presets = await loadUserPresets();
      presets.removeWhere((p) => p.name == name);
      await _writePresets(presets);
      AppLogger.info('[Presets] Deleted preset: $name');
    } catch (e) {
      AppLogger.error('Failed to delete preset: $e');
    }
  }

  /// Get all available presets: built-in + user saved.
  Future<List<Preset>> getAllPresets() async {
    const builtIn = Preset.builtIns;
    final user = await loadUserPresets();
    // User presets override built-in with same name
    final combined = <Preset>[...builtIn];
    for (final userPreset in user) {
      combined.removeWhere((p) => p.name == userPreset.name);
      combined.add(userPreset);
    }
    return combined;
  }

  Future<Directory> _getStorageDir() async {
    // Use a fixed directory for persistent preset storage
    // On Android/iOS this should use path_provider, but for cross-platform
    // compatibility we use a fixed subdirectory in the app's data space.
    final dir = Directory('${Directory.systemTemp.path}/chaosvoice_presets');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<void> _writePresets(List<Preset> presets) async {
    final dir = await _getStorageDir();
    final file = File('${dir.path}/$_fileName');
    final json = jsonEncode(presets.map((p) => p.toJson()).toList());
    await file.writeAsString(json);
  }
}
