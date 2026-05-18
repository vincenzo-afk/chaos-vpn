import 'package:flutter/material.dart';
import '../../models/effect_settings.dart';

/// Horizontally scrollable row of effect indicator chips.
/// Shows which effects are active (green) vs inactive (grey).
class StatusBarWidget extends StatelessWidget {
  final EffectSettings settings;

  const StatusBarWidget({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    // Order matches README features list: 1. Gain 2. Echo 3. Crackle 4. Dropout
    // 5. Fuzz 6. BitCrush 7. Pitch 8. Radio 9. Reverb 10. HardClip
    final effects = [
      _EffectChip(label: 'Gain', active: settings.gainBoost > 0 && settings.masterEnabled, icon: Icons.volume_up),
      _EffectChip(label: 'Echo', active: settings.echoEnabled, icon: Icons.repeat),
      _EffectChip(label: 'Crackle', active: settings.crackleEnabled, icon: Icons.bolt),
      _EffectChip(label: 'Dropout', active: settings.dropoutEnabled, icon: Icons.signal_wifi_off),
      _EffectChip(label: 'Fuzz', active: settings.fuzzEnabled, icon: Icons.waves),
      _EffectChip(label: 'Crush', active: settings.bitCrushEnabled, icon: Icons.grid_on),
      _EffectChip(label: 'Pitch', active: settings.pitchWobbleEnabled, icon: Icons.tune),
      _EffectChip(label: 'Radio', active: settings.radioFilterEnabled, icon: Icons.radio),
      _EffectChip(label: 'Reverb', active: settings.reverbEnabled, icon: Icons.meeting_room),
      _EffectChip(label: 'Clip', active: settings.clipEnabled, icon: Icons.flash_on),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        spacing: 4,
        children: effects.map((e) => e.build(context)).toList(),
      ),
    );
  }
}

class _EffectChip {
  final String label;
  final bool active;
  final IconData icon;

  const _EffectChip({
    required this.label,
    required this.active,
    required this.icon,
  });

  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withOpacity(0.2)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? Colors.green : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: active ? Colors.green : Colors.grey),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: active ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
