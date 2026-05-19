import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../providers/effect_settings_provider.dart';
import '../../services/native_audio_bridge.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// Identifies which dropdown is being rendered.
enum _DropdownId { sampleRate, bufferSize }

/// Settings screen with audio config, routing mode, battery optimization, and debug options.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _sampleRates = [8000, 16000, 44100];
  static const _bufferSizes = [160, 320, 640];
  static const _routingModes = ['Auto-Detect', 'No-Root', 'Root'];

  int _sampleRate = AudioConstants.sampleRate;
  int _bufferSize = AudioConstants.bufferSizeDefault;
  String _routingMode = 'No-Root';
  bool _debugLogging = false;
  bool _batteryOptimizationExempted = false;
  bool _lowPowerMode = false;

  @override
  void initState() {
    super.initState();
    _checkBatteryOptimization();
    // Sync initial low power mode from provider
    final settings = ref.read(effectSettingsProvider);
    _lowPowerMode = settings.lowPowerMode;
  }

  Future<void> _checkBatteryOptimization() async {
    if (Platform.isAndroid) {
      try {
        final exempted =
            await FlutterForegroundTask.isIgnoringBatteryOptimizations;
        if (mounted) {
          setState(() => _batteryOptimizationExempted = exempted);
        }
      } catch (_) {
        if (mounted) {
          setState(() => _batteryOptimizationExempted = false);
        }
      }
    } else {
      setState(() => _batteryOptimizationExempted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          '// SETTINGS',
          style: TextStyle(
            fontFamily: 'monospace',
            letterSpacing: 3,
            fontSize: 16,
          ),
        ),
        backgroundColor: const Color(0xFF050505),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Audio Configuration ──
          _buildSectionHeader('AUDIO CONFIG'),
          const SizedBox(height: 8),
          _buildDropdownTile(
            label: 'Sample Rate',
            currentValue: '$_sampleRate Hz',
            icon: Icons.tune,
            id: _DropdownId.sampleRate,
            items: _sampleRates
                .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text('$r Hz',
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _sampleRate = v);
              }
            },
          ),
          _buildDropdownTile(
            label: 'Buffer Size',
            currentValue: '$_bufferSize samples (~${(_bufferSize * 1000 ~/ _sampleRate)}ms)',
            icon: Icons.memory,
            id: _DropdownId.bufferSize,
            items: _bufferSizes
                .map((b) => DropdownMenuItem(
                      value: b,
                      child: Text('$b samples',
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _bufferSize = v);
              }
            },
          ),

          const SizedBox(height: 24),

          // ── Routing Mode ──
          _buildSectionHeader('ROUTING MODE'),
          const SizedBox(height: 8),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.phonelink_rounded,
                        size: 18, color: Color(0xFFFF4500)),
                    SizedBox(width: 10),
                    Text(
                      'Audio Output Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._routingModes.map((mode) {
                  final isSelected = _routingMode == mode;
                  final isRoot = mode == 'Root';
                  final canSelect = !isRoot || Platform.isAndroid;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: canSelect
                          ? () {
                              setState(() => _routingMode = mode);
                              NativeAudioBridge()
                                  .setRoutingMode(mode.toLowerCase());
                              AppLogger
                                  .info('Routing mode changed to: $mode');
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF4500).withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFF4500).withOpacity(0.3)
                                : const Color(0xFF2A2A2A),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 16,
                              color: isSelected
                                  ? const Color(0xFFFF4500)
                                  : (canSelect
                                      ? Colors.grey
                                      : Colors.grey.withOpacity(0.3)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mode,
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFFFF4500)
                                          : (canSelect
                                              ? Colors.white
                                              : Colors.grey.withOpacity(0.3)),
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _routingModeDescription(mode),
                                    style: TextStyle(
                                      color: canSelect
                                          ? Colors.grey.withOpacity(0.6)
                                          : Colors.grey.withOpacity(0.2),
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isRoot && !Platform.isAndroid)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: const Text(
                                  'ANDROID',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontFamily: 'monospace',
                                    color: Colors.grey,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Battery Optimization ──
          _buildSectionHeader('POWER'),
          const SizedBox(height: 8),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.battery_std,
                        size: 18, color: Color(0xFFFF4500)),
                    SizedBox(width: 10),
                    Text(
                      'Battery Optimization',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _batteryOptimizationExempted
                      ? '✓ Battery optimization is disabled for ChaosVoice.'
                      : 'Battery optimization may kill the background service on Samsung, Xiaomi, OPPO, and other OEM devices.',
                  style: TextStyle(
                    color: _batteryOptimizationExempted
                        ? const Color(0xFF00FF41)
                        : Colors.grey.withOpacity(0.7),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                if (!_batteryOptimizationExempted && Platform.isAndroid) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _requestBatteryExemption(),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text(
                        'DISABLE BATTERY OPTIMIZATION',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF4500),
                        side: const BorderSide(
                            color: Color(0xFFFF4500), width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'See: dontkillmyapp.com for device-specific instructions',
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.4),
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.speed,
                        size: 18, color: Color(0xFFFF4500)),
                    SizedBox(width: 10),
                    Text(
                      'Low Power Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Disables the most CPU-heavy effects (reverb + pitch wobble) to reduce power consumption on low-end devices.',
                  style: TextStyle(
                    color: Colors.grey.withOpacity(0.7),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Enable Low Power Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  value: _lowPowerMode,
                  activeColor: const Color(0xFFFF4500),
                  onChanged: (v) {
                    setState(() => _lowPowerMode = v);
                    ref.read(effectSettingsProvider.notifier)
                        .update(ref.read(effectSettingsProvider).copyWith(lowPowerMode: v));
                    AppLogger.info('[Settings] Low power mode: $v');
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Debug ──
          _buildSectionHeader('DEBUG'),
          const SizedBox(height: 8),
          _buildCard(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: const Text(
                'Log DSP Statistics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Print per-chunk DSP stats to console',
                style: TextStyle(
                  color: Colors.grey.withOpacity(0.6),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
              value: _debugLogging,
              activeColor: const Color(0xFFFF4500),
              onChanged: (v) {
                setState(() => _debugLogging = v);
                if (v) {
                  AppLogger.info('[Debug] DSP statistics logging enabled');
                } else {
                  AppLogger.info('[Debug] DSP statistics logging disabled');
                }
              },
            ),
          ),

          const SizedBox(height: 24),

          // ── Platform Info ──
          _buildSectionHeader('SYSTEM INFO'),
          const SizedBox(height: 8),
          _buildInfoTile('Platform', Platform.operatingSystem),
          _buildInfoTile('OS Version', Platform.operatingSystemVersion),
          if (Platform.isAndroid)
            _buildInfoTile(
                'Android',
                'API ${Platform.operatingSystemVersion.split('(').first.trim()}'),
          if (Platform.isIOS)
            _buildInfoTile('iOS', Platform.operatingSystemVersion),
          if (Platform.isAndroid)
            _buildInfoTile(
                'Root Access',
                NativeAudioBridge().isDeviceRooted().toString()),

          const SizedBox(height: 24),

          // ── About ──
          _buildSectionHeader('ABOUT'),
          const SizedBox(height: 8),
          _buildInfoTile('App', 'ChaosVoice v1.0.0'),
          _buildInfoTile('DSP Engine', '10-Layer Real-Time'),
          _buildInfoTile('Sample Rate', '$_sampleRate Hz'),
          _buildInfoTile('Buffer Size', '$_bufferSize samples'),
          _buildInfoTile('Latency', '~${(_bufferSize * 1000 ~/ _sampleRate)}ms'),
          _buildInfoTile('Routing', _routingMode),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Request battery optimization exemption via FlutterForegroundTask.
  void _requestBatteryExemption() {
    FlutterForegroundTask.requestIgnoreBatteryOptimization();
    AppLogger.info('[Settings] Requested battery optimization exemption');
  }

  String _routingModeDescription(String mode) {
    switch (mode) {
      case 'Auto-Detect':
        return 'Automatically select best available mode';
      case 'No-Root':
        return 'VoIP apps only — WhatsApp, Telegram, Zoom';
      case 'Root':
        return 'System-wide injection — requires root + Magisk module';
      default:
        return '';
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '// $title',
        style: const TextStyle(
          color: Color(0xFFFF4500),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
      ),
      child: child,
    );
  }

  Widget _buildDropdownTile({
    required String label,
    required String currentValue,
    required IconData icon,
    required _DropdownId id,
    required List<DropdownMenuItem<int>> items,
    required ValueChanged<int?> onChanged,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFFF4500)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: id == _DropdownId.sampleRate ? _sampleRate : _bufferSize,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(
                color: Color(0xFFFF4500),
                fontSize: 13,
                fontFamily: 'monospace',
              ),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Color(0xFFFF4500), size: 18),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF1A1A1A), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.withOpacity(0.6),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFCCCCCC),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
