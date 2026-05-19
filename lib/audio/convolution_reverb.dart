import 'dart:math' as math;
import '../utils/constants.dart';

/// FFT-based partitioned convolution reverb engine.
///
/// Uses overlap-add convolution with a partitioned impulse response for
/// efficient real-time operation. For the default reverb, a synthetic
/// room IR is generated if `impulse_response.wav` is not available.
///
/// Partitioned convolution works by:
///   1. Splitting the IR into small partitions (e.g., 128 samples each)
///   2. FFT each partition once during initialization
///   3. For each audio block, FFT the input and multiply-accumulate
///      with each partition's FFT in the frequency domain
///   4. IFFT and overlap-add to reconstruct the output
///
/// This gives O(N log N) performance vs O(N²) for direct convolution.
class ConvolutionReverb {
  final int sampleRate;

  // FFT size (must be power of 2, >= partition size * 2)
  static const int _fftSize = 512;
  // Partition size in samples
  static const int _partitionSize = 128;
  // Number of partitions
  late final int _numPartitions;

  // IR data (real-valued)
  late final List<double> _ir;
  // Partitioned FFT buffers (real + imaginary for each partition)
  late final List<List<double>> _irFftReal;
  late final List<List<double>> _irFftImag;

  // Input buffer for overlap-add
  final List<double> _inputBuffer = List.filled(_fftSize, 0.0);
  int _inputPos = 0;

  // Output overlap buffer
  final List<double> _overlap = List.filled(_fftSize, 0.0);

  // FFT twiddle factors (precomputed)
  late final List<double> _cosTable;
  late final List<double> _sinTable;

  // Wet/dry mix
  double wetMix = 0.45;
  bool enabled = false;

  // Use synthetic IR instead of loaded file
  bool useSyntheticIr = true;

  ConvolutionReverb({this.sampleRate = AudioConstants.sampleRate}) {
    _initFftTables();
    _ir = _generateSyntheticIr();
    _numPartitions = ((_ir.length + _partitionSize - 1) ~/ _partitionSize);
    _partitionIr();
  }

  /// Load a custom impulse response from a list of samples.
  void loadImpulseResponse(List<double> ir) {
    if (ir.isEmpty) return;
    _ir.setAll(0, ir.take(math.min(ir.length, _ir.length)));
    if (ir.length < _ir.length) {
      for (int i = ir.length; i < _ir.length; i++) {
        _ir[i] = 0.0;
      }
    }
    _partitionIr();
  }

  /// Generate a synthetic small-room impulse response.
  /// Uses decaying noise with early reflections simulated as delayed spikes.
  List<double> _generateSyntheticIr() {
    // IR length: 1.0s at sample rate
    final irLen = sampleRate;
    final ir = List<double>.filled(irLen, 0.0);
    final rng = math.Random(42); // Fixed seed for reproducibility

    // Early reflections (first 50ms)
    final earlyReflections = [2.3, 5.1, 8.7, 12.4, 16.8, 21.3, 26.1, 31.2, 36.8, 43.5];
    for (int i = 0; i < earlyReflections.length; i++) {
      final delaySamples = (earlyReflections[i] * sampleRate / 1000).round();
      if (delaySamples < irLen) {
        ir[delaySamples] = 1.0 / (i + 1) * 0.6;
      }
    }

    // Late reverb (decaying noise, exponentially tapered)
    for (int i = 0; i < irLen; i++) {
      final decay = math.exp(-3.0 * i / irLen);
      ir[i] += (rng.nextDouble() * 2.0 - 1.0) * decay * 0.3;
    }

    return ir;
  }

  /// Precompute FFT twiddle factors.
  void _initFftTables() {
    _cosTable = List.generate(_fftSize, (i) => math.cos(2.0 * math.pi * i / _fftSize));
    _sinTable = List.generate(_fftSize, (i) => math.sin(2.0 * math.pi * i / _fftSize));
  }

  /// Partition the IR and FFT each partition.
  void _partitionIr() {
    _irFftReal = [];
    _irFftImag = [];

    for (int p = 0; p < _numPartitions; p++) {
      final partition = List<double>.filled(_fftSize, 0.0);
      final start = p * _partitionSize;
      for (int i = 0; i < _partitionSize && start + i < _ir.length; i++) {
        partition[i] = _ir[start + i];
      }

      final (real, imag) = _fft(partition);
      _irFftReal.add(real);
      _irFftImag.add(imag);
    }
  }

