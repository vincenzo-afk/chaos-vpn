import 'package:audio_service/audio_service.dart';
import '../utils/logger.dart';

/// Audio service handler for ChaosVoice background audio.
/// Integrates with audio_service plugin for Android/iOS background playback.
class ChaosVoiceAudioHandler extends BaseAudioHandler {
  static final ChaosVoiceAudioHandler _instance =
      ChaosVoiceAudioHandler._();
  factory ChaosVoiceAudioHandler() => _instance;
  ChaosVoiceAudioHandler._();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await AudioService.init(
      config: AudioServiceConfig(
        androidNotificationChannelId: 'chaosvoice_channel',
        androidNotificationChannelName: 'ChaosVoice Service',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'ic_mic_chaos',
      ),
      builder: () => this,
    );

    AppLogger.info('[AudioService] Handler initialized');
  }

  Future<void> startService() async {
    AppLogger.info('[AudioService] Start requested');
  }
}
