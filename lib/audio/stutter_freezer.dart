import 'dart:math';
import 'dart:typed_data';

import '../utils/constants.dart';

/// StutterFreezer — freezes (repeats) short fragments of the incoming audio,
/// creating the classic broken-record / CD-skipping artifact.
///
/// When enabled, the effect keeps a rolling small buffer of the most recent
/// samples. With probability [freezeProbability] a freeze event is triggered
/// and the effect repeats the buffered fragment (either at normal speed or
/// sped up 2x) for [freezeDurationMs] of output time before resuming the
/// live stream.
class StutterFreezer {
  final int sampleRate;
  final Random _rng;

  /// Probability (0.0–1.0) of entering a freeze on each processed chunk.
  double freezeProbability = 0.10;

  /// How long a freeze event lasts, in milliseconds.
  double freezeDurationMs = 120.0;

  /// Size of the captured fragment in milliseconds (repeated snippet length).
  double snippetLengthMs = 60.0;

  /// When true, a freeze repeats the snippet at double speed (CD-skipping style).
  bool doubleSpeedFreeze = true;

  bool enabled = false;

  StutterFreezer({this.sampleRate = AudioConstants.sampleRate})
      : _rng = Random();

  /// Rolling capture buffer (last [bufferSize] samples seen).
  static const int _bufferSize = 1920;
  final Float64List _buffer = Float64List(_bufferSize);
  int _writePos = 0;

  // Freeze state machine
  bool _frozen = false;
  int _freezeRemaining = 0;
  int _snippetStart = 0;
  int _snippetLength = 0;
  int _snippetPos = 0;

  /// Process [samples] in place, injecting freeze repeats when triggered.
  void process(List<double> samples) {
    if (!enabled || samples.length < 2) return;

    // Feed the live input into the rolling capture buffer.
    for (int i = 0; i < samples.length; i++) {
      _buffer[_writePos] = samples[i];
      _writePos = (_writePos + 1) % _bufferSize;
    }

    if (_frozen) {
      _renderFreeze(samples);
      return;
    }

    if (_rng.nextDouble() < freezeProbability) {
      _triggerFreeze(samples.length);
      _renderFreeze(samples);
      return;
    }
  }

  /// Enter a freeze: capture the most recent snippet from the buffer.
  void _triggerFreeze(int currentChunkLen) {
    _frozen = true;
    final step = doubleSpeedFreeze ? 2 : 1;
    final targetSamples =
        (freezeDurationMs * sampleRate / 1000.0).round();
    _snippetLength =
        ((snippetLengthMs * sampleRate / 1000.0).round().clamp(16, _bufferSize ~/ 2)) ~/ step;
    // Captured snippet ends at the most recent buffered sample.
    _snippetPos = 0;
    _snippetStart = (_writePos - _snippetLength + _bufferSize) % _bufferSize;
    _freezeRemaining = targetSamples;
  }

  /// Overwrite [samples] with repeated snippet data for this chunk.
  void _renderFreeze(List<double> samples) {
    final step = doubleSpeedFreeze ? 2 : 1;
    for (int i = 0; i < samples.length && _freezeRemaining > 0; i++) {
      final srcIdx = (_snippetStart + _snippetPos) % _bufferSize;
      samples[i] = _buffer[srcIdx];
      _snippetPos = (_snippetPos + step) % _bufferSize;
      _freezeRemaining--;
    }
    if (_freezeRemaining <= 0) {
      _frozen = false;
    }
  }

  void reset() {
    for (int i = 0; i < _buffer.length; i++) {
      _buffer[i] = 0;
    }
    _writePos = 0;
    _frozen = false;
    _freezeRemaining = 0;
  }

  void dispose() {}
}
