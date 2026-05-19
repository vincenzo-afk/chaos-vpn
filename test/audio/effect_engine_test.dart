import 'dart:typed_data';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:chaosvoice/audio/effect_engine.dart';
import 'package:chaosvoice/audio/pcm_utils.dart';
import 'package:chaosvoice/models/effect_settings.dart';

void main() {
  group('EffectEngine', () {
    late EffectEngine engine;
    final testInput = Int16List(320);

    setUp(() {
      engine = EffectEngine();
      // Fill with a 440Hz sine wave at 16kHz
      for (int i = 0; i < 320; i++) {
        testInput[i] = (32767.0 * 0.5 * sin(i * 440.0 * 2 * 3.14159 / 16000))
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
      engine.gainBoost = 4.0;
      engine.gainEnabled = true;

      // Disable all other effects
      engine.radioFilterEnabled = false;
      engine.bitCrushEnabled = false;
      engine.fuzzEnabled = false;
      engine.clipEnabled = false;
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

    test('crackle injection adds noise', () {
      engine.crackleIntensity = 1.0; // Always crackle
      engine.crackleEnabled = true;
      engine.gainEnabled = false;
      engine.radioFilterEnabled = false;
      engine.bitCrushEnabled = false;
      engine.fuzzEnabled = false;
      engine.clipEnabled = false;
      engine.echoEnabled = false;
      engine.reverbEnabled = false;
      engine.dropoutEnabled = false;
      engine.pitchWobbleEnabled = false;

      final output = engine.process(testInput);
      final outputDoubles = PcmUtils.toDoubles(output);

      // At 100% crackle, output should differ from input
      bool hasChanged = false;
      for (int i = 0; i < outputDoubles.length; i++) {
        if ((outputDoubles[i] - (testInput[i] / 32767.0)).abs() > 0.01) {
          hasChanged = true;
          break;
        }
      }
      expect(hasChanged, isTrue);
    });

    test('dropout silences frames', () {
      engine.dropoutRate = 1.0; // Always drop out
      engine.dropoutEnabled = true;
      engine.gainEnabled = false;
      engine.radioFilterEnabled = false;
      engine.bitCrushEnabled = false;
      engine.fuzzEnabled = false;
      engine.clipEnabled = false;
      engine.echoEnabled = false;
      engine.reverbEnabled = false;
      engine.crackleEnabled = false;
      engine.pitchWobbleEnabled = false;

      final output = engine.process(testInput);
      final outputDoubles = PcmUtils.toDoubles(output);

      // All samples should be zero
      for (final s in outputDoubles) {
        expect(s, closeTo(0.0, 1e-10));
      }
    });

    test('echo produces delayed signal', () {
      engine.echoEnabled = true;
      engine.gainEnabled = false;
      engine.radioFilterEnabled = false;
      engine.bitCrushEnabled = false;
      engine.fuzzEnabled = false;
      engine.clipEnabled = false;
      engine.reverbEnabled = false;
      engine.crackleEnabled = false;
      engine.dropoutEnabled = false;
      engine.pitchWobbleEnabled = false;

      // Process silence first to initialize echo buffer
      final silence = Int16List(320);
      engine.process(silence);

      // Then process a single impulse
      final impulse = Int16List(320);
      impulse[0] = 30000;
      final output = engine.process(impulse);
      final outputDoubles = PcmUtils.toDoubles(output);

      // Should have non-zero samples beyond just the first sample
      bool hasTail = false;
      for (int i = 10; i < outputDoubles.length; i++) {
        if (outputDoubles[i].abs() > 0.01) {
          hasTail = true;
          break;
        }
      }
      expect(hasTail, isTrue);
    });

    test('hard clipping limits amplitude', () {
      engine.clipThreshold = 0.5;
      engine.clipEnabled = true;
      engine.gainEnabled = false;
      engine.radioFilterEnabled = false;
      engine.bitCrushEnabled = false;
      engine.fuzzEnabled = false;
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
      engine.masterEnabled = true;
      engine.gainEnabled = false;
      engine.radioFilterEnabled = false;
      engine.bitCrushEnabled = false;
      engine.fuzzEnabled = false;
      engine.clipEnabled = false;
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

    test('full pipeline with all effects enabled does not crash', () {
      engine.masterEnabled = true;
      engine.gainEnabled = true;
      engine.radioFilterEnabled = true;
      engine.bitCrushEnabled = true;
      engine.fuzzEnabled = true;
      engine.clipEnabled = true;
      engine.echoEnabled = true;
      engine.reverbEnabled = true;
      engine.crackleEnabled = true;
      engine.dropoutEnabled = true;
      engine.pitchWobbleEnabled = true;

      final output = engine.process(testInput);
      expect(output.length, equals(testInput.length));
      // Output should differ from input
      bool hasChanged = false;
      for (int i = 0; i < output.length; i++) {
        if (output[i] != testInput[i]) {
          hasChanged = true;
          break;
        }
      }
      expect(hasChanged, isTrue);
    });

    test('updateFromSettings applies all parameters', () {
      const settings = EffectSettings(
        gainBoost: 3.0,
        crackleIntensity: 0.05,
        dropoutRate: 0.10,
        fuzzDrive: 2.0,
        bitCrushDepth: 4,
        clipThreshold: 0.5,
        reverbRoomSize: 0.3,
        echoDelay: 150.0,
        echoDecay: 0.5,
        fuzzEnabled: false,
        echoEnabled: false,
      );

      engine.updateFromSettings(settings);

      expect(engine.gainBoost, equals(3.0));
      expect(engine.crackleIntensity, equals(0.05));
      expect(engine.dropoutRate, equals(0.10));
      expect(engine.fuzzDrive, equals(2.0));
      expect(engine.bitCrushDepth, equals(4));
      expect(engine.clipThreshold, equals(0.5));
      expect(engine.reverbRoomSize, equals(0.3));
      expect(engine.echoDelay, equals(150.0));
      expect(engine.echoDecay, equals(0.5));
      expect(engine.fuzzEnabled, isFalse);
      expect(engine.echoEnabled, isFalse);
    });
  });
}
