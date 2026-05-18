import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:chaosvoice/audio/effect_engine.dart';
import 'package:chaosvoice/audio/pcm_utils.dart';

void main() {
  group('EffectEngine', () {
    late EffectEngine engine;
    final testInput = Int16List(320);

    setUp(() {
      engine = EffectEngine();
      // Fill with a 440Hz sine wave at 16kHz
      for (int i = 0; i < 320; i++) {
        testInput[i] = (32767.0 * 0.5 * (i * 440.0 * 2 * 3.14159 / 16000).sin())
            .round();
      }
    });

    test('process returns output of same length', () {
      final output = engine.process(testInput);
      expect(output.length, equals(testInput.length));
    });

    test('process does not crash on empty input', () {
      final output = engine.process(Int16List(0));
      expect(output.length, equals(0));
    });

    test('gain boost amplifies signal', () {
      engine.gainFactor = 4.0;
      engine.gainEnabled = true;

      // Disable all other effects
      engine.bandpassEnabled = false;
      engine.bitCrushEnabled = false;
      engine.softClipEnabled = false;
      engine.hardClipEnabled = false;
      engine.echoEnabled = false;
      engine.reverbEnabled = false;
      engine.crackleEnabled = false;
      engine.dropoutEnabled = false;
      engine.pitchWobbleEnabled = false;

      final output = engine.process(testInput);
      final inputDoubles = PcmUtils.toDoubles(testInput);
      final outputDoubles = PcmUtils.toDoubles(output);

      // Output should generally have higher amplitude
      double inputEnergy = 0;
      double outputEnergy = 0;
      for (int i = 0; i < 320; i++) {
        inputEnergy += inputDoubles[i] * inputDoubles[i];
        outputEnergy += outputDoubles[i] * outputDoubles[i];
      }
      expect(outputEnergy, greaterThan(inputEnergy));
    });

    test('bit crusher reduces quality', () {
      engine.bitDepth = 2;
      engine.bitCrushEnabled = true;
      engine.gainEnabled = false;
      engine.bandpassEnabled = false;
      engine.softClipEnabled = false;
      engine.hardClipEnabled = false;
      engine.echoEnabled = false;
      engine.reverbEnabled = false;
      engine.crackleEnabled = false;
      engine.dropoutEnabled = false;
      engine.pitchWobbleEnabled = false;

      final output = engine.process(testInput);
      final outputDoubles = PcmUtils.toDoubles(output);

      // At 2-bit, most samples should be quantized to few values
      final uniqueValues = outputDoubles.toSet();
      expect(uniqueValues.length, lessThan(10));
    });

    test('hard clipping limits amplitude', () {
      engine.hardClipThreshold = 0.5;
      engine.hardClipEnabled = true;
      engine.gainEnabled = false;
      engine.bandpassEnabled = false;
      engine.bitCrushEnabled = false;
      engine.softClipEnabled = false;
      engine.echoEnabled = false;
      engine.reverbEnabled = false;
      engine.crackleEnabled = false;
      engine.dropoutEnabled = false;
      engine.pitchWobbleEnabled = false;

      // Create high-amplitude input
      final loudInput = Int16List(320);
      for (int i = 0; i < 320; i++) {
        loudInput[i] = 30000;
      }

      final output = engine.process(loudInput);
      final outputDoubles = PcmUtils.toDoubles(output);

      // All samples should be at or below the threshold
      for (final sample in outputDoubles) {
        expect(sample.abs(), lessThanOrEqualTo(0.55));
      }
    });

    test('all effects disabled passes signal through', () {
      engine.gainEnabled = false;
      engine.bandpassEnabled = false;
      engine.bitCrushEnabled = false;
      engine.softClipEnabled = false;
      engine.hardClipEnabled = false;
      engine.echoEnabled = false;
      engine.reverbEnabled = false;
      engine.crackleEnabled = false;
      engine.dropoutEnabled = false;
      engine.pitchWobbleEnabled = false;

      final output = engine.process(testInput);
      // Signal should pass through mostly unchanged
      for (int i = 0; i < 320; i++) {
        expect(output[i], closeTo(testInput[i], 1));
      }
    });

    test('updateFromSettings applies all parameters', () {
      final settings = EffectSettings(
        gainFactor: 3.0,
        crackleProb: 0.05,
        dropoutProb: 0.10,
        softDrive: 2.0,
        bitDepth: 4,
        hardClipThreshold: 0.5,
        reverbMix: 0.3,
        softClipEnabled: false,
        echoEnabled: false,
      );

      engine.updateFromSettings(settings);

      expect(engine.gainFactor, equals(3.0));
      expect(engine.crackleProb, equals(0.05));
      expect(engine.dropoutProb, equals(0.10));
      expect(engine.softDrive, equals(2.0));
      expect(engine.bitDepth, equals(4));
      expect(engine.hardClipThreshold, equals(0.5));
      expect(engine.reverbMix, equals(0.3));
      expect(engine.softClipEnabled, isFalse);
      expect(engine.echoEnabled, isFalse);
    });
  });
}
