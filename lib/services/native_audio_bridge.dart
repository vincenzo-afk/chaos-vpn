import 'package:flutter/services.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// MethodChannel bridge between Flutter and the Android V3 native services.
///
/// V3 architecture:
///   - ChaosVpnService (fake VPN — survival)
///   - ChaosProjectionService (MediaProjection + DSP + AudioTrack)
///   - VirtualMicService (fallback mic capture)
class NativeAudioBridge {
  static const _channel = MethodChannel(ChannelNames.audioBridge);

  static final NativeAudioBridge _instance = NativeAudioBridge._();
  factory NativeAudioBridge() => _instance;
  NativeAudioBridge._();

  // ─────────────── V1/V2 Compat ─────────────────────────────────────────────

  /// Start the legacy mic capture service (fallback).
  Future<bool> startService() async {
    try {
      final result = await _channel.invokeMethod<bool>(ChannelMethods.startService) ?? false;
      AppLogger.info('Native service started: $result');
      return result;
    } on PlatformException catch (e) {
      AppLogger.error('startService failed: ${e.message}');
      return false;
    }
  }

  /// Stop all services.
  Future<bool> stopService() async {
    try {
      final result = await _channel.invokeMethod<bool>(ChannelMethods.stopService) ?? false;
      AppLogger.info('Native service stopped: $result');
      return result;
    } on PlatformException catch (e) {
      AppLogger.error('stopService failed: ${e.message}');
      return false;
    }
  }

  /// Update all DSP parameters in the native layer.
  ///
  /// Bug fix: this now forwards the complete parameter surface (core DSP,
  /// effect enable flags and the advanced chorus/EQ/convolution/formant
  /// sections) so the native engine honors every UI control.
  Future<void> updateParams({
    required double gain,
    required double crackleIntensity,
    required double dropoutRate,
    required int bitCrushDepth,
    required double clipThreshold,
    String intensityPreset = 'BRUTAL',
    double ringModFreq = 800.0,
    double noiseAmount = 0.40,
    double glitchRate = 0.15,
    double pitchShiftSemitones = -5.0,
    int sampleRateReduction = 8000,
    // Legacy compat
    double reverbRoomSize = 0.45,
    double fuzzDrive = 4.0,
    double echoDelay = 100.0,
    double echoDecay = 1.0,
    double pitchWobbleRange = 3.0,
    // ── Effect toggle chain ──
    bool masterEnabled = true,
    bool gainEnabled = true,
    bool echoEnabled = true,
    bool reverbEnabled = true,
    bool crackleEnabled = true,
    bool dropoutEnabled = true,
    bool fuzzEnabled = true,
    bool bitCrushEnabled = true,
    bool pitchWobbleEnabled = true,
    bool radioFilterEnabled = true,
    bool clipEnabled = true,
    // ── Advanced sections ──
    bool chorusEnabled = false,
    double chorusRate = 0.25,
    double chorusDepth = 10.0,
    double chorusWetMix = 0.5,
    List<double>? eqBandGains,
    bool convolutionReverbEnabled = false,
    double convolutionReverbMix = 0.45,
    bool formantShifterEnabled = false,
    double formantShiftFactor = 1.0,
    double formantShiftMix = 1.0,
    bool lowPowerMode = false,
  }) async {
    try {
      await _channel.invokeMethod(ChannelMethods.updateParams, {
        'gain': gain,
        'crackleIntensity': crackleIntensity,
        'dropoutRate': dropoutRate,
        'bitCrushDepth': bitCrushDepth,
        'clipThreshold': clipThreshold,
        'intensityPreset': intensityPreset,
        'ringModFreq': ringModFreq,
        'noiseAmount': noiseAmount,
        'glitchRate': glitchRate,
        'pitchShiftSemitones': pitchShiftSemitones,
        'sampleRateReduction': sampleRateReduction,
        'reverbRoomSize': reverbRoomSize,
        'fuzzDrive': fuzzDrive,
        'echoDelay': echoDelay,
        'echoDecay': echoDecay,
        'pitchWobbleRange': pitchWobbleRange,
        // ── Effect toggle chain ──
        'masterEnabled': masterEnabled,
        'gainEnabled': gainEnabled,
        'echoEnabled': echoEnabled,
        'reverbEnabled': reverbEnabled,
        'crackleEnabled': crackleEnabled,
        'dropoutEnabled': dropoutEnabled,
        'fuzzEnabled': fuzzEnabled,
        'bitCrushEnabled': bitCrushEnabled,
        'pitchWobbleEnabled': pitchWobbleEnabled,
        'radioFilterEnabled': radioFilterEnabled,
        'clipEnabled': clipEnabled,
        // ── Advanced sections ──
        'chorusEnabled': chorusEnabled,
        'chorusRate': chorusRate,
        'chorusDepth': chorusDepth,
        'chorusWetMix': chorusWetMix,
        'eqBandGains': eqBandGains ?? [0.0, 0.0, 0.0, 0.0, 0.0],
        'convolutionReverbEnabled': convolutionReverbEnabled,
        'convolutionReverbMix': convolutionReverbMix,
        'formantShifterEnabled': formantShifterEnabled,
        'formantShiftFactor': formantShiftFactor,
        'formantShiftMix': formantShiftMix,
        'lowPowerMode': lowPowerMode,
      });
    } on PlatformException catch (e) {
      AppLogger.error('updateParams failed: ${e.message}');
    }
  }

