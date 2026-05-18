import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/logger.dart';

/// Settings screen with sample rate, buffer size, platform info, and debug options.
class SettingsScreen extends StatefulWidget {
  final int sampleRate;
  final int bufferSize;
  final ValueChanged<int> onSampleRateChanged;
  final ValueChanged<int> onBufferSizeChanged;

  const SettingsScreen({
    super.key,
    required this.sampleRate,
    required this.bufferSize,
    required this.onSampleRateChanged,
    required this.onBufferSizeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _sampleRates = [8000, 16000, 44100];
  static const _bufferSizes = [160, 320, 640];
  bool _debugLogging = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Audio Configuration'),
          _buildDropdownTile(
            'Sample Rate',
            widget.sampleRate,
            _sampleRates,
            (v) => widget.onSampleRateChanged(v!),
            'Hz',
          ),
          _buildDropdownTile(
            'Buffer Size',
            widget.bufferSize,
            _bufferSizes,
            (v) => widget.onBufferSizeChanged(v!),
            ' samples',
          ),
          const Divider(color: Colors.grey, height: 32),
          _buildSectionHeader('Debug'),
          _buildDebugToggle(),
          const Divider(color: Colors.grey, height: 32),
          _buildSectionHeader('Platform Info'),
          _buildInfoTile('Platform', Platform.operatingSystem),
          _buildInfoTile('OS Version', Platform.operatingSystemVersion),
          if (Platform.isAndroid) _buildInfoTile('Android', 'API ${Platform.operatingSystemVersion}'),
          if (Platform.isIOS) _buildInfoTile('iOS', Platform.operatingSystemVersion),
          const Divider(color: Colors.grey, height: 32),
          _buildSectionHeader('About'),
          _buildInfoTile('App', 'ChaosVoice v1.0.0'),
          _buildInfoTile('DSP Engine', '10-Layer Real-Time'),
          _buildInfoTile('Sample Rate', '${widget.sampleRate} Hz'),
          _buildInfoTile('Buffer Size', '${widget.bufferSize} samples'),
          _buildInfoTile('Latency', '~${(widget.bufferSize / widget.sampleRate * 1000).round()}ms'),
        ],
      ),
    );
  }

  Widget _buildDebugToggle() {
    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: const Text(
          'Log DSP Statistics',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        subtitle: const Text(
          'Print per-chunk DSP stats to console',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        value: _debugLogging,
        activeColor: Colors.orange,
        onChanged: (v) {
          setState(() {
            _debugLogging = v;
          });
          if (v) {
            AppLogger.info('[Debug] DSP statistics logging enabled');
          } else {
            AppLogger.info('[Debug] DSP statistics logging disabled');
          }
        },
      ),
    );
  }
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildDropdownTile(
    String label,
    int currentValue,
    List<int> values,
    ValueChanged<int?> onChanged,
    String suffix,
  ) {
    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        trailing: DropdownButton<int>(
          value: currentValue,
          dropdownColor: const Color(0xFF2A2A2A),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          underline: const SizedBox(),
          items: values
              .map((v) => DropdownMenuItem(
                    value: v,
                    child: Text('$v$suffix'),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        title: Text(
          label,
          style: TextStyle(
            color: Colors.grey.withOpacity(0.8),
            fontSize: 13,
          ),
        ),
        trailing: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
