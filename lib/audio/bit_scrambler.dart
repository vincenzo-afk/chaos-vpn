import 'dart:math';

import '../utils/constants.dart';

/// BitScrambler — corrupts the sample data itself by XOR-flipping and rotating
/// bits at random positions.
///
/// This is the digital "data corruption" effect: instead of filtering the
/// audio, it mangles the underlying bits of the samples. Low [scrambleDepth]
/// (1–2) produces gritty crackle; medium (3–4) produces robotic mangled
/// speech; high (5–8) produces near-unrecognizable noise screams.
class BitScrambler {
  final int sampleRate;
  final Random _rng;

  /// Number of bits mangled per hit (1–8). Higher = worse.
  int scrambleDepth = 3;

  /// Probability (0.0–1.0) that any given sample is scrambled.
  double scrambleProbability = 0.25;

  /// When true, bits are flipped (XOR); when false, bits are rotated.
  bool useXorFlip = true;

  bool enabled = false;

  BitScrambler({this.sampleRate = AudioConstants.sampleRate})
      : _rng = Random();

  /// Process [samples] in place, mangling bits.
  void process(List<double> samples) {
    if (!enabled || samples.isEmpty) return;

    final depth = scrambleDepth.clamp(1, 8);
    final prob = scrambleProbability.clamp(0.0, 1.0);

    for (int i = 0; i < samples.length; i++) {
      if (_rng.nextDouble() >= prob) continue;

      // Convert the double sample to a raw int16 bit pattern.
      int bits = (samples[i] * 32767.0).round().toInt().toUnsigned(16);

      if (useXorFlip) {
        // Flip a random cluster of [depth] adjacent bits.
        final pos = _rng.nextInt(16 - depth);
        int mask = 0;
        for (int d = 0; d < depth; d++) {
          mask |= (1 << (pos + d));
        }
        bits = bits ^ mask;
      } else {
        // Rotate the whole 16-bit word by a random amount — sounds
        // like alien static, because the waveform is phase-scrambled.
        final rot = 1 + _rng.nextInt(15);
        bits = ((bits << rot) | (bits >>> (16 - rot))) & 0xFFFF;
      }

      // Sign-extend the 16-bit result back to an int, then normalize.
      var signed = bits;
      if (signed >= 0x8000) signed -= 0x10000;
      samples[i] = (signed / 32767.0).clamp(-1.0, 1.0);
    }
  }

  void reset() {}

  void dispose() {}
}
