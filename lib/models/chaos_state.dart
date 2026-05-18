/// App state for ChaosVoice.
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

/// Holds the complete state of the ChaosVoice app.
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

  const ChaosState({
    this.serviceStatus = ChaosServiceStatus.stopped,
    this.hasMicPermission = false,
    this.hasNotificationPermission = false,
    this.isAndroid = false,
    this.isIOS = false,
    this.currentRmsLevel = 0.0,
    this.errorMessage,
    this.platformName = '',
    this.sampleRate = 16000,
    this.bufferSize = 320,
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
    );
  }

  bool get isActive => serviceStatus == ChaosServiceStatus.active;

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
          bufferSize == other.bufferSize;

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
      );
}
