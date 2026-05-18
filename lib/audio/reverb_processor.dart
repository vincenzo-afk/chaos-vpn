import '../utils/constants.dart';

/// Schroeder reverb network: 4 comb filters + 2 all-pass filters.
/// Simulates a large room for hollow, distant voice quality.
class ReverbProcessor {
  final int sampleRate;

  // Comb filter delays in samples (tuned for large room feel)
  late final List<_CombFilter> _combs;
  // All-pass filter delays
  late final List<_AllPassFilter> _allPass;

  ReverbProcessor({this.sampleRate = AudioConstants.sampleRate}) {
    // Comb filter delay times in ms
    final combDelays = [29.7, 37.1, 41.1, 43.7];
    const combDecay = 0.84;

    _combs = combDelays
        .map((ms) => _CombFilter(
              delayLength: (sampleRate * ms / 1000).round(),
              decay: combDecay,
            ))
        .toList();

    // All-pass delays
    _allPass = [
      _AllPassFilter(
        delayLength: (sampleRate * 5.0 / 1000).round(),
        decay: 0.7,
      ),
      _AllPassFilter(
        delayLength: (sampleRate * 1.7 / 1000).round(),
        decay: 0.7,
      ),
    ];
  }

  List<double> process(List<double> input) {
    if (input.isEmpty) return input;

    final output = List<double>.filled(input.length, 0.0);

    // Sum all 4 comb filters
    for (final comb in _combs) {
      for (int i = 0; i < input.length; i++) {
        output[i] += comb.process(input[i]);
      }
    }

    // Scale comb sum
    for (int i = 0; i < output.length; i++) {
      output[i] /= _combs.length;
    }

    // Pass through 2 all-pass filters in series
    for (final ap in _allPass) {
      for (int i = 0; i < output.length; i++) {
        output[i] = ap.process(output[i]);
      }
    }

    return output;
  }

  void reset() {
    for (final comb in _combs) {
      for (int i = 0; i < comb._buffer.length; i++) {
        comb._buffer[i] = 0.0;
      }
      comb._pos = 0;
    }
    for (final ap in _allPass) {
      for (int i = 0; i < ap._buffer.length; i++) {
        ap._buffer[i] = 0.0;
      }
      ap._pos = 0;
    }
  }

  void dispose() {}
}

class _CombFilter {
  final int delayLength;
  final double decay;
  late final List<double> _buffer;
  int _pos = 0;

  _CombFilter({required this.delayLength, required this.decay}) {
    _buffer = List<double>.filled(delayLength, 0.0);
  }

  double process(double input) {
    final delayed = _buffer[_pos];
    _buffer[_pos] = input + delayed * decay;
    _pos = (_pos + 1) % delayLength;
    return delayed;
  }
}

class _AllPassFilter {
  final int delayLength;
  final double decay;
  late final List<double> _buffer;
  int _pos = 0;

  _AllPassFilter({required this.delayLength, required this.decay}) {
    _buffer = List<double>.filled(delayLength, 0.0);
  }

  double process(double input) {
    final delayed = _buffer[_pos];
    final v = input + delayed * (-decay);
    _buffer[_pos] = v;
    _pos = (_pos + 1) % delayLength;
    return delayed + v * decay;
  }
}
