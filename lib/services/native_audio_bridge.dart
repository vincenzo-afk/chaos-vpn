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
      final result = await _channel.invokeMethod<bool>(ChannelMethods.startService) ?? false;
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
      final result = await _channel.invokeMethod<bool>(ChannelMethods.stopService) ?? false;
      AppLogger.info('Native service stopped: $result');
      return result;
    } on PlatformException catch (e) {
      AppLogger.error('stopService failed: ${e.message}');
      return false;
    }
  }

  /// Update DSP parameters in the native layer.
  Future<void> updateParams({
    required double gain,
    required double crackleIntensity,
    required double dropoutRate,
    required int bitCrushDepth,
    required double clipThreshold,
  }) async {
    try {
      await _channel.invokeMethod(ChannelMethods.updateParams, {
        'gain': gain,
        'crackleIntensity': crackleIntensity,
        'dropoutRate': dropoutRate,
        'bitCrushDepth': bitCrushDepth,
        'clipThreshold': clipThreshold,
      });
    } on PlatformException catch (e) {
      AppLogger.error('updateParams failed: ${e.message}');
    }
  }

  /// Check if native service is running.
  Future<bool> isServiceRunning() async {
    try {
      return await _channel.invokeMethod<bool>(ChannelMethods.isRunning) ?? false;
    } on PlatformException {
      return false;
    }
  }
}
