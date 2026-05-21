import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/effect_settings.dart';
import '../services/native_audio_bridge.dart';
import '../utils/logger.dart';

/// StateNotifier that manages EffectSettings and syncs changes to native layer.
class EffectSettingsNotifier extends StateNotifier<EffectSettings> {
  final NativeAudioBridge _bridge;

  EffectSettingsNotifier(this._bridge) : super(const EffectSettings());

  /// Update a specific field and sync to native.
  void update(EffectSettings newSettings) {
    state = newSettings;
    _syncToNative(newSettings);
  }

  /// Reset all effect settings to defaults.
  void reset() {
    state = const EffectSettings();
    _syncToNative(state);
  }

  /// Push current settings to the native audio service.
  void _syncToNative(EffectSettings settings) {
    _bridge.updateParams(
      gain: settings.gainBoost,
      crackleIntensity: settings.crackleIntensity,
      dropoutRate: settings.dropoutRate,
      bitCrushDepth: settings.bitCrushDepth,
      clipThreshold: settings.clipThreshold,
      intensityPreset: settings.intensityPreset,
      reverbRoomSize: settings.reverbRoomSize,
      fuzzDrive: settings.fuzzDrive,
      echoDelay: settings.echoDelay,
      echoDecay: settings.echoDecay,
      pitchWobbleRange: settings.pitchWobbleRange,
    );
    AppLogger.info('[Provider] Settings synced to native');
  }
}

/// Riverpod provider for EffectSettings.
final effectSettingsProvider =
    StateNotifierProvider<EffectSettingsNotifier, EffectSettings>((ref) {
  final bridge = NativeAudioBridge();
  return EffectSettingsNotifier(bridge);
});
