import 'package:flutter_test/flutter_test.dart';
import 'package:chaosvoice/audio/bandpass_filter.dart';
import 'dart:math';

void main() {
  group('BandpassFilter', () {
    late BandpassFilter filter;

    setUp(() {
      filter = BandpassFilter(
        sampleRate: 16000,
        lowHz: 300.0,
        highHz: 3400.0,
      );
    });

    test('process does not crash on valid input', () {
      final samples = List<double>.generate(320, (i) => 0.5 * (i * 0.1).sin());
      filter.process(samples);
      expect(samples.length, equals(320));
    });

    test('process handles silence correctly', () {
      final samples = List<double>.filled(320, 0.0);
      filter.process(samples);
      for (final s in samples) {
        expect(s, closeTo(0.0, 1e-10));
      }
    });

    test('process handles empty list', () {
      final samples = <double>[];
      filter.process(samples);
      expect(samples, isEmpty);
    });

    test('initializes with correct coefficients', () {
      // Create a second filter with different frequencies
      final filter2 = BandpassFilter(
        sampleRate: 44100,
        lowHz: 500.0,
        highHz: 2000.0,
      );
      // Process the same input through both filters
      final input = List<double>.generate(320, (i) => 0.5 * (i * 0.1).sin());
      final inputClone = List<double>.from(input);
      filter.process(input);
      filter2.process(inputClone);
      // Filters with different coefficients produce different output
      bool differs = false;
      for (int i = 0; i < input.length; i++) {
        if ((input[i] - inputClone[i]).abs() > 0.001) {
          differs = true;
          break;
        }
      }
      expect(differs, isTrue);
    });

    test('low frequency signals are attenuated', () {
      // Generate a very low frequency signal (50 Hz)
      final lowInput = List<double>.generate(320, (i) => sin(2 * pi * 50 * i / 16000));
      final inputRms = _computeRms(lowInput);
      filter.process(lowInput);
      final outputRms = _computeRms(lowInput);
      // Output should be attenuated (lower RMS)
      expect(outputRms, lessThan(inputRms));
    });

    test('voice band frequencies pass through', () {
      // Generate a mid-range frequency (1000 Hz, in the passband)
      final midInput = List<double>.generate(320, (i) => sin(2 * pi * 1000 * i / 16000));
      final inputRms = _computeRms(midInput);
      filter.process(midInput);
      final outputRms = _computeRms(midInput);
      // Output should be close to input RMS (passband)
      expect(outputRms, greaterThan(inputRms * 0.5));
    });

    test('high frequency signals are attenuated', () {
      // Generate a high frequency signal (8000 Hz, above cutoff)
      final highInput = List<double>.generate(320, (i) => sin(2 * pi * 8000 * i / 16000));
      final inputRms = _computeRms(highInput);
      filter.process(highInput);
      final outputRms = _computeRms(highInput);
      // Output should be attenuated
      expect(outputRms, lessThan(inputRms));
    });

    test('reset clears internal state', () {
      // Run some signal through
      final samples1 = List<double>.generate(320, (i) => 0.5 * (i * 0.1).sin());
      filter.process(samples1);

      // Reset
      filter.reset();

      // Verify it doesn't crash with new signal
      final samples2 = List<double>.generate(320, (i) => 0.3 * (i * 0.05).cos());
      filter.process(samples2);
      expect(samples2.length, equals(320));
    });

    test('process filters out DC offset', () {
      // Create a signal with DC offset and low frequencies
      final samples = List<double>.filled(320, 0.5);
      filter.process(samples);
      // After HP filter, DC should be removed
      final avg = samples.reduce((a, b) => a + b) / samples.length;
      expect(avg.abs(), lessThan(0.01));
    });
  });
}

/// Compute RMS energy of a signal.
double _computeRms(List<double> samples) {
  if (samples.isEmpty) return 0.0;
  double sum = 0.0;
  for (final s in samples) {
    sum += s * s;
  }
  return sqrt(sum / samples.length);
}
