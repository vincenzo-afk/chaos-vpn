import 'dart:math' as math;
import 'package:flutter/material.dart';

/// CustomPainter that renders a real-time spectrogram from PCM audio data.
///
/// Uses FFT to compute frequency bins and renders them as a scrolling
/// heat-map with time on the X axis and frequency on the Y axis.
/// Frequency range: 0 Hz to Nyquist (sampleRate / 2).
class SpectrogramPainter extends CustomPainter {
  final List<List<double>> spectrogramData;
  final ColorScheme colors;
  final bool isActive;
  final int sampleRate;

  SpectrogramPainter({
    this.spectrogramData = const [],
    this.isActive = false,
    this.sampleRate = 16000,
    ColorScheme? colors,
  }) : colors = colors ?? const ColorScheme.dark(
          primary: Color(0xFFFF4500),
          secondary: Color(0xFF00FF41),
          surface: Color(0xFF111111),
          error: Color(0xFFFF0033),
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onSurface: Colors.white,
          onError: Colors.white,
        );

  // Pre-computed color map from black -> blue -> green -> yellow -> red -> white
  static const List<Color> _heatmapColors = [
    Color(0xFF000000), // silence
    Color(0xFF000044), // very quiet
    Color(0xFF000088), // quiet
    Color(0xFF0044AA), // low
    Color(0xFF0088CC), // low-mid
    Color(0xFF44AA44), // mid
    Color(0xFF88CC22), // mid-high
    Color(0xFFCCCC00), // high
    Color(0xFFFF8800), // very high
    Color(0xFFFF4400), // loud
    Color(0xFFFF0000), // very loud
    Color(0xFFFFFFFF), // clipping
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF080808);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    if (spectrogramData.isEmpty || !isActive) {
      // Draw idle state
      final idlePaint = Paint()
        ..color = const Color(0xFFFF4500).withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      // Draw frequency guide lines
      for (int i = 1; i < 5; i++) {
        final y = size.height * i / 5;
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          idlePaint,
        );
      }

      // Draw labels
      final labelStyle = TextStyle(
        color: Colors.grey.withOpacity(0.3),
        fontSize: 8,
        fontFamily: 'monospace',
      );
      final labelPainter = TextPainter(textDirection: TextDirection.ltr);

      labelPainter.text = TextSpan(
        text: '${sampleRate ~/ 2} Hz',
        style: labelStyle,
      );
      labelPainter.layout();
      labelPainter.paint(canvas, const Offset(4, 2));

      labelPainter.text = TextSpan(
        text: '0 Hz',
        style: labelStyle,
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(4, size.height - 14));

      return;
    }

    final binHeight = size.height / _numBins;
    final colWidth = math.max(1.0, size.width / spectrogramData.length);

    // Draw spectrogram columns
    for (int col = 0; col < spectrogramData.length; col++) {
      final column = spectrogramData[col];
      if (column.isEmpty) continue;

      final x = size.width - (spectrogramData.length - col) * colWidth;
      if (x + colWidth < 0 || x > size.width) continue;

      // Normalize column
      double maxVal = 0.001;
      for (final v in column) {
        if (v > maxVal) maxVal = v;
      }

      for (int bin = 0; bin < column.length && bin < _numBins; bin++) {
        final normalized = (column[bin] / maxVal).clamp(0.0, 1.0);
        final colorIdx = (normalized * (_heatmapColors.length - 1)).round();
        final color = _heatmapColors[colorIdx.clamp(0, _heatmapColors.length - 1)];

        final paint = Paint()..color = color;
        final y = size.height - (bin + 1) * binHeight;
        canvas.drawRect(
          Rect.fromLTWH(x, y, colWidth + 0.5, binHeight + 0.5),
          paint,
        );
      }
    }

    // Draw frequency labels
    _drawLabels(canvas, size);
  }

  // Number of frequency bins to display
  int get _numBins => 64;

  void _drawLabels(Canvas canvas, Size size) {
    final labelStyle = TextStyle(
      color: Colors.grey.withOpacity(0.4),
      fontSize: 8,
      fontFamily: 'monospace',
    );
    final painter = TextPainter(textDirection: TextDirection.ltr);

    // Top label (Nyquist frequency)
    painter.text = TextSpan(
      text: '${sampleRate ~/ 2} Hz',
      style: labelStyle,
    );
    painter.layout();
    painter.paint(canvas, const Offset(4, 2));

    // Bottom label
    painter.text = TextSpan(
      text: '0 Hz',
      style: labelStyle,
    );
    painter.layout();
    painter.paint(canvas, Offset(4, size.height - 14));

    // Middle frequency markers
    painter.text = TextSpan(
      text: '${sampleRate ~/ 4} Hz',
      style: labelStyle,
    );
    painter.layout();
    painter.paint(canvas, Offset(4, size.height * 0.48));
  }

  @override
  bool shouldRepaint(SpectrogramPainter oldDelegate) {
    return oldDelegate.spectrogramData != spectrogramData ||
        oldDelegate.isActive != isActive;
  }
}

