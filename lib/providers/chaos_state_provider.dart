import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chaos_state.dart';
import '../services/permission_service.dart';
import '../services/native_audio_bridge.dart';
import '../utils/logger.dart';

/// StateNotifier that manages the global ChaosVoice V3 app state.
/// Includes crash recovery watchdog and boot persistence tracking.
class ChaosStateNotifier extends StateNotifier<ChaosState> {
  final NativeAudioBridge _bridge;
  final PermissionService _permissions;

  /// Periodic health check timer for crash recovery.
  Timer? _watchdogTimer;

  /// Periodic earphone check.
  Timer? _earphoneTimer;

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
    final micGranted    = await _permissions.hasMicPermission();
    final notifGranted  = await _permissions.hasNotificationPermission();
    final running       = await _bridge.isV3EngineRunning();
    final vpnRunning    = await _bridge.isVpnRunning();
    final vpnPerm       = await _bridge.isVpnPermissionGranted();
    final projRunning   = await _bridge.isProjectionRunning();
    final batteryOk     = await _bridge.isBatteryOptimizationExempted();
    final earphones     = await _bridge.isEarphoneConnected();

    state = state.copyWith(
      hasMicPermission: micGranted,
      hasNotificationPermission: notifGranted,
      serviceStatus: running ? ChaosServiceStatus.active : ChaosServiceStatus.stopped,
      vpnActive: vpnRunning,
      vpnPermissionGranted: vpnPerm,
      projectionServiceRunning: projRunning,
      batteryOptimizationExempted: batteryOk,
      earphoneConnected: earphones,
    );

    if (running) {
      _wasActive = true;
      state = state.copyWith(lastActiveTimestamp: DateTime.now());
      _startWatchdog();
    }

