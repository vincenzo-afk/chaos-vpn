import 'dart:math' as math;

/// Chorus / Flanger modulation effect.
///
/// Works by mixing the dry signal with a pitch-shifted copy created by
/// modulating the read position of a delay line with a low-frequency oscillator (LFO).
///
/// - **Chorus mode** (default): slower LFO rate (~0.25 Hz), moderate depth,
///   higher wet mix. Creates a thick, doubled-voice effect.
/// - **Flanger mode**: faster LFO rate (~0.5–2 Hz), lower depth, lower wet mix.
///   Creates a swooshing, jet-plane effect.
///
/// Theory: delayModMs = depth * sin(2*pi * rate * t / sampleRate)
/// The modulated delay causes a pitch shift (Doppler effect), then
/// mixing with dry creates comb-filtering that sweeps with the LFO.
class ChorusFlanger {
  final int sampleRate;

  // Delay buffer
  late final List<double> _buffer;
  int _writeHead = 0;

  // LFO state
  double _phase = 0.0;

  // Parameters
  double rate = 0.25;       // LFO rate in Hz (0.1–4.0)
  double depth = 8.0;       // modulation depth in ms (1.0–20.0)
  double wetMix = 0.5;      // wet/dry mix (0.0–1.0)
  double feedback = 0.3;    // feedback (0.0–0.9)
  bool enabled = false;

  ChorusFlanger({required this.sampleRate})
      : _buffer = List<double>.filled((sampleRate * 0.05).round(), 0.0); // 50ms max delay

  /// Set chorus mode (slower rate, deeper modulation, more wet).
  void setChorusMode() {
    rate = 0.25;
    depth = 10.0;
    wetMix = 0.6;
    feedback = 0.3;
  }

  /// Set flanger mode (faster rate, shallower modulation).
  void setFlangerMode() {
    rate = 1.5;
    depth = 4.0;
    wetMix = 0.4;
    feedback = 0.2;
  }

  /// Process a buffer, applying chorus/flanger in place.
  void process(List<double> samples) {
    if (!enabled) return;

    const double twoPi = 2.0 * math.pi;

    for (int i = 0; i < samples.length; i++) {
      final dry = samples[i];

      // Write dry to buffer
      _buffer[_writeHead] = dry + feedback * _buffer[
          (_writeHead - (_writeHead < 1 ? _buffer.length - _buffer.length % 1 : 0)) % _buffer.length];

      // LFO: sin(phase) maps to [-1, 1], scale to delay in samples
      final lfo = math.sin(_phase);
      final delaySamples = (depth * (1.0 + lfo) / 2.0 * sampleRate / 1000.0).round()
          .clamp(1, _buffer.length - 1);

      // Read delayed sample with linear interpolation
      final readPos = (_writeHead - delaySamples) % _buffer.length;
      final nextPos = (readPos + 1) % _buffer.length;
      const double frac = 0.5; // nearest-neighbor approximation for speed
      final wet = _buffer[readPos] * (1.0 - frac) + _buffer[nextPos] * frac;

      // Mix dry + wet
      samples[i] = (dry * (1.0 - wetMix) + wet * wetMix).clamp(-1.0, 1.0);

      // Advance
      _writeHead = (_writeHead + 1) % _buffer.length;
      _phase += twoPi * rate / sampleRate;
      if (_phase > twoPi) _phase -= twoPi;
    }
  }

  void reset() {
    for (int i = 0; i < _buffer.length; i++) {
      _buffer[i] = 0.0;
    }
    _writeHead = 0;
    _phase = 0.0;
  }

  void dispose() {}
}