  /// Check if any native service is running.
  Future<bool> isServiceRunning() async {
    try {
      return await _channel.invokeMethod<bool>(ChannelMethods.isRunning) ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Set the audio routing mode (Android only).
  Future<bool> setRoutingMode(String mode) async {
    try {
      final result = await _channel.invokeMethod<bool>('setRoutingMode', {'mode': mode}) ?? false;
      AppLogger.info('Routing mode set to: $mode');
      return result;
    } on PlatformException catch (e) {
      AppLogger.error('setRoutingMode failed: ${e.message}');
      return false;
    }
  }

  /// Check if device is rooted.
  Future<bool> isDeviceRooted() async {
    try {
      return await _channel.invokeMethod<bool>('isDeviceRooted') ?? false;
    } on PlatformException {
      return false;
    }
  }

  // ─────────────── V3: VPN Service ──────────────────────────────────────────

  /// Request VPN permission from the user (shows system dialog).
  Future<bool> requestVpnPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestVpnPermission') ?? false;
      AppLogger.info('VPN permission: $result');
      return result;
    } on PlatformException catch (e) {
      AppLogger.error('requestVpnPermission failed: ${e.message}');
      return false;
    }
  }

  /// Check if VPN permission is already granted.
  Future<bool> isVpnPermissionGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isVpnPermissionGranted') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Start the fake VPN service.
  Future<bool> startVpnService() async {
    try {
      return await _channel.invokeMethod<bool>('startVpnService') ?? false;
    } on PlatformException catch (e) {
      AppLogger.error('startVpnService failed: ${e.message}');
      return false;
    }
  }

  /// Stop the fake VPN service.
  Future<bool> stopVpnService() async {
    try {
      return await _channel.invokeMethod<bool>('stopVpnService') ?? false;
    } on PlatformException catch (e) {
      AppLogger.error('stopVpnService failed: ${e.message}');
      return false;
    }
  }

  /// Check if the fake VPN is running.
  Future<bool> isVpnRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isVpnRunning') ?? false;
    } on PlatformException {
      return false;
    }
  }

  // ─────────────── V3: MediaProjection ──────────────────────────────────────

  /// Start the ChaosProjectionService in foreground-only mode (no audio).
  ///
  /// MUST be called BEFORE [requestMediaProjection].
  /// This satisfies the Android 14 requirement that a foreground service with
  /// foregroundServiceType=mediaProjection must be running before the user
  /// grants the MediaProjection dialog, otherwise getMediaProjection() crashes.
  Future<bool> startForegroundServiceOnly() async {
    try {
      return await _channel.invokeMethod<bool>('startForegroundServiceOnly') ?? false;
    } on PlatformException catch (e) {
      AppLogger.error('startForegroundServiceOnly failed: ${e.message}');
      return false;
    }
  }

  /// Request MediaProjection permission (shows screen capture dialog).
  Future<bool> requestMediaProjection() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestMediaProjection') ?? false;
      AppLogger.info('MediaProjection permission: $result');
      return result;
    } on PlatformException catch (e) {
      AppLogger.error('requestMediaProjection failed: ${e.message}');
      return false;
    }
  }

  /// Start the chaos projection service (requires prior requestMediaProjection).
  Future<bool> startProjectionService() async {
    try {
      return await _channel.invokeMethod<bool>('startProjectionService') ?? false;
    } on PlatformException catch (e) {
      AppLogger.error('startProjectionService failed: ${e.message}');
      return false;
    }
  }

  /// Stop the chaos projection service.
  Future<bool> stopProjectionService() async {
    try {
      return await _channel.invokeMethod<bool>('stopProjectionService') ?? false;
    } on PlatformException catch (e) {
      AppLogger.error('stopProjectionService failed: ${e.message}');
      return false;
    }
  }

  /// Check if the projection service is running.
  Future<bool> isProjectionRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isProjectionRunning') ?? false;
    } on PlatformException {
      return false;
    }
  }

  // ─────────────── V3: Battery Optimization ─────────────────────────────────

  /// Open system dialog to disable battery optimization for this app.
  Future<bool> requestBatteryOptimizationExemption() async {
    try {
      return await _channel.invokeMethod<bool>('requestBatteryOptimizationExemption') ?? false;
    } on PlatformException catch (e) {
      AppLogger.error('requestBatteryOptimizationExemption failed: ${e.message}');
      return false;
    }
  }

  /// Check if battery optimization is already disabled.
  Future<bool> isBatteryOptimizationExempted() async {
    try {
      return await _channel.invokeMethod<bool>('isBatteryOptimizationExempted') ?? false;
    } on PlatformException {
      return false;
    }
  }

  // ─────────────── V3: Earphone Detection ───────────────────────────────────

  /// Returns true if wired/Bluetooth earphones are connected.
  Future<bool> isEarphoneConnected() async {
    try {
      return await _channel.invokeMethod<bool>('isEarphoneConnected') ?? false;
    } on PlatformException {
      return false;
    }
  }

  // ─────────────── V3: Convenience ──────────────────────────────────────────

  /// Start the full V3 engine (VPN + Projection service).
  Future<bool> startV3Engine() async {
    try {
      return await _channel.invokeMethod<bool>('startV3Engine') ?? false;
    } on PlatformException catch (e) {
      AppLogger.error('startV3Engine failed: ${e.message}');
      return false;
    }
  }

  /// Stop the full V3 engine.
  Future<bool> stopV3Engine() async {
    try {
      return await _channel.invokeMethod<bool>('stopV3Engine') ?? false;
    } on PlatformException catch (e) {
      AppLogger.error('stopV3Engine failed: ${e.message}');
      return false;
    }
  }

  /// Check if V3 engine is running.
  Future<bool> isV3EngineRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isV3EngineRunning') ?? false;
    } on PlatformException {
      return false;
    }
  }
}
