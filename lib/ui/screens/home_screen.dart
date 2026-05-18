import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/chaos_state.dart';
import '../../models/effect_settings.dart';
import '../../services/permission_service.dart';
import '../../services/native_audio_bridge.dart';
import '../widgets/chaos_toggle.dart';
import '../widgets/waveform_painter.dart';
import '../widgets/status_bar_widget.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _permissionService = PermissionService();
  final _nativeBridge = NativeAudioBridge();

  ChaosState _state = const ChaosState();
  EffectSettings _settings = const EffectSettings();
  final List<double> _waveformSamples = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _checkServiceStatus();
  }

  Future<void> _checkPermissions() async {
    final micGranted = await _permissionService.hasMicPermission();
    final notifGranted = await _permissionService.hasNotificationPermission();
    setState(() {
      _state = _state.copyWith(
        hasMicPermission: micGranted,
        hasNotificationPermission: notifGranted,
      );
    });
    AppLogger.info('Permissions — mic: $micGranted, notif: $notifGranted');
  }

  Future<void> _checkServiceStatus() async {
    final running = await _nativeBridge.isServiceRunning();
    setState(() {
      _state = _state.copyWith(
        serviceStatus:
            running ? ChaosServiceStatus.active : ChaosServiceStatus.stopped,
      );
    });
  }

  Future<void> _toggleService() async {
    if (_state.isActive) {
      await _stopService();
    } else {
      await _startService();
    }
  }

  Future<void> _startService() async {
    // Ensure permissions first
    final micOk = await _permissionService.requestMicPermission();
    if (!micOk) {
      setState(() {
        _state = _state.copyWith(
          errorMessage: 'Microphone permission is required.',
        );
      });
      return;
    }

    setState(() {
      _state = _state.copyWith(
        serviceStatus: ChaosServiceStatus.starting,
        clearError: true,
      );
    });

    final started = await _nativeBridge.startService();
    setState(() {
      _state = _state.copyWith(
        serviceStatus: started
            ? ChaosServiceStatus.active
            : ChaosServiceStatus.error,
        errorMessage: started ? null : 'Failed to start audio service.',
        hasMicPermission: true,
      );
    });

    if (started) {
      // Simulate waveform samples for demo
      _simulateWaveform();
    }
  }

  Future<void> _stopService() async {
    await _nativeBridge.stopService();
    setState(() {
      _state = _state.copyWith(
        serviceStatus: ChaosServiceStatus.stopped,
        clearError: true,
      );
      _waveformSamples.clear();
    });
  }

  void _simulateWaveform() {
    // Generate fake waveform data for visualization when service is active
    // In production, this would come from flutter_voice_processor callbacks
    _waveformSamples.clear();
    for (int i = 0; i < AudioConstants.bufferSize; i++) {
      _waveformSamples.add(
        sin(i * 0.1) * 0.5 + (_rng.nextDouble() - 0.5) * 0.2,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text(
          '☠️ ChaosVoice',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Waveform display
            Container(
              height: 120,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  painter: WaveformPainter(
                    samples: _waveformSamples,
                    isActive: _state.isActive,
                  ),
                  size: const Size(double.infinity, 120),
                ),
              ),
            ),

            // Main toggle
            Center(
              child: ChaosToggle(
                isActive: _state.isActive,
                onToggle: _toggleService,
              ),
            ),
            const SizedBox(height: 24),

            // Status text
            _buildStatusText(),
            const SizedBox(height: 16),

            // Error message
            if (_state.errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _state.errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Permission request button if needed
            if (!_state.hasMicPermission && !_state.isActive)
              _buildPermissionButton(),

            // Active effects status
            if (_state.isActive) ...[
              const Divider(color: Colors.grey),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'ACTIVE EFFECTS',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
              ),
              StatusBarWidget(settings: _settings),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/effects');
                },
                icon: const Icon(Icons.tune, color: Colors.orange),
                label: const Text(
                  'Configure Effects →',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ],

            // Version / info
            const SizedBox(height: 32),
            Text(
              'v1.0.0',
              style: TextStyle(
                color: Colors.grey.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusText() {
    Color statusColor;
    String statusText;

    switch (_state.serviceStatus) {
      case ChaosServiceStatus.active:
        statusColor = Colors.green;
        statusText = '🔴 ACTIVE — Voice is being chaotically transformed';
        break;
      case ChaosServiceStatus.starting:
        statusColor = Colors.yellow;
        statusText = '⏳ Starting service...';
        break;
      case ChaosServiceStatus.error:
        statusColor = Colors.red;
        statusText = '❌ Error — Check permissions and try again';
        break;
      case ChaosServiceStatus.stopped:
        statusColor = Colors.grey;
        statusText = '⏸️ Stopped — Tap the skull to activate chaos';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: statusColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPermissionButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: ElevatedButton.icon(
        onPressed: () async {
          final granted = await _permissionService.requestAll();
          setState(() {
            _state = _state.copyWith(
              hasMicPermission: granted,
              hasNotificationPermission: granted,
            );
          });
        },
        icon: const Icon(Icons.mic),
        label: const Text('Grant Microphone Permission'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
