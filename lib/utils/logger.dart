import 'package:logger/logger.dart';

/// Centralized logging utility for ChaosVoice.
/// Wraps the `logger` package with app-specific formatting.
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    level: Level.debug,
  );

  static void debug(String message) => _logger.d(message);
  static void info(String message) => _logger.i(message);
  static void warn(String message) => _logger.w(message);
  static void error(String message, [dynamic error]) =>
      _logger.e(message, error: error);
}
