import 'dart:math';

import '../utils/constants.dart';

/// ReverseGlitch — periodically reverses short windows of the audio signal
/// in place.
///
/// When enabled, every processed chunk has a [reversalProbability] chance of
/// having one or more small windows (typically 16–128 ms) flipped backwards.
/// The reversed fragments keep the original timing position, so the result
/// sounds like a broken tape / corrupted network stream rather than a full
/// reversed playback — maximally disorienting for the listener.
class ReverseGlitch {
  final int sampleRate;
  final Random _rng;

  /// Probability (0.0–1.0) that a chunk is hit by a reversal event.
  double reversalProbability = 0.15;

  /// Length of each reversed window in milliseconds.
  double windowLengthMs = 80.0;

  /// Maximum number of reversal windows per chunk (1+ windows = heavier chaos).
  int maxWindows = 2;

  bool enabled = false;

  ReverseGlitch({this.sampleRate = AudioConstants.sampleRate})
      : _rng = Random();

  /// Reverse a span of samples in place within [samples].
  void process(List<double> samples) {
    if (!enabled || samples.length < 16) return;
    if (_rng.nextDouble() >= reversalProbability) return;

    final windowSamples =
        (windowLengthMs * sampleRate / 1000.0).round().clamp(16, samples.length ~/ 2);
    final hits = 1 + _rng.nextInt(maxWindows);

    for (int w = 0; w < hits; w++) {
      final start = _rng.nextInt((samples.length - windowSamples).clamp(1, samples.length));
      _reverseSpan(samples, start, windowSamples);
    }
  }

  /// Reverse the span [start .. start+length) in place.
  void _reverseSpan(List<double> samples, int start, int length) {
    for (int i = 0; i < length ~/ 2; i++) {
      final a = start + i;
      final b = start + length - 1 - i;
      final tmp = samples[a];
      samples[a] = samples[b];
      samples[b] = tmp;
    }
  }

  void reset() {}

  void dispose() {}
}
