import 'package:flutter_test/flutter_test.dart';
import 'package:chaosvoice/audio/reverb_processor.dart';
import 'dart:math';

void main() {
  group('ReverbProcessor', () {
    late ReverbProcessor reverb;

    setUp(() {
      reverb = ReverbProcessor(sampleRate: 16000);
    });

    test('process returns output of same length', () {
      final input = List<double>.generate(320, (i) => sin(2 * pi * 440 * i / 16000));
      final output = reverb.process(input);
      expect(output.length, equals(input.length));
    });

    test('process handles silence', () {
      final input = List<double>.filled(320, 0.0);
      final output = reverb.process(input);
      for (final s in output) {
        expect(s.abs(), lessThan(1e-10));
      }
    });

    test('process handles empty input', () {
      final output = reverb.process(<double>[]);
      expect(output, isEmpty);
    });

    test('reverb adds tail to impulse signal', () {
      // Create an impulse (single non-zero sample)
      final input = List<double>.filled(320, 0.0);
      input[0] = 1.0;

      final output = reverb.process(input);

      // Should have decay tail after the impulse
      bool hasTail = false;
      for (int i = 10; i < output.length; i++) {
        if (output[i].abs() > 0.001) {
          hasTail = true;
          break;
        }
      }
      expect(hasTail, isTrue);
    });

    test('reverb output decays over time', () {
      final input = List<double>.filled(320, 0.0);
      input[0] = 1.0;

      final output = reverb.process(input);

      // Late samples should have lower amplitude than early samples
      double earlyEnergy = 0;
      double lateEnergy = 0;
      for (int i = 0; i < 50; i++) {
        earlyEnergy += output[i] * output[i];
      }
      for (int i = 200; i < 320; i++) {
        lateEnergy += output[i] * output[i];
      }
      expect(lateEnergy, lessThan(earlyEnergy));
    });

    test('process multiple chunks without error', () {
      for (int chunk = 0; chunk < 5; chunk++) {
        final input = List<double>.generate(320, (i) =>
            0.5 * sin(2 * pi * 440 * (i + chunk * 320) / 16000));
        final output = reverb.process(input);
        expect(output.length, equals(320));
      }
    });

    test('reset clears internal state', () {
      // Run signal through
      final input1 = List<double>.generate(320, (i) => sin(2 * pi * 440 * i / 16000));
      reverb.process(input1);

      // Reset
      reverb.reset();

      // Process silence — should be all zeros (state was cleared)
      final silence = List<double>.filled(320, 0.0);
      final output = reverb.process(silence);
      for (final s in output) {
        expect(s.abs(), lessThan(1e-10));
      }
    });

    test('reverb with different sample rates', () {
      final reverb44k = ReverbProcessor(sampleRate: 44100);
      final input = List<double>.generate(882, (i) => sin(2 * pi * 440 * i / 44100));
      final output = reverb44k.process(input);
      expect(output.length, equals(882));
      // Should have some reverb tail
      bool hasOutput = false;
      for (final s in output) {
        if (s.abs() > 0.001) {
          hasOutput = true;
          break;
        }
      }
      expect(hasOutput, isTrue);
    });
  });
}
