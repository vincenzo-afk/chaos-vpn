import 'dart:math' as math;
import '../utils/constants.dart';

/// Formant shifter using linear predictive coding (LPC) analysis/synthesis.
///
/// Breaks the signal into frames, analyzes formants via LPC, shifts them
/// by [shiftFactor] (0.5 = thinner/higher, 2.0 = deeper/lower), and
/// resynthesizes the signal. This creates natural-sounding voice
/// transformations without the robotic artifacts of pure pitch shifting.
///
/// Algorithm:
///   1. Window each frame with a Hann window
///   2. Compute autocorrelation (up to LPC order)
///   3. Solve LPC coefficients via Levinson-Durbin recursion
///   4. Compute residual (LPC inverse filter)
///   5. Resample residual to shift formants
///   6. Resynthesize via all-pole LPC synthesis filter
///   7. Overlap-add frames back together
class FormantShifter {
  final int sampleRate;

  // Parameters
  double shiftFactor = 1.0; // 0.5–2.0 (1.0 = off)
  double mix = 1.0; // wet/dry mix (0.0–1.0)
  bool enabled = false;

  // LPC order (typical for 16kHz speech: 10–14)
  static const int _lpcOrder = 12;

  // Frame size in samples (~30ms at 16kHz)
  static const int _frameSize = 480;
  // Hop size (50% overlap)
  static const int _hopSize = _frameSize ~/ 2;

  // Hann window coefficients (precomputed)
  late final List<double> _window;
  // LPC analysis state
  final List<double> _prevFrame = List.filled(_hopSize, 0.0);

  FormantShifter({this.sampleRate = AudioConstants.sampleRate}) {
    _window = List.generate(_frameSize, (i) {
      return 0.5 * (1.0 - math.cos(2.0 * math.pi * i / (_frameSize - 1)));
    });
  }

  /// Process a buffer of samples in place.
  /// Uses overlap-add framing internally.
  void process(List<double> samples) {
    if (!enabled || shiftFactor == 1.0 || samples.isEmpty) return;

    final output = List<double>.filled(samples.length, 0.0);
    final frame = List<double>.filled(_frameSize, 0.0);

    // Process frame by frame with overlap
    int pos = 0;
    while (pos < samples.length) {
      final frameStart = pos - _hopSize;

      // Build current frame (with lookback)
      for (int i = 0; i < _frameSize; i++) {
        final srcIdx = frameStart + i;
        if (srcIdx >= 0 && srcIdx < samples.length) {
          frame[i] = samples[srcIdx] * _window[i];
        } else if (srcIdx < 0) {
          // Pad with silence for negative indices
          frame[i] = 0.0;
        } else {
          frame[i] = 0.0;
        }
      }

      // Apply LPC analysis + formant shift + synthesis
      final processed = _processFrame(frame);

      // Overlap-add into output buffer
      for (int i = 0; i < _frameSize; i++) {
        final dstIdx = frameStart + i;
        if (dstIdx >= 0 && dstIdx < samples.length) {
          output[dstIdx] += processed[i];
        }
      }

      pos += _hopSize;
    }

    // Normalize output and mix with dry signal
    final peak = output.reduce((a, b) => a.abs() > b.abs() ? a : b).abs();
    final scale = peak > 1.0 ? 1.0 / peak : 1.0;

    for (int i = 0; i < samples.length; i++) {
      final wet = output[i] * scale * mix;
      final dry = samples[i] * (1.0 - mix);
      samples[i] = (wet + dry).clamp(-1.0, 1.0);
    }
  }

  /// Process a single Hann-windowed frame through LPC analysis,
  /// formant shifting (residual resampling), and LPC synthesis.
  List<double> _processFrame(List<double> frame) {
    // 1. Autocorrelation
    final r = List<double>.filled(_lpcOrder + 1, 0.0);
    for (int k = 0; k <= _lpcOrder; k++) {
      double sum = 0.0;
      for (int n = 0; n < _frameSize - k; n++) {
        sum += frame[n] * frame[n + k];
      }
      r[k] = sum;
    }

    // 2. Levinson-Durbin recursion to solve LPC coefficients
    final a = List<double>.filled(_lpcOrder + 1, 0.0);
    a[0] = 1.0;
    double e = r[0];

    for (int i = 1; i <= _lpcOrder; i++) {
      double k = r[i];
      for (int j = 1; j < i; j++) {
        k -= a[j] * r[i - j];
      }
      if (e == 0) break;
      k /= e;

      final newA = List<double>.from(a);
      for (int j = 1; j < i; j++) {
        newA[j] = a[j] - k * a[i - j];
      }
      newA[i] = -k;
      a.setAll(0, newA);
      e *= (1.0 - k * k);
    }

    // 3. Compute residual (inverse filter: A(z) * X(z))
    final residual = List<double>.filled(_frameSize, 0.0);
    for (int n = 0; n < _frameSize; n++) {
      double pred = 0.0;
      for (int j = 1; j <= _lpcOrder && j <= n; j++) {
        pred += a[j] * frame[n - j];
      }
      residual[n] = frame[n] - pred;
    }

    // 4. Resample residual to shift formants
    final shiftedResidual = _resample(residual, shiftFactor);

    // 5. Resynthesize via LPC synthesis filter (1/A(z))
    final synthesized = List<double>.filled(_frameSize, 0.0);
    final len = math.min(shiftedResidual.length, _frameSize);
    for (int n = 0; n < len; n++) {
      double synth = shiftedResidual[n];
      for (int j = 1; j <= _lpcOrder && j <= n; j++) {
        synth += a[j] * synthesized[n - j];
      }
      synthesized[n] = synth;
    }

    // 6. Apply window to output frame
    final output = List<double>.filled(_frameSize, 0.0);
    for (int i = 0; i < _frameSize; i++) {
      output[i] = synthesized[i] * _window[i];
    }

    return output;
  }

  /// Resample a signal by [factor].
  /// factor < 1 = stretch (higher formants)
  /// factor > 1 = compress (lower formants)
  List<double> _resample(List<double> input, double factor) {
    if (factor <= 0) return List.from(input);
    if (factor == 1.0) return List.from(input);

    final outLen = (input.length / factor).round();
    final output = List<double>.filled(outLen, 0.0);

    for (int i = 0; i < outLen; i++) {
      final srcPos = i * factor;
      final srcIdx = srcPos.floor();
      final frac = srcPos - srcIdx;

      if (srcIdx + 1 < input.length) {
        output[i] = input[srcIdx] * (1.0 - frac) + input[srcIdx + 1] * frac;
      } else if (srcIdx < input.length) {
        output[i] = input[srcIdx];
      }
    }

    return output;
  }

  void reset() {
    for (int i = 0; i < _hopSize; i++) {
      _prevFrame[i] = 0.0;
    }
  }

  void dispose() {}
}
