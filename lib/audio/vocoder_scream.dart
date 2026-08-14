import 'dart:math';

import '../utils/constants.dart';

/// VocoderScream — a simple but brutal vocoder / amplitude-modulation effect.
///
/// It multiplies the voice by a distorted carrier waveform whose frequency
/// is modulated by an LFO. The result is the classic "robotic demon" /
/// vocoded-scream sound used by horror voice changers. Unlike a clean
/// ring modulator, the carrier is passed through a tanh saturation first,
/// so it injects rich harmonic chaos into the voice instead of clean
/// sidebands.
class VocoderScream {
  final int sampleRate;

  /// Base carrier frequency in Hz.
  double carrierFrequency = 120.0;

  /// LFO rate in Hz that sweeps the carrier frequency (0 = static carrier).
  double sweepRate = 0.35;

  /// Amount of carrier frequency variation (in octaves, up/down).
  double sweepDepth = 0.6;

  /// Wet/dry mix (0.0–1.0). 1.0 = fully vocoded.
  double mix = 1.0;

  bool enabled = false;

  double _carrierPhase = 0.0;
  double _lfoPhase = 0.0;

  VocoderScream({this.sampleRate = AudioConstants.sampleRate});

  /// Process [samples] in place.
  void process(List<double> samples) {
    if (!enabled || samples.isEmpty) return;

    final carrierIncBase = 2.0 * pi * carrierFrequency / sampleRate;
    final lfoInc = 2.0 * pi * sweepRate / sampleRate;

    for (int i = 0; i < samples.length; i++) {
      // LFO sweeps the carrier frequency up/down for instability.
      final lfo = sin(_lfoPhase);
      _lfoPhase += lfoInc;
      if (_lfoPhase >= 2.0 * pi) _lfoPhase -= 2.0 * pi;

      final carrierInc = carrierIncBase * pow(2.0, lfo * sweepDepth);
      _carrierPhase += carrierInc;
      while (_carrierPhase >= 2.0 * pi) _carrierPhase -= 2.0 * pi;

      // Distorted carrier: sine -> tanh saturation for harmonic richness.
      final rawCarrier = sin(_carrierPhase);
      final hardCarrier = rawCarrier * 6.0;
      final carrier = _fastTanh(hardCarrier);

      final wet = samples[i] * carrier;
      samples[i] = (samples[i] * (1.0 - mix) + wet * mix).clamp(-1.0, 1.0);
    }
  }

  /// Fast tanh approximation, numerically stable in the working range.
  double _fastTanh(double x) {
    if (x > 4.0) return 1.0;
    if (x < -4.0) return -1.0;
    final x2 = x * x;
    return x * (27.0 + x2) / (27.0 + 9.0 * x2);
  }

  void reset() {
    _carrierPhase = 0.0;
    _lfoPhase = 0.0;
  }

  void dispose() {}
}
