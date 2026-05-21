import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/chaos_state_provider.dart';
import 'services/foreground_task_handler.dart';
import 'services/audio_service_handler.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/effects_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/onboarding_screen.dart';
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

  runApp(const ProviderScope(child: ChaosVoiceApp()));
}

class ChaosVoiceApp extends ConsumerWidget {
  const ChaosVoiceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'ChaosVoice',
      debugShowCheckedModeBanner: false,
      theme: _buildChaosTheme(),
      home: const AppShell(),
      routes: {
        '/effects': (context) => const EffectsScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
      },
    );
  }

  /// Build the dark CRT/glitch-inspired theme for ChaosVoice.
  ThemeData _buildChaosTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFF4500), // CRT orange-red
        secondary: Color(0xFF00FF41), // CRT green
        surface: Color(0xFF111111),
        error: Color(0xFFFF0033),
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: Colors.white,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF050505),
        foregroundColor: Color(0xFFCCCCCC),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFFFF4500),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 3,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF111111),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(
            color: Color(0xFF2A2A2A),
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          backgroundColor: const Color(0xFFFF4500),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1A1A1A),
        thickness: 1,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: Color(0xFFFF4500),
        inactiveTrackColor: Color(0xFF2A2A2A),
        thumbColor: Color(0xFFFF4500),
        overlayColor: Color(0x29FF4500),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return const Color(0xFFFF4500);
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return const Color(0x4DFF4500);
          return const Color(0xFF2A2A2A);
        }),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          color: Color(0xFFCCCCCC),
          fontFamily: 'monospace',
          fontSize: 14,
        ),
        bodyMedium: TextStyle(
          color: Color(0xFFCCCCCC),
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        bodySmall: TextStyle(
          color: Color(0xFF666666),
          fontFamily: 'monospace',
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Root shell widget with ProviderScope wrapper.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _onboardingChecked = false;

  static const String _flagFileName = 'chaosvoice_onboarding_done.flag';

  /// Check if onboarding has been shown; if not, navigate to onboarding screen.
  Future<void> _checkOnboarding() async {
    if (_onboardingChecked) return;
    _onboardingChecked = true;

    final flagFile = File('${Directory.systemTemp.path}/$_flagFileName');
    final onboardingDone = flagFile.existsSync();

    if (!onboardingDone && mounted) {
      // Show onboarding as a modal route — user dismisses it to proceed
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
          fullscreenDialog: true,
        ),
      );
      // Mark onboarding as complete
      flagFile.createSync();
      AppLogger.info('[Onboarding] Marked as complete');
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize state after first frame, then show onboarding
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chaosStateProvider.notifier).init();
      _checkOnboarding();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
