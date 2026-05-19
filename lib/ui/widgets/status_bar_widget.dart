import 'package:flutter/material.dart';
import '../../models/effect_settings.dart';

/// Horizontally scrollable row of effect indicator chips.
/// Shows which effects are active (orange/green) vs inactive (grey).
/// Order matches the DSP pipeline defined in README2.MD.
class StatusBarWidget extends StatelessWidget {
  final EffectSettings settings;

  const StatusBarWidget({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    // DSP pipeline order (README2.MD):
    // 1. Gain → 2. EQ → 3. Radio → 4. Crush → 5. Fuzz → 6. Clip
    // 7. Chorus → 8. Echo → 9. Reverb → 10. Crackle
    // 11. Dropout → 12. Formant → 13. Pitch
    final effects = <_EffectChip>[
      _EffectChip('Gain',
          settings.gainEnabled && settings.gainBoost > 0 && settings.masterEnabled,
          Icons.volume_up),
      _EffectChip('EQ', settings.eqBandGains.any((g) => g.abs() > 0.5),
          Icons.graphic_eq),
      _EffectChip('Radio', settings.radioFilterEnabled, Icons.radio),
      _EffectChip('Crush', settings.bitCrushEnabled, Icons.grid_on),
      _EffectChip('Fuzz', settings.fuzzEnabled, Icons.waves),
      _EffectChip('Clip', settings.clipEnabled, Icons.flash_on),
      _EffectChip('Chorus', settings.chorusEnabled, Icons.layers),
      _EffectChip('Echo', settings.echoEnabled, Icons.repeat),
      _EffectChip('Reverb', settings.reverbEnabled, Icons.meeting_room),
      _EffectChip('Crackle', settings.crackleEnabled, Icons.bolt),
      _EffectChip('Dropout', settings.dropoutEnabled, Icons.signal_wifi_off),
      _EffectChip('Formant', settings.formantShifterEnabled,
          Icons.record_voice_over),
      _EffectChip('Pitch', settings.pitchWobbleEnabled, Icons.tune),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: effects.map((e) {
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: e.active
                    ? const Color(0xFFFF4500).withOpacity(0.15)
                    : Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: e.active
                      ? const Color(0xFFFF4500).withOpacity(0.3)
                      : Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(e.icon,
                      size: 10,
                      color: e.active
                          ? const Color(0xFFFF4500)
                          : Colors.grey.withOpacity(0.5)),
                  const SizedBox(width: 3),
                  Text(
                    e.label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: e.active
                          ? const Color(0xFFFF4500)
                          : Colors.grey.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EffectChip {
  final String label;
  final bool active;
  final IconData icon;
  const _EffectChip(this.label, this.active, this.icon);
}
