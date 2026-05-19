import 'package:flutter/services.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// MethodChannel bridge between Flutter and Android/iOS native audio services.
class NativeAudioBridge {
  static const _channel = MethodChannel(ChannelNames.audioBridge);

  static final NativeAudioBridge _instance = NativeAudioBridge._();
  factory NativeAudioBridge() => _instance;
  NativeAudioBridge._();

  /// Start the native audio service.
  Future<bool> startService() async {
    try {
      final result =
          await _channel.invokeMethod<bool>(ChannelMethods.startService) ??
              false;
      AppLogger.info('Native service started: $result');
      return result;
    } on PlatformException catch (e) {
      AppLogger.error('startService failed: ${e.message}');
      return false;
    }
  }

  /// Stop the native audio service.
  Future<bool> stopService() async {
    try {
      final result =
          await _channel.invokeMethod<bool>(ChannelMethods.stopService) ??
              false;
      AppLogger.info('Native service stopped: $result');
      return result;
    } on PlatformException catch (e) {
      AppLogger.error('stopService failed: ${e.message}');
      return false;
    }
  }

  /// Update all DSP parameters in the native layer.
  Future<void> updateParams({
    required double gain,
    required double crackleIntensity,
    required double dropoutRate,
    required int bitCrushDepth,
    required double clipThreshold,
    double reverbRoomSize = 0.45,
    double fuzzDrive = 4.0,
    double echoDelay = 100.0,
    double echoDecay = 1.0,
    double pitchWobbleRange = 3.0,
  }) async {
    try {
      await _channel.invokeMethod(ChannelMethods.updateParams, {
        'gain': gain,
        'crackleIntensity': crackleIntensity,
        'dropoutRate': dropoutRate,
        'bitCrushDepth': bitCrushDepth,
        'clipThreshold': clipThreshold,
        'reverbRoomSize': reverbRoomSize,
        'fuzzDrive': fuzzDrive,
        'echoDelay': echoDelay,
        'echoDecay': echoDecay,
        'pitchWobbleRange': pitchWobbleRange,
      });
    } on PlatformException catch (e) {
      AppLogger.error('updateParams failed: ${e.message}');
    }
  }

  /// Check if native service is running.
  Future<bool> isServiceRunning() async {
    try {
      return await _channel.invokeMethod<bool>(ChannelMethods.isRunning) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Set the audio routing mode (Android only).
  Future<bool> setRoutingMode(String mode) async {
    try {
      final result =
          await _channel.invokeMethod<bool>('setRoutingMode', {'mode': mode}) ??
              false;
      AppLogger.info('Routing mode set to: $mode');
      return result;
    } on PlatformException catch (e) {
      AppLogger.error('setRoutingMode failed: ${e.message}');
      return false;
    }
  }

  /// Check if device is rooted (Android only).
  Future<bool> isDeviceRooted() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isDeviceRooted') ?? false;
      return result;
    } on PlatformException {
      return false;
    }
  }
}
