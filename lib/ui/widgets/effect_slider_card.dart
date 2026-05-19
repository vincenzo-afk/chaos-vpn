import 'package:flutter/material.dart';

/// Individual effect intensity slider card.
/// Each card has: effect name and icon, Slider for intensity,
/// current value label, and Switch to enable/disable.
class EffectSliderCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displayValue;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<bool> onToggle;

  const EffectSliderCard({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    this.divisions = 100,
    required this.displayValue,
    required this.enabled,
    required this.onChanged,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: enabled
              ? const Color(0xFFFF4500).withOpacity(0.15)
              : const Color(0xFF1A1A1A),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFFFF4500).withOpacity(0.1)
                  : Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon,
              size: 18,
              color: enabled ? const Color(0xFFFF4500) : Colors.grey.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        letterSpacing: 1,
                        color: enabled ? Colors.white : Colors.grey.withOpacity(0.5),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: enabled
                            ? const Color(0xFFFF4500).withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        displayValue,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? const Color(0xFFFF4500)
                              : Colors.grey.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: value.clamp(min, max),
                    min: min,
                    max: max,
                    divisions: divisions > 0 ? divisions : null,
                    onChanged: enabled ? onChanged : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Switch(
            value: enabled,
            activeColor: const Color(0xFFFF4500),
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}
