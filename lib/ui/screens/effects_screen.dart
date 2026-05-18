import 'package:flutter/material.dart';
import '../../models/effect_settings.dart';
import '../widgets/effect_slider.dart';

/// Effects configuration screen with per-effect sliders and toggles.
class EffectsScreen extends StatefulWidget {
  final EffectSettings initialSettings;
  final ValueChanged<EffectSettings> onSettingsChanged;

  const EffectsScreen({
    super.key,
    required this.initialSettings,
    required this.onSettingsChanged,
  });

  @override
  State<EffectsScreen> createState() => _EffectsScreenState();
}

class _EffectsScreenState extends State<EffectsScreen> {
  late EffectSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  void _updateSettings(EffectSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
    widget.onSettingsChanged(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('Effects Configuration'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          EffectSliderCard(
            label: 'Volume Gain',
            icon: Icons.volume_up,
            value: _settings.gainFactor,
            min: 1.0,
            max: 8.0,
            displayValue: '${_settings.gainFactor.toStringAsFixed(1)}x',
            enabled: _settings.gainEnabled,
            onChanged: (v) => _updateSettings(_settings.copyWith(gainFactor: v)),
            onToggle: (v) => _updateSettings(_settings.copyWith(gainEnabled: v)),
          ),
          EffectSliderCard(
            label: 'Radio Filter',
            icon: Icons.radio,
            value: 1,
            min: 0,
            max: 1,
            divisions: 1,
            displayValue: '300–3400 Hz',
            enabled: _settings.bandpassEnabled,
            onChanged: (_) {},
            onToggle: (v) => _updateSettings(_settings.copyWith(bandpassEnabled: v)),
          ),
          EffectSliderCard(
            label: 'Bit Crusher',
            icon: Icons.grid_on,
            value: _settings.bitDepth.toDouble(),
            min: 2,
            max: 16,
            divisions: 14,
            displayValue: '${_settings.bitDepth}-bit',
            enabled: _settings.bitCrushEnabled,
            onChanged: (v) => _updateSettings(_settings.copyWith(bitDepth: v.round())),
            onToggle: (v) => _updateSettings(_settings.copyWith(bitCrushEnabled: v)),
          ),
          EffectSliderCard(
            label: 'Soft Clip Distortion',
            icon: Icons.waves,
            value: _settings.softDrive,
            min: 1.0,
            max: 10.0,
            displayValue: '${_settings.softDrive.toStringAsFixed(1)}x',
            enabled: _settings.softClipEnabled,
            onChanged: (v) => _updateSettings(_settings.copyWith(softDrive: v)),
            onToggle: (v) => _updateSettings(_settings.copyWith(softClipEnabled: v)),
          ),
          EffectSliderCard(
            label: 'Hard Clip Threshold',
            icon: Icons.flash_on,
            value: _settings.hardClipThreshold,
            min: 0.1,
            max: 1.0,
            divisions: 90,
            displayValue: '${(_settings.hardClipThreshold * 100).round()}%',
            enabled: _settings.hardClipEnabled,
            onChanged: (v) => _updateSettings(_settings.copyWith(hardClipThreshold: v)),
            onToggle: (v) => _updateSettings(_settings.copyWith(hardClipEnabled: v)),
          ),
          EffectSliderCard(
            label: 'Reverb Mix',
            icon: Icons.meeting_room,
            value: _settings.reverbMix,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            displayValue: '${(_settings.reverbMix * 100).round()}%',
            enabled: _settings.reverbEnabled,
            onChanged: (v) => _updateSettings(_settings.copyWith(reverbMix: v)),
            onToggle: (v) => _updateSettings(_settings.copyWith(reverbEnabled: v)),
          ),
          EffectSliderCard(
            label: 'Crackle Probability',
            icon: Icons.bolt,
            value: _settings.crackleProb,
            min: 0.0,
            max: 0.15,
            divisions: 150,
            displayValue: '${(_settings.crackleProb * 100).round()}%',
            enabled: _settings.crackleEnabled,
            onChanged: (v) => _updateSettings(_settings.copyWith(crackleProb: v)),
            onToggle: (v) => _updateSettings(_settings.copyWith(crackleEnabled: v)),
          ),
          EffectSliderCard(
            label: 'Dropout Probability',
            icon: Icons.signal_wifi_off,
            value: _settings.dropoutProb,
            min: 0.0,
            max: 0.20,
            divisions: 200,
            displayValue: '${(_settings.dropoutProb * 100).round()}%',
            enabled: _settings.dropoutEnabled,
            onChanged: (v) => _updateSettings(_settings.copyWith(dropoutProb: v)),
            onToggle: (v) => _updateSettings(_settings.copyWith(dropoutEnabled: v)),
          ),
          EffectSliderCard(
            label: 'Pitch Wobble',
            icon: Icons.tune,
            value: 1,
            min: 0,
            max: 1,
            divisions: 1,
            displayValue: '±3 semitones',
            enabled: _settings.pitchWobbleEnabled,
            onChanged: (_) {},
            onToggle: (v) => _updateSettings(_settings.copyWith(pitchWobbleEnabled: v)),
          ),
          EffectSliderCard(
            label: 'Echo Delay',
            icon: Icons.repeat,
            value: _settings.echoMixDry,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            displayValue: '${(_settings.echoMixDry * 100).round()}% dry',
            enabled: _settings.echoEnabled,
            onChanged: (v) => _updateSettings(_settings.copyWith(echoMixDry: v)),
            onToggle: (v) => _updateSettings(_settings.copyWith(echoEnabled: v)),
          ),
          const SizedBox(height: 8),
          // Echo 100ms tap mix
          Padding(
            padding: const EdgeInsets.only(left: 68),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Text(
                  '100ms tap',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.withOpacity(0.7),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _settings.echoMix100,
                    min: 0.0,
                    max: 0.8,
                    divisions: 80,
                    activeColor: Colors.orange.withOpacity(0.6),
                    inactiveColor: Colors.grey.withOpacity(0.2),
                    onChanged: _settings.echoEnabled
                        ? (v) => _updateSettings(_settings.copyWith(echoMix100: v))
                        : null,
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(_settings.echoMix100 * 100).round()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.orange.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Echo 250ms tap mix
          Padding(
            padding: const EdgeInsets.only(left: 80),
            child: Row(
              children: [
                const SizedBox(width: 24),
                Text(
                  '250ms tap',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.withOpacity(0.7),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _settings.echoMix250,
                    min: 0.0,
                    max: 0.8,
                    divisions: 80,
                    activeColor: Colors.orange.withOpacity(0.6),
                    inactiveColor: Colors.grey.withOpacity(0.2),
                    onChanged: _settings.echoEnabled
                        ? (v) => _updateSettings(_settings.copyWith(echoMix250: v))
                        : null,
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(_settings.echoMix250 * 100).round()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.orange.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () {
                _updateSettings(const EffectSettings());
              },
              icon: const Icon(Icons.restart_alt, color: Colors.red),
              label: const Text(
                'RESET TO DEFAULT',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
