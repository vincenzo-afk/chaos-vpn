import 'dart:math';

/// Pitch wobble via linear resampling.
/// Randomly shifts pitch by a new semitone offset in [-3, +3] every 200–600ms.
/// Achieved by changing the playback speed factor: speed = 2^(semitones/12).
class PitchWobble {
  final int sampleRate;
  final Random _rng = Random();

  double _currentSpeed = 1.0;
  double _targetSpeed = 1.0;
  int _samplesUntilChange = 0;
  double _fractionalPos = 0.0;

  // Accumulates leftover samples from previous chunk
  final List<double> _remainder = [];

  PitchWobble({required this.sampleRate}) {
    _scheduleNextChange();
  }

  void _scheduleNextChange() {
    // Random interval 200–600ms
    final intervalMs = 200 + _rng.nextInt(400);
    _samplesUntilChange = (sampleRate * intervalMs / 1000).round();

    // Random semitone shift ±3
    final semitones = (_rng.nextDouble() * 6.0) - 3.0;
    _targetSpeed = pow(2.0, semitones / 12.0).toDouble();
  }

  List<double> process(List<double> input) {
    if (input.isEmpty) return input;

    // Gradually move current speed toward target (glide)
    _currentSpeed += (_targetSpeed - _currentSpeed) * 0.05;

    _samplesUntilChange -= input.length;
    if (_samplesUntilChange <= 0) {
      _scheduleNextChange();
    }

    // Linear resampling: read input at [_currentSpeed] rate
    final allInput = [..._remainder, ...input];
    final output = <double>[];

    while (_fractionalPos + 1 < allInput.length) {
      final i = _fractionalPos.floor();
      final frac = _fractionalPos - i;
      // Linear interpolation between adjacent samples
      final sample = allInput[i] * (1.0 - frac) + allInput[i + 1] * frac;
      output.add(sample);
      _fractionalPos += _currentSpeed;
    }

    // Save unconsumed samples for next chunk
    final consumed = _fractionalPos.floor();
    _remainder.clear();
    if (consumed < allInput.length) {
      _remainder.addAll(allInput.sublist(consumed));
    }
    _fractionalPos -= consumed;

    return output;
  }

  void reset() {
    _currentSpeed = 1.0;
    _targetSpeed = 1.0;
    _fractionalPos = 0.0;
    _remainder.clear();
    _scheduleNextChange();
  }

  void dispose() {
    _remainder.clear();
  }
}
