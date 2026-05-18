import 'package:flutter/material.dart';

/// Individual effect intensity slider card with toggle switch.
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
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface.withOpacity(0.8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 24, color: enabled ? Colors.orange : Colors.grey),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: enabled ? Colors.white : Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        displayValue,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: enabled
                              ? Colors.orange.withOpacity(0.9)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: divisions,
                    activeColor: Colors.orange,
                    inactiveColor: Colors.grey.withOpacity(0.3),
                    onChanged: enabled ? onChanged : null,
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              activeColor: Colors.orange,
              onChanged: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}
