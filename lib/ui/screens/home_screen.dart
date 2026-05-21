import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/chaos_state.dart';
import '../../models/effect_settings.dart';
import '../../providers/chaos_state_provider.dart';
import '../../providers/effect_settings_provider.dart';
import '../../services/native_audio_bridge.dart';
import '../../services/permission_service.dart';
import '../widgets/chaos_toggle.dart';
import '../widgets/waveform_painter.dart';
import '../widgets/status_bar_widget.dart';


/// Routing mode options for display.
enum RoutingMode {
  noRoot('No-Root', 'VoIP apps only (WhatsApp, Telegram, Zoom)', Icons.phonelink),
  root('Root', 'System-wide (requires root + Magisk module)', Icons.security),
  auto('Auto-Detect', 'Automatically select best available mode', Icons.info_outline);

  final String label;
  final String description;
  final IconData icon;
  const RoutingMode(this.label, this.description, this.icon);
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _permissionService = PermissionService();
  final List<double> _waveformSamples = [];
  final Random _rng = Random();
  RoutingMode _routingMode = RoutingMode.noRoot;

  late AnimationController _glitchController;
  Timer? _waveformTimer;

  @override
  void initState() {
    super.initState();
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    // Check if device is rooted for routing mode
    _checkRoutingMode();

    // Start waveform simulation (runs regardless of active state, paused visually when inactive)
    _startWaveformSimulation();
  }

  Future<void> _checkRoutingMode() async {
    if (Platform.isAndroid) {
      final bridge = NativeAudioBridge();
      final rooted = await bridge.isDeviceRooted();
      if (mounted) {
        setState(() {
          _routingMode = rooted ? RoutingMode.root : RoutingMode.noRoot;
        });
      }
    }
  }

