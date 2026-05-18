import 'models/effect_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/native_audio_bridge.dart';
import 'services/foreground_task_handler.dart';
import 'services/audio_service_handler.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/effects_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'utils/constants.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0D0D0D),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize foreground task configuration
  initForegroundTask();

  // Initialize audio service handler for background audio
  await ChaosVoiceAudioHandler().init();

  AppLogger.info('ChaosVoice starting...');

  runApp(const ChaosVoiceApp());
}

class ChaosVoiceApp extends StatelessWidget {
  const ChaosVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChaosVoice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: const ColorScheme.dark(
          primary: Colors.orange,
          secondary: Colors.red,
          surface: Color(0xFF1A1A1A),
          error: Colors.red,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1A1A),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Colors.grey),
        ),
      ),
      home: const AppShell(),
      routes: {
        '/effects': (context) => const _EffectsScreenWrapper(),
        '/settings': (context) => const _SettingsScreenWrapper(),
      },
    );
  }
}

/// Root shell widget that manages app state.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}

/// Wrapper for effects screen that reads state from parent.
class _EffectsScreenWrapper extends StatefulWidget {
  const _EffectsScreenWrapper();

  @override
  State<_EffectsScreenWrapper> createState() => _EffectsScreenWrapperState();
}

class _EffectsScreenWrapperState extends State<_EffectsScreenWrapper> {
  EffectSettings _settings = const EffectSettings();

  void _onEffectsChanged(EffectSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
    // Push updated params to native layer
    NativeAudioBridge().updateParams(
      gain: newSettings.gainBoost,
      crackleIntensity: newSettings.crackleIntensity,
      dropoutRate: newSettings.dropoutRate,
      bitCrushDepth: newSettings.bitCrushDepth,
      clipThreshold: newSettings.clipThreshold,
    );
    AppLogger.info('Effects settings updated');
  }

  @override
  Widget build(BuildContext context) {
    return EffectsScreen(
      initialSettings: _settings,
      onSettingsChanged: _onEffectsChanged,
    );
  }
}

/// Wrapper for settings screen.
class _SettingsScreenWrapper extends StatelessWidget {
  const _SettingsScreenWrapper();

  @override
  Widget build(BuildContext context) {
    return SettingsScreen(
      sampleRate: AudioConstants.sampleRate,
      bufferSize: AudioConstants.bufferSize,
      onSampleRateChanged: (rate) {
        AppLogger.info('Sample rate changed to $rate');
      },
      onBufferSizeChanged: (size) {
        AppLogger.info('Buffer size changed to $size');
      },
    );
  }
}
