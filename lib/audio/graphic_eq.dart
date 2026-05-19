import 'dart:math' as math;

/// 5-band parametric graphic equalizer with configurable gains per band.
/// Each band uses a biquad IIR filter. Bands are applied in series.
///
/// Default bands (ISO standard frequencies for voice processing):
///   Band 1: 80 Hz     (Low shelf — sub-bass rumble)
///   Band 2: 300 Hz    (Low mids — body of voice)
///   Band 3: 1000 Hz   (Mid — presence)
///   Band 4: 3400 Hz   (High mids — telephone band edge)
///   Band 5: 8000 Hz   (High shelf — air / sibilance)
///
/// On default settings (all gains = 0 dB), the EQ passes audio transparently.
/// When "radio filter" mode is enabled, it emulates a telephone line
/// (300 Hz high-pass + 3400 Hz low-pass).
class GraphicEQ {
  final int sampleRate;

  // Band center frequencies
  static const List<double> bandFrequencies = [80.0, 300.0, 1000.0, 3400.0, 8000.0];

  // Band gains in dB (0 = flat, +12 = max boost, -12 = max cut)
  final List<double> gains = [0.0, 0.0, 0.0, 0.0, 0.0];

  // Per-band biquad filter state
  final List<_Biquad> _filters;

  /// Enable telephone filter mode: high-pass at 300 Hz + low-pass at 3400 Hz
  bool radioFilterEnabled = false;

  GraphicEQ({required this.sampleRate})
      : _filters = List.generate(
          5,
          (i) => _Biquad(
            sampleRate: sampleRate,
            freq: bandFrequencies[i],
          ),
        ) {
    _recomputeAll();
  }

  /// Set gain for a specific band (index 0-4, in dB, range -12 to +12).
  void setBand(int band, double gainDb) {
    if (band < 0 || band >= 5) return;
    gains[band] = gainDb.clamp(-12.0, 12.0);
    _filters[band].setBandGain(gainDb);
  }

  /// Enable telephone bandpass emulation (300-3400 Hz).
  void setRadioFilter(bool enabled) {
    radioFilterEnabled = enabled;
    _recomputeAll();
  }

  void _recomputeAll() {
    if (radioFilterEnabled) {
      // Telephone mode: only pass 300-3400 Hz
      // Band 1: 80 Hz → full cut (-12 dB)
      _filters[0].setBandGain(-12.0);
      // Band 2: 300 Hz → flat
      _filters[1].setBandGain(0.0);
      // Band 3: 1 kHz → flat
      _filters[2].setBandGain(0.0);
      // Band 4: 3400 Hz → flat
      _filters[3].setBandGain(0.0);
      // Band 5: 8 kHz → full cut (-12 dB)
      _filters[4].setBandGain(-12.0);
    } else {
      // Normal mode: use user gains
      for (int i = 0; i < 5; i++) {
        _filters[i].setBandGain(gains[i]);
      }
    }
  }

  /// Process a buffer of samples in place.
  /// Skips processing entirely when all bands are flat (0 dB) and radio filter is off,
  /// to avoid unnecessary CPU cycles on the most common default state.
  void process(List<double> samples) {
    // Optimization: bypass entirely when no EQ bands are active
    if (_isFlat()) return;

    for (final filter in _filters) {
      for (int i = 0; i < samples.length; i++) {
        samples[i] = filter.process(samples[i]).clamp(-1.0, 1.0);
      }
    }
  }

  /// Returns true if all band gains are at 0 dB and radio filter is off.
  bool _isFlat() {
    if (radioFilterEnabled) return false;
    for (final g in gains) {
      if (g.abs() > 0.5) return false; // > 0.5 dB deviation from flat
    }
    return true;
  }

  void reset() {
    for (final f in _filters) {
      f.reset();
    }
    for (int i = 0; i < 5; i++) {
      gains[i] = 0.0;
    }
    radioFilterEnabled = false;
    _recomputeAll();
  }

  void dispose() {}
}

/// Single biquad IIR filter (peaking EQ band).
class _Biquad {
  final int sampleRate;
  final double freq;
  double _b0 = 1.0, _b1 = 0.0, _b2 = 0.0;
  double _a1 = 0.0, _a2 = 0.0;
  double _x1 = 0.0, _x2 = 0.0, _y1 = 0.0, _y2 = 0.0;

  _Biquad({required this.sampleRate, required this.freq});

  /// Set gain in dB for this peaking filter.
  void setBandGain(double gainDb) {
    if (gainDb.abs() < 0.5) {
      // Near-zero gain: bypass (flat response)
      _b0 = 1.0;
      _b1 = 0.0;
      _b2 = 0.0;
      _a1 = 0.0;
      _a2 = 0.0;
      return;
    }

    final a = math.pow(10.0, gainDb / 40.0).toDouble(); // amplitude
    final w0 = 2.0 * math.pi * freq / sampleRate;
    final alpha = math.sin(w0) / (2.0 * 1.0); // Q = 1.0 (bandwidth)

    final cosW0 = math.cos(w0);

    _b0 = 1.0 + alpha * a;
    _b1 = -2.0 * cosW0;
    _b2 = 1.0 - alpha * a;
    _a1 = -2.0 * cosW0;
    _a2 = 1.0 - alpha / a;

    final norm = 1.0 / (1.0 + alpha / a);
    _b0 *= norm;
    _b1 *= norm;
    _b2 *= norm;
    _a1 *= norm;
    _a2 *= norm;
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
