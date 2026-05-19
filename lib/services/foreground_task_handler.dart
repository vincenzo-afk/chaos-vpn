import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../utils/logger.dart';
import 'native_audio_bridge.dart';

/// Callback handler for flutter_foreground_task.
/// Runs in a background isolate — keeps the DSP service alive
/// even when the app is minimized or the screen is off.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(ChaosVoiceTaskHandler());
}

class ChaosVoiceTaskHandler extends TaskHandler {
  final _bridge = NativeAudioBridge();

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    AppLogger.info('[ForegroundTask] Task started at $timestamp');
    await _bridge.startService();
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    // Health check — restart service if it died
    _bridge.isServiceRunning().then((running) {
      if (!running) {
        AppLogger.warn('[ForegroundTask] Service not running — restarting...');
        _bridge.startService();
      }
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    AppLogger.info('[ForegroundTask] Task destroyed at $timestamp');
    await _bridge.stopService();
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'btn_stop') {
      FlutterForegroundTask.stopService();
    }
  }
}

/// Initialize the foreground task notification configuration.
void initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'chaosvoice_channel',
      channelName: 'ChaosVoice Service',
      channelDescription:
          'ChaosVoice is running and transforming your microphone.',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      iconData: const NotificationIconData(
        resType: ResourceType.drawable,
        resPrefix: ResourcePrefix.ic,
        name: 'ic_mic_chaos',
      ),
      buttons: [
        const NotificationButton(
          id: 'btn_stop',
          text: 'Stop ChaosVoice',
        ),
      ],
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 5000,
      isOnceEvent: false,
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}