/// FFT-based spectrogram analyzer that produces frequency bins from PCM data.
class SpectrogramAnalyzer {
  final int sampleRate;
  final int fftSize;

  // Hann window
  late final List<double> window;
  // Buffer for incoming samples
  final List<double> _buffer;
  int _bufferPos = 0;

  // Spectrogram history (columns of frequency bins)
  final List<List<double>> _history = [];
  int maxHistory = 128;

  SpectrogramAnalyzer({
    this.sampleRate = 16000,
    this.fftSize = 256,
  }) : _buffer = List.filled(256, 0.0) {
    // Hann window
    window = List.generate(fftSize, (i) {
      return 0.5 * (1.0 - math.cos(2.0 * math.pi * i / (fftSize - 1)));
    });
  }

  /// Feed audio samples into the analyzer.
  /// Processes in fftSize-sized blocks when enough samples are accumulated.
  void feedSamples(List<double> samples) {
    for (final sample in samples) {
      _buffer[_bufferPos] = sample;
      _bufferPos++;

      if (_bufferPos >= fftSize) {
        _computeSpectrum();
        // 50% overlap
        for (int i = fftSize ~/ 2; i < fftSize; i++) {
          _buffer[i - fftSize ~/ 2] = _buffer[i];
        }
        _bufferPos = fftSize ~/ 2;
      }
    }
  }

  /// Compute a single FFT spectrum and add to history.
  void _computeSpectrum() {
    // Apply window and copy
    final real = List<double>.filled(fftSize, 0.0);
    final imag = List<double>.filled(fftSize, 0.0);
    for (int i = 0; i < fftSize; i++) {
      real[i] = _buffer[i] * window[i];
    }

    // FFT
    _fft(real, imag);

    // Magnitude spectrum (only first half since input is real)
    final bins = <double>[];
    for (int i = 0; i < fftSize ~/ 2; i++) {
      final mag = math.sqrt(real[i] * real[i] + imag[i] * imag[i]);
      // Convert to dB scale, normalize
      final db = mag > 0 ? 20.0 * math.log(mag) / math.ln10 : -100;
      bins.add((db + 100) / 100.0); // Normalize to 0-1
    }

    // Downsample to 64 bins for display
    final displayBins = List<double>.filled(64, 0.0);
    for (int i = 0; i < bins.length; i++) {
      final binIdx = (i * 64 ~/ bins.length).clamp(0, 63);
      if (bins[i] > displayBins[binIdx]) {
        displayBins[binIdx] = bins[i];
      }
    }

    _history.add(displayBins);
    if (_history.length > maxHistory) {
      _history.removeAt(0);
    }
  }

  /// Radix-2 Cooley-Tukey FFT (in-place).
  void _fft(List<double> real, List<double> imag) {
    final n = real.length;

    // Bit-reversal permutation
    for (int i = 1; i < n; i++) {
      int j = 0;
      int m = i;
      for (int k = n >> 1; k > 0; k >>= 1) {
        j = (j >> 1) | ((m & 1) * k);
        m >>= 1;
      }
      if (j > i) {
        double temp = real[i]; real[i] = real[j]; real[j] = temp;
        temp = imag[i]; imag[i] = imag[j]; imag[j] = temp;
      }
    }

    // FFT
    for (int len = 2; len <= n; len <<= 1) {
      final halfLen = len >> 1;
      final wRe = math.cos(2.0 * math.pi / len);
      final wIm = -math.sin(2.0 * math.pi / len);

      for (int i = 0; i < n; i += len) {
        double wr = 1.0, wi = 0.0;
        for (int j = 0; j < halfLen; j++) {
          final tRe = real[i + j + halfLen] * wr - imag[i + j + halfLen] * wi;
          final tIm = real[i + j + halfLen] * wi + imag[i + j + halfLen] * wr;

          real[i + j + halfLen] = real[i + j] - tRe;
          imag[i + j + halfLen] = imag[i + j] - tIm;
          real[i + j] += tRe;
          imag[i + j] += tIm;

          final nwr = wr * wRe - wi * wIm;
          wi = wr * wIm + wi * wRe;
          wr = nwr;
        }
      }
    }
  }

  /// Get the current spectrogram data for painting.
  List<List<double>> get data => List.unmodifiable(_history);

  void reset() {
    _bufferPos = 0;
    _history.clear();
  }

  void dispose() {
    _history.clear();
  }
}
