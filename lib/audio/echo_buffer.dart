import '../utils/constants.dart';

/// Circular ring buffer for multi-tap echo delay.
/// Pre-allocated for maxDelayMs capacity at given sampleRate.
class EchoBuffer {
  final int sampleRate;
  final int maxDelayMs;
  late final List<double> _buffer;
  int _writeHead = 0;

  EchoBuffer({
    this.sampleRate = AudioConstants.sampleRate,
    this.maxDelayMs = 500,
  }) {
    final capacity = (sampleRate * maxDelayMs / 1000).ceil() + 1;
    _buffer = List<double>.filled(capacity, 0.0);
  }

  int _delayInSamples(int delayMs) =>
      (sampleRate * delayMs / 1000).round();

  /// Read a delayed sample from the buffer at [chunkOffset] position
  /// with the specified [delayMs].
  double readAt(int chunkOffset, {required int delayMs}) {
    final delaySamples = _delayInSamples(delayMs);
    final readPos =
        (_writeHead + chunkOffset - delaySamples) % _buffer.length;
    return _buffer[readPos < 0 ? readPos + _buffer.length : readPos];
  }

  /// Write a sample at [chunkOffset] position.
  void write(int chunkOffset, double value) {
    final pos = (_writeHead + chunkOffset) % _buffer.length;
    _buffer[pos] = value;
  }

  /// Advance the write head by [chunkSize] samples.
  void advance(int chunkSize) {
    _writeHead = (_writeHead + chunkSize) % _buffer.length;
  }

  /// Reset buffer to silence.
  void reset() {
    for (int i = 0; i < _buffer.length; i++) {
      _buffer[i] = 0.0;
    }
    _writeHead = 0;
  }

  void dispose() {
    _buffer = List<double>.filled(0, 0.0);
  }
}
