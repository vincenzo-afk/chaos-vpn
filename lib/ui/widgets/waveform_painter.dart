import 'dart:math';
import 'package:flutter/material.dart';

/// CustomPainter that renders a live waveform visualization from PCM data.
/// Features CRT-style glow, gradient coloring, and filled waveform area.
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
      // Draw idle line with subtle pulse indicator
      final idlePaint = Paint()
        ..color = waveColor.withOpacity(0.25)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final centerY = size.height / 2;

      // Draw a subtle reference line
      canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), idlePaint);

      // Draw minimal grid lines
      final gridPaint = Paint()
        ..color = waveColor.withOpacity(0.04)
        ..strokeWidth = 0.5;
      for (int i = 1; i < 4; i++) {
        final y = size.height * i / 4;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }

      // Draw "STANDBY" text
      final textPainter = TextPainter(
        text: TextSpan(
          text: '● STANDBY',
          style: TextStyle(
            color: waveColor.withOpacity(0.15),
            fontSize: 9,
            fontFamily: 'monospace',
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - textPainter.width - 8, size.height - textPainter.height - 4));

      return;
    }

    _drawWaveform(canvas, size);
  }

  void _drawWaveform(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final halfHeight = size.height / 2 - 6;
    final step = max(1, (samples.length / size.width).ceil());
    final displayCount = (size.width).toInt();

    // Build path for the waveform line
    final linePath = Path();
    // Build path for the filled area (bottom half)
    final fillPath = Path();

    bool pathStarted = false;
    for (int i = 0; i < displayCount && i * step < samples.length; i++) {
      final x = (i / displayCount) * size.width;
      final sample = samples[i * step].clamp(-1.0, 1.0);
      final y = centerY - (sample * halfHeight); // flip so positive = up

      if (!pathStarted) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, y);
        pathStarted = true;
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Close fill path
    if (displayCount > 0) {
      final lastX = ((displayCount - 1) / displayCount) * size.width;
      fillPath.lineTo(lastX, centerY);
      fillPath.lineTo(0, centerY);
      fillPath.close();
    }

    // Draw glow layer
    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          waveColor.withOpacity(0.08),
          waveColor.withOpacity(0.03),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(fillPath, glowPaint);

    // Draw filled area under waveform
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          waveColor.withOpacity(0.18),
          waveColor.withOpacity(0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Draw the main waveform line with gradient
    final wavePaint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        colors: [
          waveColor,
          waveColor.withOpacity(0.7),
          waveColor,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(linePath, wavePaint);

    // Draw a brighter highlight line on top
    final highlightPaint = Paint()
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.3);
    canvas.drawPath(linePath, highlightPaint);

    // Draw peak markers (dots at sample peaks)
    final peakPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < displayCount && i * step < samples.length; i += 6) {
      final x = (i / displayCount) * size.width;
      final sample = samples[i * step].clamp(-1.0, 1.0);
      final y = centerY - (sample * halfHeight);
      canvas.drawCircle(Offset(x, y), 1.5, peakPaint);
    }

    // Draw center line
    final centerLinePaint = Paint()
      ..color = waveColor.withOpacity(0.06)
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), centerLinePaint);

    // Draw corner watermark
    final watermarkPainter = TextPainter(
      text: TextSpan(
        text: 'CHAOS • LIVE',
        style: TextStyle(
          color: waveColor.withOpacity(0.08),
          fontSize: 8,
          fontFamily: 'monospace',
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    watermarkPainter.layout();
    watermarkPainter.paint(canvas, Offset(6, size.height - watermarkPainter.height - 3));
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.isActive != isActive;
  }
}
