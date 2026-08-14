import 'dart:math';
import 'dart:typed_data';
import '../utils/constants.dart';

/// PCM utility functions for Int16 ↔ double conversion and signal processing.
class PcmUtils {
  PcmUtils._();

  /// Convert Int16List to normalized [-1.0, 1.0] doubles.
  static List<double> toDoubles(Int16List input) {
    return List<double>.generate(
      input.length,
      (i) => input[i] / AudioConstants.maxInt16,
    );
  }

  /// Convert normalized doubles back to Int16List.
  ///
  /// Bug fix: the previous implementation rounded values near ±1.0 to 32768,
  /// which overflows Int16 and wraps to -32768 on native conversion, causing
  /// audible clicks/spikes at peak amplitude. Clamping the integer result
  /// into the valid [-32768, 32767] range prevents this.
  static Int16List toInt16(List<double> samples) {
    final out = Int16List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      // Int16 valid range: -32768 .. 32767.
      // Note: .clamp() with num bounds returns num, which cannot be assigned
      // to Int16List; use explicit int bounds instead.
      int v = (samples[i].clamp(-1.0, 1.0) * 32767.0).round().toInt();
      if (v < -32768) v = -32768;
      if (v > 32767) v = 32767;
      out[i] = v;
    }
    return out;
  }

  /// Pad or trim a list to match [targetLength].
  /// If shorter, pads with silence (0.0).
  /// If longer, trims excess samples.
  static List<double> padOrTrim(List<double> samples, int targetLength) {
    if (samples.length == targetLength) return samples;
    if (samples.length > targetLength) {
      return samples.sublist(0, targetLength);
    }
    final padded = List<double>.filled(targetLength, 0.0);
    for (int i = 0; i < samples.length; i++) {
      padded[i] = samples[i];
    }
    return padded;
  }

  /// Hyperbolic tangent for soft clipping.
  /// Numerically stable approximation.
  static double tanh(double x) {
    if (x > 20) return 1.0;
    if (x < -20) return -1.0;
    final e2x = exp(2 * x);
    return (e2x - 1) / (e2x + 1);
  }

  /// Simple envelope follower (RMS).
  static double rms(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    double sum = 0.0;
    for (final s in samples) {
      sum += s * s;
    }
    return sqrt(sum / samples.length);
  }

  /// Peak amplitude in the given sample array.
  static double peak(List<double> samples) {
    double max = 0.0;
    for (final s in samples) {
      final abs = s.abs();
      if (abs > max) max = abs;
    }
    return max;
  }
}