  /// Generate simulated waveform data when real PCM stream is not available.
  void _startWaveformSimulation() {
    _waveformTimer?.cancel();
    // Pre-fill with some initial data
    _waveformSamples.addAll(List.generate(200, (_) => sin(_ * 0.1) * 0.3));

    // Refresh waveform every 50ms to simulate live PCM stream
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      final chaosState = ref.read(chaosStateProvider);

      if (chaosState.isActive) {
        // Generate chaotic waveform data when service is active
        final newSamples = List<double>.generate(20, (_) {
          // Mix multiple sine waves + noise for chaotic but recognizable waveform
          final t = DateTime.now().microsecondsSinceEpoch / 1000000.0;
          return (sin(t * 20 + _rng.nextDouble()) * 0.4 +
                  sin(t * 50) * 0.25 +
                  (_rng.nextDouble() - 0.5) * 0.2)
              .clamp(-1.0, 1.0);
        });

        if (mounted) {
          setState(() {
            _waveformSamples.addAll(newSamples);
            if (_waveformSamples.length > 500) {
              _waveformSamples.removeRange(0, _waveformSamples.length - 500);
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _glitchController.dispose();
    _waveformTimer?.cancel();
    super.dispose();
  }

  void _triggerGlitch() {
    _glitchController.forward().then((_) => _glitchController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    final chaosState = ref.watch(chaosStateProvider);
    final effectSettings = ref.watch(effectSettingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '☠️',
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 8),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFF4500), Color(0xFFFF0033)],
              ).createShader(bounds),
              child: const Text(
                'CHAOSVOICE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Color(0xFFFF4500)),
            onPressed: () {
              Navigator.pushNamed(context, '/effects');
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF666666)),
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
            // ── V3 Status Panel ──
            _buildV3StatusPanel(chaosState),
            const SizedBox(height: 8),

            // ── Routing Mode Badge ──
            _buildRoutingModeBadge(),

            // ── Waveform display ──
            Container(
              height: 120,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: chaosState.isActive
                      ? const Color(0xFFFF4500).withOpacity(0.3)
                      : const Color(0xFF2A2A2A),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Stack(
                  children: [
                    CustomPaint(
                      painter: WaveformPainter(
                        samples: _waveformSamples,
                        waveColor: chaosState.isActive
                            ? const Color(0xFFFF4500)
                            : const Color(0xFF333333),
                        backgroundColor: const Color(0xFF080808),
                        isActive: chaosState.isActive,
                      ),
                      size: const Size(double.infinity, 120),
                    ),
                    // CRT scanline overlay
                    if (chaosState.isActive)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _ScanlinePainter(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Main Toggle ──
            Center(
              child: ChaosToggle(
                isActive: chaosState.isActive,
                onToggle: () {
                  ref.read(chaosStateProvider.notifier).toggleService();
                  _triggerGlitch();
                },
              ),
            ),
            const SizedBox(height: 20),

            // ── Status Text ──
            _buildStatusText(chaosState),

            // ── Error message ──
            if (chaosState.errorMessage != null)
              _buildErrorCard(chaosState.errorMessage!),

            // ── Earphone warning ──
            if (chaosState.isActive && !chaosState.earphoneConnected)
              _buildEarphoneWarning(),

            // ── Permission request ──
            if (!chaosState.hasMicPermission && !chaosState.isActive)
              _buildPermissionButton(),

            // ── Active effects panel ──
            if (chaosState.isActive) ...[
              const SizedBox(height: 16),
              _buildActiveEffectsPanel(effectSettings),
            ],

            // ── Boot persistence / crash recovery info ──
            if (chaosState.isActive || chaosState.lastActiveTimestamp != null)
              _buildPersistenceInfo(chaosState),

            // ── Active preset name ──
            if (chaosState.lastPresetName != null)
              _buildActivePresetBadge(chaosState.lastPresetName!),

            // ── Stats footer ──
            const SizedBox(height: 24),
            _buildStatsFooter(chaosState),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutingModeBadge() {
    Color badgeColor;
    switch (_routingMode) {
      case RoutingMode.root:
        badgeColor = const Color(0xFFFF0033);
        break;
      case RoutingMode.auto:
        badgeColor = const Color(0xFFFF4500);
        break;
      case RoutingMode.noRoot:
        badgeColor = const Color(0xFF666666);
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(_routingMode.icon, size: 14, color: badgeColor),
          const SizedBox(width: 8),
          Text(
            'MODE: ${_routingMode.label.toUpperCase()}',
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          Text(
            _routingMode.description,
            style: TextStyle(
              color: badgeColor.withOpacity(0.5),
              fontSize: 9,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText(ChaosState state) {
    Color statusColor;
    String statusText;
    String statusSymbol;

    switch (state.serviceStatus) {
      case ChaosServiceStatus.active:
        statusColor = const Color(0xFF00FF41);
        statusText = 'PROCESSING — Voice is being chaotically transformed';
        statusSymbol = '▶';
        break;
      case ChaosServiceStatus.starting:
        statusColor = const Color(0xFFFF4500);
        statusText = 'INITIALIZING — Starting audio pipeline...';
        statusSymbol = '●';
        break;
      case ChaosServiceStatus.error:
        statusColor = const Color(0xFFFF0033);
        statusText = 'ERROR — ${state.errorMessage ?? "Check permissions"}';
        statusSymbol = '✕';
        break;
      case ChaosServiceStatus.stopped:
        statusColor = const Color(0xFF444444);
        statusText = 'STANDBY — Tap the skull to activate chaos';
        statusSymbol = '■';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: statusColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Text(
            statusSymbol,
            style: TextStyle(
              color: statusColor,
              fontSize: 14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF0033).withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFFF0033).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF0033), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFF0033),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveEffectsPanel(EffectSettings settings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF1A1A1A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '// ACTIVE EFFECTS',
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          StatusBarWidget(settings: settings),
        ],
      ),
    );
  }

  Widget _buildPermissionButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      child: ElevatedButton.icon(
        onPressed: () async {
          await _permissionService.requestAll();
          if (mounted) {
            ref.read(chaosStateProvider.notifier).init();
          }
        },
        icon: const Icon(Icons.mic, size: 18),
        label: const Text(
          'GRANT MICROPHONE ACCESS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildActivePresetBadge(String presetName) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF00FF41).withOpacity(0.06),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF00FF41).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bookmark, size: 14, color: Color(0xFF00FF41)),
          const SizedBox(width: 8),
          const Text(
            'PRESET:',
            style: TextStyle(
              color: Color(0xFF00FF41),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              presetName,
              style: const TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersistenceInfo(ChaosState state) {
    final parts = <Widget>[];

    // Uptime
    if (state.isActive && state.lastActiveTimestamp != null) {
      parts.add(_buildStatChip(
        Icons.timer,
        'UP ${state.uptimeText}',
        const Color(0xFF00FF41),
      ));
    }

    // Session start time
    if (state.lastActiveTimestamp != null) {
      final timeStr =
          '${state.lastActiveTimestamp!.hour.toString().padLeft(2, '0')}:'
          '${state.lastActiveTimestamp!.minute.toString().padLeft(2, '0')}';
      parts.add(_buildStatChip(
        Icons.access_time,
        state.isActive ? 'Since $timeStr' : 'Last active: $timeStr',
        const Color(0xFF666666),
      ));
    }

    // Crash recovery count
    if (state.crashRecoveryCount > 0) {
      parts.add(_buildStatChip(
        Icons.healing,
        '${state.crashRecoveryCount} recovery'
            '${state.crashRecoveryCount == 1 ? '' : 'ies'}',
        const Color(0xFFFF4500),
      ));
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF1A1A1A)),
      ),
      child: Row(
        children: [
          ...parts.expand((w) => [
                w,
                const SizedBox(width: 12),
              ]),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsFooter(ChaosState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'v3.0.0',
          style: TextStyle(
            color: Colors.grey.withOpacity(0.3),
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '${state.sampleRate}Hz',
          style: TextStyle(
            color: Colors.grey.withOpacity(0.3),
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '${state.bufferSize}samples',
          style: TextStyle(
            color: Colors.grey.withOpacity(0.3),
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 16),
        if (state.crashRecoveryCount > 0)
          Text(
            '${state.crashRecoveryCount}x crash',
            style: TextStyle(
              color: const Color(0xFFFF4500).withOpacity(0.4),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
      ],
    );
  }
  /// V3 status panel showing VPN / Projection / Earphone states.
  Widget _buildV3StatusPanel(ChaosState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF1A1A1A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '// V3 ENGINE STATUS',
            style: TextStyle(
              color: Color(0xFF444444),
              fontSize: 9,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildV3StatusChip(
                'VPN',
                state.vpnActive,
                state.vpnPermissionGranted,
                Icons.security,
              ),
              const SizedBox(width: 8),
              _buildV3StatusChip(
                'PROJECTION',
                state.projectionServiceRunning,
                state.mediaProjectionGranted,
                Icons.screen_share,
              ),
              const SizedBox(width: 8),
              _buildV3StatusChip(
                'BATTERY',
                state.batteryOptimizationExempted,
                state.batteryOptimizationExempted,
                Icons.battery_charging_full,
              ),
              const SizedBox(width: 8),
              _buildV3StatusChip(
                'EARPHONES',
                state.earphoneConnected,
                state.earphoneConnected,
                Icons.headphones,
              ),
            ],
          ),
          if (!state.isActive && state.v3SetupProgress < 3) ...
          [
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: state.v3SetupProgress / 3.0,
              backgroundColor: const Color(0xFF1A1A1A),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF4500)),
              minHeight: 2,
            ),
            const SizedBox(height: 4),
            Text(
              'Setup: ${state.v3SetupProgress}/3 permissions granted',
              style: const TextStyle(
                color: Color(0xFF555555),
                fontSize: 9,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildV3StatusChip(
    String label,
    bool active,
    bool granted,
    IconData icon,
  ) {
    final color = active
        ? const Color(0xFF00FF41)
        : granted
            ? const Color(0xFFFF4500)
            : const Color(0xFF333333);
    final text = active ? '●' : (granted ? '◌' : '○');
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(height: 3),
            Text(
              text,
              style: TextStyle(color: color, fontSize: 8, fontFamily: 'monospace'),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 7,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Warning when active but no earphones detected.
  Widget _buildEarphoneWarning() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFAA00).withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFFFAA00).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.headset_off, color: Color(0xFFFFAA00), size: 14),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '⚠ No earphones detected. Plug in earphones for best results. '  
              'Without them, the other person may hear your clean voice first.',
              style: TextStyle(
                color: Color(0xFFFFAA00),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CRT scanline overlay painter for the glitch aesthetic.
class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.05)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
