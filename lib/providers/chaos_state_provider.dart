import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chaos_state.dart';
import '../services/permission_service.dart';
import '../services/native_audio_bridge.dart';
import '../utils/logger.dart';

/// StateNotifier that manages the global ChaosVoice app state.
/// Includes crash recovery watchdog and boot persistence tracking.
class ChaosStateNotifier extends StateNotifier<ChaosState> {
  final NativeAudioBridge _bridge;
  final PermissionService _permissions;

  /// Periodic health check timer for crash recovery.
  Timer? _watchdogTimer;

  /// Track whether the service was previously active to detect crashes.
  bool _wasActive = false;

  ChaosStateNotifier(this._bridge, this._permissions)
      : super(ChaosState(
          isAndroid: Platform.isAndroid,
          isIOS: Platform.isIOS,
          platformName: Platform.operatingSystem,
        ));

  /// Initialize: check permissions and service status on startup.
  Future<void> init() async {
    final micGranted = await _permissions.hasMicPermission();
    final notifGranted = await _permissions.hasNotificationPermission();
    final running = await _bridge.isServiceRunning();

    state = state.copyWith(
      hasMicPermission: micGranted,
      hasNotificationPermission: notifGranted,
      serviceStatus:
          running ? ChaosServiceStatus.active : ChaosServiceStatus.stopped,
    );

    // If service was running from previous boot, restore active timestamp
    if (running) {
      _wasActive = true;
      state = state.copyWith(lastActiveTimestamp: DateTime.now());
      _startWatchdog();
      AppLogger.info('[Provider] Service was already running on startup');
    }

    AppLogger.info('[Provider] State initialized');
  }

  /// Start a periodic health check that auto-restarts the service if killed.
  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!state.isActive) {
        // Service is expected to be stopped — no watchdog needed
        return;
      }

      final running = await _bridge.isServiceRunning();
      if (!running && _wasActive) {
        // Service was killed (crash or OS kill) — attempt recovery
        AppLogger.warn('[Provider] Service crashed — attempting recovery');
        final recovered = await _bridge.startService();
        if (recovered) {
          state = state.copyWith(
            crashRecoveryCount: state.crashRecoveryCount + 1,
            lastActiveTimestamp: DateTime.now(),
          );
          AppLogger.info('[Provider] Crash recovery successful (${
              state.crashRecoveryCount} total)');
        } else {
          state = state.copyWith(
            serviceStatus: ChaosServiceStatus.error,
            errorMessage:
                'Service crashed ${state.crashRecoveryCount + 1} times. Recovery failed.',
          );
          _watchdogTimer?.cancel();
        }
      }
      _wasActive = running;
    });
  }

  /// Stop the health check watchdog.
  void _stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _wasActive = false;
  }

  /// Toggle the audio service on/off.
  Future<void> toggleService() async {
    if (state.isActive) {
      await stopService();
    } else {
      await startService();
    }
  }

  /// Start the native audio service.
  Future<void> startService() async {
    // Ensure mic permission first
    final micOk = await _permissions.requestMicPermission();
    if (!micOk) {
      state = state.copyWith(
        serviceStatus: ChaosServiceStatus.error,
        errorMessage: 'Microphone permission is required.',
      );
      return;
    }

    state = state.copyWith(
      serviceStatus: ChaosServiceStatus.starting,
      clearError: true,
      hasMicPermission: true,
    );

    final started = await _bridge.startService();
    if (started) {
      state = state.copyWith(
        serviceStatus: ChaosServiceStatus.active,
        lastActiveTimestamp: DateTime.now(),
      );
      _wasActive = true;
      _startWatchdog();
      AppLogger.info('[Provider] Service started successfully');
    } else {
      state = state.copyWith(
        serviceStatus: ChaosServiceStatus.error,
        errorMessage: 'Failed to start audio service.',
      );
    }
  }

  /// Stop the native audio service.
  Future<void> stopService() async {
    await _bridge.stopService();
    state = state.copyWith(
      serviceStatus: ChaosServiceStatus.stopped,
      clearError: true,
      // Keep lastActiveTimestamp for boot persistence display
    );
    _wasActive = false;
    _stopWatchdog();
    AppLogger.info('[Provider] Service stopped');
  }

  /// Record the name of the currently active preset.
  void setPresetName(String? name) {
    state = state.copyWith(
      lastPresetName: name,
      clearLastPresetName: name == null,
    );
  }

  /// Update current RMS level from audio stream.
  void updateRmsLevel(double rms) {
    state = state.copyWith(currentRmsLevel: rms);
  }

  /// Update sample rate setting.
  void setSampleRate(int rate) {
    state = state.copyWith(sampleRate: rate);
    AppLogger.info('[Provider] Sample rate set to $rate');
  }

  /// Update buffer size setting.
  void setBufferSize(int size) {
    state = state.copyWith(bufferSize: size);
    AppLogger.info('[Provider] Buffer size set to $size');
  }

  /// Clear any error message.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Reset entire state to defaults.
  void reset() {
    _stopWatchdog();
    state = ChaosState(
      isAndroid: Platform.isAndroid,
      isIOS: Platform.isIOS,
      platformName: Platform.operatingSystem,
    );
  }

  @override
  void dispose() {
    _stopWatchdog();
    super.dispose();
  }
}

/// Riverpod provider for ChaosState.
final chaosStateProvider =
    StateNotifierProvider<ChaosStateNotifier, ChaosState>((ref) {
  final bridge = NativeAudioBridge();
  final permissions = PermissionService();
  return ChaosStateNotifier(bridge, permissions);
});
