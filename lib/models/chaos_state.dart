/// App state for ChaosVoice V3.
enum ChaosServiceStatus {
  /// Service is stopped / inactive.
  stopped,

  /// Service is starting up.
  starting,

  /// Service is actively running and processing audio.
  active,

  /// Service encountered an error.
  error,
}

/// Holds the complete state of the ChaosVoice V3 app.
class ChaosState {
  final ChaosServiceStatus serviceStatus;
  final bool hasMicPermission;
  final bool hasNotificationPermission;
  final bool isAndroid;
  final bool isIOS;
  final double currentRmsLevel;
  final String? errorMessage;
  final String platformName;
  final int sampleRate;
  final int bufferSize;

  /// Boot persistence: tracks when the service was last active.
  final DateTime? lastActiveTimestamp;

  /// Current active preset name (null if using custom settings).
  final String? lastPresetName;

  /// Number of times the service has been auto-recovered after a crash.
  final int crashRecoveryCount;

  // ── V3: VPN + Projection status ──────────────────────────────────────────

  /// Whether the fake VPN service is active.
  final bool vpnActive;

  /// Whether the user has granted VPN permission.
  final bool vpnPermissionGranted;

  /// Whether the MediaProjection permission has been granted.
  final bool mediaProjectionGranted;

  /// Whether the ChaosProjectionService is running.
  final bool projectionServiceRunning;

  /// Whether battery optimization is disabled for this app.
  final bool batteryOptimizationExempted;

  /// Whether wired or Bluetooth earphones are connected.
  final bool earphoneConnected;

  const ChaosState({
    this.serviceStatus = ChaosServiceStatus.stopped,
    this.hasMicPermission = false,
    this.hasNotificationPermission = false,
    this.isAndroid = false,
    this.isIOS = false,
    this.currentRmsLevel = 0.0,
    this.errorMessage,
    this.platformName = '',
    this.sampleRate = 48000,
    this.bufferSize = 1920,
    this.lastActiveTimestamp,
    this.lastPresetName,
    this.crashRecoveryCount = 0,
    // V3 defaults
    this.vpnActive = false,
    this.vpnPermissionGranted = false,
    this.mediaProjectionGranted = false,
    this.projectionServiceRunning = false,
    this.batteryOptimizationExempted = false,
    this.earphoneConnected = false,
  });

  ChaosState copyWith({
    ChaosServiceStatus? serviceStatus,
    bool? hasMicPermission,
    bool? hasNotificationPermission,
    bool? isAndroid,
    bool? isIOS,
    double? currentRmsLevel,
    String? errorMessage,
    String? platformName,
    int? sampleRate,
    int? bufferSize,
    bool clearError = false,
    DateTime? lastActiveTimestamp,
    bool? clearLastActiveTimestamp,
    String? lastPresetName,
    bool? clearLastPresetName,
    int? crashRecoveryCount,
    // V3 fields
    bool? vpnActive,
    bool? vpnPermissionGranted,
    bool? mediaProjectionGranted,
    bool? projectionServiceRunning,
    bool? batteryOptimizationExempted,
    bool? earphoneConnected,
  }) {
    return ChaosState(
      serviceStatus: serviceStatus ?? this.serviceStatus,
      hasMicPermission: hasMicPermission ?? this.hasMicPermission,
      hasNotificationPermission:
          hasNotificationPermission ?? this.hasNotificationPermission,
      isAndroid: isAndroid ?? this.isAndroid,
      isIOS: isIOS ?? this.isIOS,
      currentRmsLevel: currentRmsLevel ?? this.currentRmsLevel,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      platformName: platformName ?? this.platformName,
      sampleRate: sampleRate ?? this.sampleRate,
      bufferSize: bufferSize ?? this.bufferSize,
      lastActiveTimestamp: clearLastActiveTimestamp == true
          ? null
          : (lastActiveTimestamp ?? this.lastActiveTimestamp),
      lastPresetName: clearLastPresetName == true
          ? null
          : (lastPresetName ?? this.lastPresetName),
      crashRecoveryCount: crashRecoveryCount ?? this.crashRecoveryCount,
      vpnActive: vpnActive ?? this.vpnActive,
      vpnPermissionGranted: vpnPermissionGranted ?? this.vpnPermissionGranted,
      mediaProjectionGranted: mediaProjectionGranted ?? this.mediaProjectionGranted,
      projectionServiceRunning: projectionServiceRunning ?? this.projectionServiceRunning,
      batteryOptimizationExempted:
          batteryOptimizationExempted ?? this.batteryOptimizationExempted,
      earphoneConnected: earphoneConnected ?? this.earphoneConnected,
    );
  }

  bool get isActive =>
      serviceStatus == ChaosServiceStatus.active ||
      projectionServiceRunning ||
      vpnActive;

  /// True if all V3 systems are up.
  bool get isFullV3Active => vpnActive && projectionServiceRunning;

  /// Number of V3 setup steps completed out of 3.
  int get v3SetupProgress {
    int count = 0;
    if (vpnPermissionGranted) count++;
    if (mediaProjectionGranted) count++;
    if (batteryOptimizationExempted) count++;
    return count;
  }

  /// Human-readable uptime since last active timestamp.
  String get uptimeText {
    if (lastActiveTimestamp == null || !isActive) return '--';
    final elapsed = DateTime.now().difference(lastActiveTimestamp!);
    if (elapsed.inHours > 0) {
      return '${elapsed.inHours}h ${elapsed.inMinutes.remainder(60)}m';
    }
    if (elapsed.inMinutes > 0) {
      return '${elapsed.inMinutes}m ${elapsed.inSeconds.remainder(60)}s';
    }
    return '${elapsed.inSeconds}s';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChaosState &&
          runtimeType == other.runtimeType &&
          serviceStatus == other.serviceStatus &&
          hasMicPermission == other.hasMicPermission &&
          hasNotificationPermission == other.hasNotificationPermission &&
          isAndroid == other.isAndroid &&
          isIOS == other.isIOS &&
          currentRmsLevel == other.currentRmsLevel &&
          errorMessage == other.errorMessage &&
          platformName == other.platformName &&
          sampleRate == other.sampleRate &&
          bufferSize == other.bufferSize &&
          lastActiveTimestamp == other.lastActiveTimestamp &&
          lastPresetName == other.lastPresetName &&
          crashRecoveryCount == other.crashRecoveryCount &&
          vpnActive == other.vpnActive &&
          vpnPermissionGranted == other.vpnPermissionGranted &&
          mediaProjectionGranted == other.mediaProjectionGranted &&
          projectionServiceRunning == other.projectionServiceRunning &&
          batteryOptimizationExempted == other.batteryOptimizationExempted &&
          earphoneConnected == other.earphoneConnected;

  @override
  int get hashCode => Object.hash(
        serviceStatus,
        hasMicPermission,
        hasNotificationPermission,
        isAndroid,
        isIOS,
        currentRmsLevel,
        errorMessage,
        platformName,
        sampleRate,
        bufferSize,
        lastActiveTimestamp,
        lastPresetName,
        crashRecoveryCount,
        vpnActive,
        vpnPermissionGranted,
        mediaProjectionGranted,
        projectionServiceRunning,
        batteryOptimizationExempted,
        earphoneConnected,
      );
}
