import 'dart:math';

/// Two-pole IIR Butterworth bandpass filter.
/// Passes frequencies between [lowHz] and [highHz].
/// Used to create the telephone / broken walkie-talkie effect (300–3400 Hz).
class BandpassFilter {
  final double sampleRate;
  final double lowHz;
  final double highHz;

  // Coefficients for HP stage (removes below lowHz)
  late double _hpA1, _hpA2, _hpB0, _hpB1, _hpB2;
  double _hpX1 = 0, _hpX2 = 0, _hpY1 = 0, _hpY2 = 0;

  // Coefficients for LP stage (removes above highHz)
  late double _lpA1, _lpA2, _lpB0, _lpB1, _lpB2;
  double _lpX1 = 0, _lpX2 = 0, _lpY1 = 0, _lpY2 = 0;

  BandpassFilter({
    required this.sampleRate,
    required this.lowHz,
    required this.highHz,
  }) {
    _computeHighPassCoeffs(lowHz);
    _computeLowPassCoeffs(highHz);
  }

  void _computeHighPassCoeffs(double cutoffHz) {
    final wc = 2.0 * pi * cutoffHz / sampleRate;
    final k = tan(wc / 2);
    final norm = 1.0 / (1.0 + sqrt(2.0) * k + k * k);
    _hpB0 = norm;
    _hpB1 = -2.0 * norm;
    _hpB2 = norm;
    _hpA1 = 2.0 * (k * k - 1.0) * norm;
    _hpA2 = (1.0 - sqrt(2.0) * k + k * k) * norm;
  }

  void _computeLowPassCoeffs(double cutoffHz) {
    final wc = 2.0 * pi * cutoffHz / sampleRate;
    final k = tan(wc / 2);
    final norm = 1.0 / (1.0 + sqrt(2.0) * k + k * k);
    _lpB0 = k * k * norm;
    _lpB1 = 2.0 * _lpB0;
    _lpB2 = _lpB0;
    _lpA1 = 2.0 * (k * k - 1.0) * norm;
    _lpA2 = (1.0 - sqrt(2.0) * k + k * k) * norm;
  }

  void process(List<double> samples) {
    for (int i = 0; i < samples.length; i++) {
      // High-pass stage
      final hpOut = _hpB0 * samples[i] +
          _hpB1 * _hpX1 +
          _hpB2 * _hpX2 -
          _hpA1 * _hpY1 -
          _hpA2 * _hpY2;
      _hpX2 = _hpX1;
      _hpX1 = samples[i];
      _hpY2 = _hpY1;
      _hpY1 = hpOut;

      // Low-pass stage on HP output
      final lpOut = _lpB0 * hpOut +
          _lpB1 * _lpX1 +
          _lpB2 * _lpX2 -
          _lpA1 * _lpY1 -
          _lpA2 * _lpY2;
      _lpX2 = _lpX1;
      _lpX1 = hpOut;
      _lpY2 = _lpY1;
      _lpY1 = lpOut;

      samples[i] = lpOut;
    }
  }

  void reset() {
    _hpX1 = 0;
    _hpX2 = 0;
    _hpY1 = 0;
    _hpY2 = 0;
    _lpX1 = 0;
    _lpX2 = 0;
    _lpY1 = 0;
    _lpY2 = 0;
  }
}
