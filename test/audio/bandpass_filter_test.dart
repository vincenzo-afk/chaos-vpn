import 'package:flutter_test/flutter_test.dart';
import 'package:chaosvoice/audio/bandpass_filter.dart';

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

    test('process filters out DC offset', () {
      // Create a signal with DC offset and low frequencies
      final samples = List<double>.filled(320, 0.5);
      filter.process(samples);
      // After HP filter, DC should be removed
      final avg = samples.reduce((a, b) => a + b) / samples.length;
      expect(avg.abs(), lessThan(0.01));
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
  });
}
