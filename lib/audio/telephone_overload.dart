import 'dart:math' as math;

import '../utils/constants.dart';

/// TelephoneOverload — an ear-piercing "radio overload" effect.
///
/// It crushes the signal into a narrow, aggressively resonant mid band,
/// then drives it through tanh saturation. The result is the sound of a
/// voice screaming through an overloaded public-address / police radio:
/// thin, nasal, buzzing, and painfully present in the listener's ear.
class TelephoneOverload {
  final int sampleRate;

  /// Band center frequency in Hz.
  double _centerFrequency = 2400.0;

  /// Bandwidth in Hz (narrower = more resonant / more painful).
  double _bandwidth = 220.0;

  /// Saturation drive applied after the resonant filter.
  double drive = 8.0;

  /// Wet/dry mix (0.0–1.0).
  double mix = 1.0;

  bool enabled = false;

  /// Two cascaded peaking biquads for an extra-sharp resonance peak.
  late final _ResoBiquad _f1 = _ResoBiquad();
  late final _ResoBiquad _f2 = _ResoBiquad();

  TelephoneOverload({this.sampleRate = AudioConstants.sampleRate}) {
    _recompute();
  }

  void _recompute() {
    final q = _centerFrequency / _bandwidth;
    _f1.setPeak(sampleRate: sampleRate, freq: _centerFrequency, q: q, gainDb: 12.0);
    _f2.setPeak(sampleRate: sampleRate, freq: _centerFrequency, q: q, gainDb: 6.0);
  }

  double get centerFrequency => _centerFrequency;
  set centerFrequency(double v) {
    _centerFrequency = v.clamp(300.0, 6000.0);
    _recompute();
  }

  double get bandwidth => _bandwidth;
  set bandwidth(double v) {
    _bandwidth = v.clamp(60.0, 1200.0);
    _recompute();
  }

  /// Process [samples] in place.
  void process(List<double> samples) {
    if (!enabled || samples.isEmpty) return;

    for (int i = 0; i < samples.length; i++) {
      var s = samples[i];
      s = _f1.process(s);
      s = _f2.process(s);
      // Drive through saturation: thin resonant band + heavy harmonic drive.
      s = _fastTanh(s * drive);
      samples[i] = (samples[i] * (1.0 - mix) + s * mix).clamp(-1.0, 1.0);
    }
  }

  double _fastTanh(double x) {
    if (x > 4.0) return 1.0;
    if (x < -4.0) return -1.0;
    final x2 = x * x;
    return x * (27.0 + x2) / (27.0 + 9.0 * x2);
  }

  void reset() {
    _f1.reset();
    _f2.reset();
  }

  void dispose() {}
}

/// Peaking EQ biquad (Direct Form I).
class _ResoBiquad {
  double _b0 = 1.0, _b1 = 0.0, _b2 = 0.0;
  double _a1 = 0.0, _a2 = 0.0;
  double _x1 = 0.0, _x2 = 0.0, _y1 = 0.0, _y2 = 0.0;

  void setPeak({
    required int sampleRate,
    required double freq,
    required double q,
    required double gainDb,
  }) {
    final a = math.pow(10.0, gainDb / 40.0).toDouble();
    final w0 = 2.0 * math.pi * freq / sampleRate;
    final alpha = math.sin(w0) / (2.0 * q);
    final cosW0 = math.cos(w0);

    var b0 = 1.0 + alpha * a;
    var b1 = -2.0 * cosW0;
    var b2 = 1.0 - alpha * a;
    var a1 = -2.0 * cosW0;
    var a2 = 1.0 - alpha / a;

    final norm = 1.0 / (1.0 + alpha / a);
    b0 *= norm;
    b1 *= norm;
    b2 *= norm;
    a1 *= norm;
    a2 *= norm;

    _b0 = b0;
    _b1 = b1;
    _b2 = b2;
    _a1 = a1;
    _a2 = a2;
  }

  double process(double x) {
    final y = _b0 * x + _b1 * _x1 + _b2 * _x2 - _a1 * _y1 - _a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }

  void reset() {
    _x1 = _x2 = _y1 = _y2 = 0.0;
  }
}
