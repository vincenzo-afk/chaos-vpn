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
  ///
  /// Bug fix: the previous implementation forwarded only a narrow subset of
  /// parameters, so most toggles and advanced controls in the UI never reached
  /// the running native engine. All effect parameters are now forwarded.
  void _syncToNative(EffectSettings settings) {
    _bridge.updateParams(
      // ── Core DSP ──
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
      // ── Effect toggle chain (native side honors enable flags) ──
      masterEnabled: settings.masterEnabled,
      gainEnabled: settings.gainEnabled,
      echoEnabled: settings.echoEnabled,
      reverbEnabled: settings.reverbEnabled,
      crackleEnabled: settings.crackleEnabled,
      dropoutEnabled: settings.dropoutEnabled,
      fuzzEnabled: settings.fuzzEnabled,
      bitCrushEnabled: settings.bitCrushEnabled,
      pitchWobbleEnabled: settings.pitchWobbleEnabled,
      radioFilterEnabled: settings.radioFilterEnabled,
      clipEnabled: settings.clipEnabled,
      // ── Advanced sections ──
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
      lowPowerMode: settings.lowPowerMode,
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
