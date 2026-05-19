import 'package:logger/logger.dart';

/// Centralized logging utility for ChaosVoice.
/// Wraps the `logger` package with app-specific formatting and prefix tags.
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 120,
      colors: true,
      printEmojis: true,
    ),
    level: Level.debug,
  );

  /// [AUDIO] — Audio capture, playback, and routing.
  static void audio(String message) => _logger.d('[AUDIO] $message');

  /// [SERVICE] — Foreground service lifecycle and background tasks.
  static void service(String message) => _logger.i('[SERVICE] $message');

  /// [DSP] — DSP processing, parameters, and effect engine.
  static void dsp(String message) => _logger.d('[DSP] $message');

  /// [UI] — UI state changes, navigation, and widget events.
  static void ui(String message) => _logger.d('[UI] $message');

  /// [PLATFORM] — Native bridge and platform-specific operations.
  static void platform(String message) => _logger.d('[PLATFORM] $message');

  /// General info (no tag).
  static void info(String message) => _logger.i(message);

  /// General warning.
  static void warn(String message) => _logger.w(message);

  /// General error with optional error object.
  static void error(String message, [dynamic err, StackTrace? stack]) =>
      _logger.e(message, error: err, stackTrace: stack);
}
