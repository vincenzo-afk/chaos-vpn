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
          // ── Volume Gain ──
          EffectSliderCard(
            label: 'Volume Gain',
            icon: Icons.volume_up,
            value: _settings.gainBoost,
            min: 1.0,
            max: 8.0,
            displayValue: '${_settings.gainBoost.toStringAsFixed(1)}x',
            enabled: _settings.masterEnabled && _settings.gainBoost > 0,
            onChanged: (v) => _updateSettings(_settings.copyWith(gainBoost: v)),
            onToggle: (v) => _updateSettings(_settings.copyWith(masterEnabled: v)),
          ),
          // ── Radio Filter ──
          EffectSliderCard(
            label: 'Radio Filter',
            icon: Icons.radio,
            value: 1,
            min: 0,
            max: 1,
            divisions: 1,
            displayValue: '300–3400 Hz',
            enabled: _settings.radioFilterEnabled,
            onChanged: (_) {},
            onToggle: (v) => _updateSettings(_settings.copyWith(radioFilterEnabled: v)),
          ),
          // ── Bit Crusher ──
          EffectSliderCard(
            label: 'Bit Crusher',
            icon: Icons.grid_on,
            value: _settings.bitCrushDepth.toDouble(),
            min: 2,
            max: 16,
            divisions: 14,
            displayValue: '${_settings.bitCrushDepth}-bit',
            enabled: _settings.bitCrushEnabled,
            onChanged: (v) => _updateSettings(_settings.copyWith(bitCrushDepth: v.round())),
            onToggle: (v) => _updateSettings(_settings.copyWith(bitCrushEnabled: v)),
          ),
          // ── Fuzz Distortion ──
          EffectSliderCard(
            label: 'Fuzz Distortion',
            icon: Icons.waves,
            value: _settings.fuzzDrive,
            min: 1.0,
            max: 10.0,
            displayValue: '${_settings.fuzzDrive.toStringAsFixed(1)}x',
            enabled: _settings.fuzzEnabled,
            onChanged: (v) => _updateSettings(_settings.copyWith(fuzzDrive: v)),
            onToggle: (v) => _updateSettings(_settings.copyWith(fuzzEnabled: v)),
          ),
          // ── Hard Clip Threshold ──
          EffectSliderCard(
            label: 'Clip Threshold',
            icon: Icons.flash_on,
            value: _settings.clipThreshold,
            min: 0.1,
            max: 1.0,
            divisions: 90,
            displayValue: '${(_settings.clipThreshold * 100).round()}%',
            enabled: _settings.clipEnabled,
            onChanged: (v) => _updateSettings(_settings.copyWith(clipThreshold: v)),
            onToggle: (v) => _updateSettings(_settings.copyWith(clipEnabled: v)),
          ),
          // ── Reverb Room Size ──
          EffectSliderCard(
            label: 'Reverb Room',
            icon: Icons.meeting_room,
            value: _settings.reverbRoomSize,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            displayValue: '${(_settings.reverbRoomSize * 100).round()}%',
            enabled: _settings.reverbEnabled,
            onChanged: (v) => _updateSettings(_settings.copyWith(reverbRoomSize: v)),
            onToggle: (v) => _updateSettings(_settings.copyWith(reverbEnabled: v)),
          ),
          // ── Crackle Intensity ──
          EffectSliderCard(
            label: 'Crackle Intensity',
            icon: Icons.bolt,
            value: _settings.crackleIntensity,
            min: 0.0,
            max: 0.15,
            divisions: 150,
            displayValue: '${(_settings.crackleIntensity * 100).round()}%',
            enabled: _settings.crackleEnabled,
            onChanged: (v) => _updateSettings(_settings.copyWith(crackleIntensity: v)),
            onToggle: (v) => _updateSettings(_settings.copyWith(crackleEnabled: v)),
          ),
          // ── Dropout Rate ──
          EffectSliderCard(
            label: 'Dropout Rate',
            icon: Icons.signal_wifi_off,
            value: _settings.dropoutRate,
            min: 0.0,
            max: 0.20,
            divisions: 200,
            displayValue: '${(_settings.dropoutRate * 100).round()}%',
            enabled: _settings.dropoutEnabled,
            onChanged: (v) => _updateSettings(_settings.copyWith(dropoutRate: v)),
            onToggle: (v) => _updateSettings(_settings.copyWith(dropoutEnabled: v)),
          ),
          // ── Pitch Wobble Range ──
          EffectSliderCard(
            label: 'Pitch Wobble',
            icon: Icons.tune,
            value: _settings.pitchWobbleRange,
            min: 0.0,
            max: 12.0,
            divisions: 120,
            displayValue: '±${_settings.pitchWobbleRange.toStringAsFixed(1)} st',
            enabled: _settings.pitchWobbleEnabled,
            onChanged: (v) => _updateSettings(_settings.copyWith(pitchWobbleRange: v)),
            onToggle: (v) => _updateSettings(_settings.copyWith(pitchWobbleEnabled: v)),
          ),
          // ── Echo Delay ──
          EffectSliderCard(
            label: 'Echo Delay',
            icon: Icons.repeat,
            value: _settings.echoDelay,
            min: 20.0,
            max: 500.0,
            divisions: 96,
            displayValue: '${_settings.echoDelay.round()}ms',
            enabled: _settings.echoEnabled,
            onChanged: (v) => _updateSettings(_settings.copyWith(echoDelay: v)),
            onToggle: (v) => _updateSettings(_settings.copyWith(echoEnabled: v)),
          ),
          // ── Echo Decay ──
          Padding(
            padding: const EdgeInsets.only(left: 68),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Text(
                  'Decay',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.withOpacity(0.7),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _settings.echoDecay,
                    min: 0.0,
                    max: 0.9,
                    divisions: 90,
                    activeColor: Colors.orange.withOpacity(0.6),
                    inactiveColor: Colors.grey.withOpacity(0.2),
                    onChanged: _settings.echoEnabled
                        ? (v) => _updateSettings(_settings.copyWith(echoDecay: v))
                        : null,
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(_settings.echoDecay * 100).round()}%',
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
          // ── Reset ──
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