    _startEarphoneMonitor();
    AppLogger.info('[Provider V3] State initialized');
  }

  // ─────────────────── V3 Full Launch Flow ──────────────────────────────────

  /// Complete V3 activation sequence:
  /// 1. Request mic & notification permission
  /// 2. Start ChaosProjectionService in foreground-only mode (empty)
  /// 3. Request MediaProjection permission (shows system dialog)
  /// 4. Request VPN permission (shows system dialog)
  /// 5. Start processing / battery optimization
  Future<void> activateV3() async {
    state = state.copyWith(serviceStatus: ChaosServiceStatus.starting, clearError: true);

    // Step 1: Mic permission
    final micOk = await _permissions.requestMicPermission();
    if (!micOk) {
      state = state.copyWith(
        serviceStatus: ChaosServiceStatus.error,
        errorMessage: 'Microphone permission is required.',
      );
      return;
    }
    state = state.copyWith(hasMicPermission: true);

    if (Platform.isAndroid) {
      await _permissions.requestNotificationPermission();
    }

    // Step 2: Start foreground service FIRST (empty)
    // This prevents crash on Android 14+ when requesting MediaProjection
    await _bridge.startForegroundServiceOnly();
    await Future.delayed(const Duration(seconds: 1)); // Wait for service to bind

    // Step 3: MediaProjection permission (SECOND)
    final projGranted = await _bridge.requestMediaProjection();
    state = state.copyWith(mediaProjectionGranted: projGranted);

    if (!projGranted) {
      AppLogger.warn('[V3] MediaProjection denied — starting MIC fallback');
      await _bridge.startService();
    }
    state = state.copyWith(projectionServiceRunning: projGranted);

    // Step 4: VPN permission (THIRD)
    bool vpnPerm = await _bridge.isVpnPermissionGranted();
    if (!vpnPerm) {
      vpnPerm = await _bridge.requestVpnPermission();
    }
    state = state.copyWith(vpnPermissionGranted: vpnPerm);

    if (!vpnPerm) {
      state = state.copyWith(
        serviceStatus: ChaosServiceStatus.error,
        errorMessage: 'VPN permission is required for background operation.',
      );
      return;
    }

    // Step 5: Start processing (VPN service) (LAST)
    await _bridge.startVpnService();
    state = state.copyWith(vpnActive: true);

    // Step 7: Battery optimization exemption
    final batteryOk = await _bridge.isBatteryOptimizationExempted();
    if (!batteryOk) {
      await _bridge.requestBatteryOptimizationExemption();
      // Don't block on this — user can dismiss and app still works
    }
    final batteryNow = await _bridge.isBatteryOptimizationExempted();
    state = state.copyWith(batteryOptimizationExempted: batteryNow);

    // Check earphones
    final earphones = await _bridge.isEarphoneConnected();
    state = state.copyWith(earphoneConnected: earphones);

    state = state.copyWith(
      serviceStatus: ChaosServiceStatus.active,
      lastActiveTimestamp: DateTime.now(),
      clearError: true,
    );
    _wasActive = true;
    _startWatchdog();
    _startEarphoneMonitor();

    AppLogger.info('[V3] Engine activated. Projection=$projGranted, VPN=true');
  }

  /// Stop all V3 services.
  Future<void> deactivateV3() async {
    await _bridge.stopV3Engine();
    state = state.copyWith(
      serviceStatus: ChaosServiceStatus.stopped,
      vpnActive: false,
      projectionServiceRunning: false,
      clearError: true,
    );
    _wasActive = false;
    _stopWatchdog();
    AppLogger.info('[V3] Engine deactivated');
  }

  /// Toggle V3 engine on/off.
  Future<void> toggleService() async {
    if (state.isActive) {
      await deactivateV3();
    } else {
      await activateV3();
    }
  }

  // ─────────────── Legacy V1/V2 compat methods ──────────────────────────────

  Future<void> startService() async => activateV3();
  Future<void> stopService() async => deactivateV3();

  // ─────────────── Watchdog ──────────────────────────────────────────────────

  /// Start a periodic health check that auto-restarts the service if killed.
  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!state.isActive) return;

      final running = await _bridge.isV3EngineRunning();
      if (!running && _wasActive) {
        AppLogger.warn('[V3] Service crashed — attempting recovery');
        final vpnOk = await _bridge.startVpnService();
        final svcOk = state.projectionServiceRunning
            ? await _bridge.startProjectionService()
            : await _bridge.startService();

        if (vpnOk || svcOk) {
          state = state.copyWith(
            crashRecoveryCount: state.crashRecoveryCount + 1,
            lastActiveTimestamp: DateTime.now(),
            vpnActive: vpnOk,
          );
          AppLogger.info('[V3] Recovery successful (${state.crashRecoveryCount})');
        } else {
          state = state.copyWith(
            serviceStatus: ChaosServiceStatus.error,
            errorMessage: 'Service crashed and failed to recover.',
          );
          _stopWatchdog();
        }
      }
      _wasActive = running;
    });
  }

  void _stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _wasActive = false;
  }

  /// Monitor earphone status every 5 seconds.
  void _startEarphoneMonitor() {
    _earphoneTimer?.cancel();
    _earphoneTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final connected = await _bridge.isEarphoneConnected();
      if (connected != state.earphoneConnected) {
        state = state.copyWith(earphoneConnected: connected);
        AppLogger.info('[V3] Earphone status changed: $connected');
      }
    });
  }

  // ─────────────── Misc state mutators ──────────────────────────────────────

  void setPresetName(String? name) {
    state = state.copyWith(
      lastPresetName: name,
      clearLastPresetName: name == null,
    );
  }

  void updateRmsLevel(double rms) {
    state = state.copyWith(currentRmsLevel: rms);
  }

  void setSampleRate(int rate) {
    state = state.copyWith(sampleRate: rate);
  }

  void setBufferSize(int size) {
    state = state.copyWith(bufferSize: size);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void reset() {
    _stopWatchdog();
    _earphoneTimer?.cancel();
    state = ChaosState(
      isAndroid: Platform.isAndroid,
      isIOS: Platform.isIOS,
      platformName: Platform.operatingSystem,
    );
  }

  @override
  void dispose() {
    _stopWatchdog();
    _earphoneTimer?.cancel();
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
