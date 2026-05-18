import 'dart:math';
import 'package:flutter/material.dart';

/// CustomPainter that renders a live waveform visualization from PCM data.
class WaveformPainter extends CustomPainter {
  final List<double> samples;
  final Color waveColor;
  final Color backgroundColor;
  final bool isActive;

  WaveformPainter({
    this.samples = const [],
    this.waveColor = const Color(0xFFFF4500),
    this.backgroundColor = const Color(0xFF1A1A1A),
    this.isActive = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(12),
      ),
      bgPaint,
    );

    if (samples.isEmpty || !isActive) {
      // Draw idle line
      final idlePaint = Paint()
        ..color = waveColor.withOpacity(0.3)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final centerY = size.height / 2;
      canvas.drawLine(
        Offset(0, centerY),
        Offset(size.width, centerY),
        idlePaint,
      );
      return;
    }

    // Draw waveform
    final wavePaint = Paint()
      ..color = waveColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final centerY = size.height / 2;
    final halfHeight = size.height / 2 - 4;

    // Ensure we don't exceed sample bounds
    final step = max(1, (samples.length / size.width).ceil());
    final displaySamples = max(1, (size.width).toInt());

    for (int i = 0; i < displaySamples && i * step < samples.length; i++) {
      final x = (i / displaySamples) * size.width;
      final sample = samples[i * step].clamp(-1.0, 1.0);
      final y = centerY + (sample * halfHeight);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, wavePaint);

    // Draw glow effect if active
    if (isActive) {
      final glowPaint = Paint()
        ..color = waveColor.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(path, glowPaint);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.isActive != isActive;
  }
}
