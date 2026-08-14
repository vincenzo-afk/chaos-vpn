import 'dart:math';

/// Pitch wobble via linear resampling.
/// Randomly shifts pitch by [range] semitones every 200–600ms.
/// Achieved by changing the playback speed factor: speed = 2^(semitones/12).
class PitchWobble {
  final int sampleRate;
  final Random _rng = Random();

  double range = 3.0; // ± semitones (configurable)

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

    // Random semitone shift ±range
    final semitones = (_rng.nextDouble() * (2 * range)) - range;
    _targetSpeed = pow(2.0, semitones / 12.0).toDouble();
  }

  List<double> process(List<double> input) {
    if (input.isEmpty) return input;

    // Gradually move current speed toward target (glide)
    _currentSpeed += (_targetSpeed - _currentSpeed) * 0.05;
    // Clamp speed to avoid runaway slowdown/speedup artifacts
    _currentSpeed = _currentSpeed.clamp(0.5, 2.0);

    _samplesUntilChange -= input.length;
    if (_samplesUntilChange <= 0) {
      _scheduleNextChange();
    }

    // Linear resampling: read input at [_currentSpeed] rate
    final allInput = [..._remainder, ...input];
    final output = <double>[];

    // Bug fix: use `_fractionalPos + _currentSpeed <= allInput.length - 1`
    // so the interpolation always has two valid neighbor samples.
    while (_fractionalPos + _currentSpeed <= allInput.length - 1) {
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

    // Bug fix: if resampling produced no output yet (tiny chunk / very slow
    // speed), emit one interpolated sample so downstream chunks never see an
    // empty result, which caused audio dropouts at chunk boundaries.
    if (output.isEmpty && allInput.length >= 2) {
      final i = _fractionalPos.floor();
      final frac = _fractionalPos - i;
      output.add(allInput[i] * (1.0 - frac) + allInput[i + 1] * frac);
      _fractionalPos += _currentSpeed;
    }

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