  /// Process a chunk of samples, replacing them with convolved output.
  void process(List<double> samples) {
    if (!enabled || samples.isEmpty) return;

    int outPos = 0;

    while (outPos < samples.length) {
      // Fill input buffer
      while (_inputPos < _partitionSize && outPos < samples.length) {
        _inputBuffer[_inputPos] = samples[outPos];
        _inputPos++;
        outPos++;
      }

      if (_inputPos >= _partitionSize) {
        // Zero-pad the rest of the input buffer
        for (int i = _partitionSize; i < _fftSize; i++) {
          _inputBuffer[i] = 0.0;
        }

        // FFT the input block
        final (xReal, xImag) = _fft(_inputBuffer);

        // Multiply-accumulate with each partition
        final yReal = List<double>.filled(_fftSize, 0.0);
        final yImag = List<double>.filled(_fftSize, 0.0);

        for (int p = 0; p < _numPartitions; p++) {
          for (int i = 0; i < _fftSize; i++) {
            // Complex multiply: X * IR_p
            final re = xReal[i] * _irFftReal[p][i] - xImag[i] * _irFftImag[p][i];
            final im = xReal[i] * _irFftImag[p][i] + xImag[i] * _irFftReal[p][i];
            yReal[i] += re;
            yImag[i] += im;
          }
        }

        // IFFT
        final (convolved, _) = _ifft(yReal, yImag);


        // Add to overlap buffer
        for (int i = 0; i < _fftSize; i++) {
          _overlap[i] += convolved[i];
        }

        // Read from overlap buffer to output
        final dryLen = math.min(_partitionSize, samples.length - (outPos - _partitionSize));
        for (int i = 0; i < dryLen; i++) {
          final writeIdx = outPos - _partitionSize + i;
          if (writeIdx >= 0 && writeIdx < samples.length) {
            final wet = _overlap[i];
            final dry = samples[writeIdx];
            samples[writeIdx] = (dry * (1.0 - wetMix) + wet * wetMix).clamp(-1.0, 1.0);
          }
        }

        // Shift overlap buffer
        for (int i = 0; i < _fftSize - _partitionSize; i++) {
          _overlap[i] = _overlap[i + _partitionSize];
        }
        for (int i = _fftSize - _partitionSize; i < _fftSize; i++) {
          _overlap[i] = 0.0;
        }

        _inputPos = 0;
      }
    }
  }

  /// Radix-2 Cooley-Tukey FFT (in-place, decimation-in-time).
  /// Returns (real, imag) arrays of length fftSize.
  (List<double> real, List<double> imag) _fft(List<double> input) {
    final n = input.length;
    final real = List<double>.filled(n, 0.0);
    final imag = List<double>.filled(n, 0.0);

    // Bit-reversal permutation
    for (int i = 0; i < n; i++) {
      int j = 0;
      int m = i;
      for (int k = 1; k < n; k <<= 1) {
        j = (j << 1) | (m & 1);
        m >>= 1;
      }
      real[j] = input[i];
      imag[j] = 0.0;
    }

    // FFT butterfly
    for (int len = 2; len <= n; len <<= 1) {
      final halfLen = len >> 1;
      final step = n ~/ len;

      for (int i = 0; i < n; i += len) {
        for (int j = 0; j < halfLen; j++) {
          final wRe = _cosTable[j * step];
          final wIm = -_sinTable[j * step];

          final tRe = real[i + j + halfLen] * wRe - imag[i + j + halfLen] * wIm;
          final tIm = real[i + j + halfLen] * wIm + imag[i + j + halfLen] * wRe;

          real[i + j + halfLen] = real[i + j] - tRe;
          imag[i + j + halfLen] = imag[i + j] - tIm;
          real[i + j] += tRe;
          imag[i + j] += tIm;
        }
      }
    }

    return (real, imag);
  }

  /// Inverse FFT. Returns (timeDomain, _).
  (List<double> real, List<double> imag) _ifft(List<double> realIn, List<double> imagIn) {
    final n = realIn.length;

    final (r, i) = _fft(realIn);

    for (int j = 0; j < n; j++) {
      r[j] = r[j] / n;
    }

    return (r, i);
  }

  void reset() {
    for (int i = 0; i < _fftSize; i++) {
      _inputBuffer[i] = 0.0;
      _overlap[i] = 0.0;
    }
    _inputPos = 0;
  }

  void dispose() {}
}
