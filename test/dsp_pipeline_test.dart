import 'dart:math';
import 'dart:typed_data';

import 'package:chaosvoice/audio/effect_engine.dart';
import 'package:chaosvoice/audio/pcm_utils.dart';
import 'package:chaosvoice/audio/pitch_wobble.dart';
import 'package:chaosvoice/audio/echo_buffer.dart';
import 'package:chaosvoice/models/effect_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PcmUtils.toInt16', () {
    test('never produces values outside Int16 range, even at full scale', () {
      final samples = [1.0, -1.0, 0.999999, -0.999999];
      final out = PcmUtils.toInt16(samples);
      for (final v in out) {
        expect(v >= -32768 && v <= 32767, isTrue);
      }
      expect(out[0], 32767); // 1.0 clamps to 32767, not 32768
      expect(out[1], -32767);
    });
  });

  group('PitchWobble.process', () {
    test('always returns non-empty output for non-empty input', () {
      final pitch = PitchWobble(sampleRate: 16000);
      pitch.range = 3.0;
      final input = List<double>.generate(960, (_) => Random().nextDouble() * 2 - 1);
      for (int i = 0; i < 20; i++) {
        final out = pitch.process(input);
        expect(out, isNotEmpty, reason: 'Iteration $i produced empty output');
      }
    });

    test('output length never exceeds reasonable resampling bounds', () {
      final pitch = PitchWobble(sampleRate: 16000);
      pitch.range = 3.0;
      final input = List<double>.generate(960, (_) => Random().nextDouble() * 2 - 1);
      final out = pitch.process(input);
      // Randomized resampling may slightly grow/shrink the chunk, but never
      // more than 10% — EffectEngine pads/trim to original length afterwards.
      expect(out.length, lessThan(input.length * 1.2));
      expect(out.length, greaterThan(input.length * 0.5));
    });
  });

  group('EchoBuffer', () {
    test('dispose resets state instead of leaving stale references', () {
      final echo = EchoBuffer(sampleRate: 16000, maxDelayMs: 500);
      for (int i = 0; i < 100; i++) {
        echo.write(i, 1.0);
      }
      echo.advance(100);
      echo.dispose();
      // After dispose + internal reset, reading old delay returns silence.
      final stale = echo.readAt(0, delayMs: 100);
      expect(stale.abs(), lessThan(1e-9));
    });
  });

  group('EffectEngine', () {
    late EffectEngine engine;
    late Int16List sineChunk;

    setUp(() {
      engine = EffectEngine(sampleRate: 16000);
      engine.updateFromSettings(const EffectSettings());
      // Synthesize a 440 Hz tone chunk.
      sineChunk = Int16List(960);
      for (int i = 0; i < 960; i++) {
        sineChunk[i] = (32000 * sin(2 * pi * 440 * i / 16000)).toInt();
      }
    });

    test('processes a chunk without throwing and returns same length', () {
      final out = engine.process(sineChunk);
      expect(out.length, sineChunk.length);
    });

    test('output is audibly modified (not identical to input)', () {
      final out = engine.process(sineChunk);
      int differing = 0;
      for (int i = 0; i < out.length; i++) {
        if (out[i] != sineChunk[i]) differing++;
      }
      expect(differing > out.length * 0.5, isTrue,
          reason: 'Effect chain should modify most samples');
    });

    test('masterEnabled=false bypasses all effects', () {
      engine.masterEnabled = false;
      final out = engine.process(sineChunk);
      expect(out, equals(sineChunk));
    });

    test('GraphicEQ does not run when radio filter is disabled', () {
      // With neutral EQ band gains (0 dB), GraphicEQ is effectively a no-op,
      // so outputs should match whether or not the radio filter chain is on.
      final neutralEq = List<double>.filled(5, 0.0);
      final withFilter = const EffectSettings()
          .copyWith(radioFilterEnabled: true, eqBandGains: neutralEq);
      final withoutFilter = const EffectSettings()
          .copyWith(radioFilterEnabled: false, eqBandGains: neutralEq);

      engine.reset();
      engine.updateFromSettings(withFilter);
      final out1 = engine.process(sineChunk);

      engine.reset();
      engine.updateFromSettings(withoutFilter);
      final out2 = engine.process(sineChunk);

      // The only difference between the two paths is the 300–3400 Hz bandpass
      // filter; both must complete without throwing and return full-length
      // chunks. The filtered path must differ from the unfiltered one because
      // the bandpass attenuates sub-bass and air bands of the 440 Hz tone's
      // harmonics/quantization.
      expect(out1.length, sineChunk.length);
      expect(out2.length, sineChunk.length);
      expect(out1, isNot(equals(out2)),
          reason: 'Bandpass filter must act when radio filter is enabled');

      // Key property: with the radio filter OFF, enabling the GraphicEQ
      // toggle does not change the output path (the EQ module is skipped
      // entirely when the chain is disabled — its bandpass emulation only
      // ever runs alongside an enabled radio filter).
      // The EQ module must never run when the radio chain is disabled, even
      // with large band gains configured. Verify by comparing two pipelines
      // that differ ONLY in EQ band gains.
      final eqGains = [5.0, 5.0, 5.0, 5.0, 5.0];
      final settingsWithGains = EffectSettings(
        radioFilterEnabled: false,
        eqBandGains: eqGains,
        gainBoost: 1.0, // unity — no other stage alters the signal
        intensityPreset: 'MILD',
        clipThreshold: 1.0,
        dropoutRate: 0.0,
        crackleIntensity: 0.0,
        bitCrushEnabled: false,
        fuzzEnabled: false,
        clipEnabled: false,
        echoEnabled: false,
        reverbEnabled: false,
        crackleEnabled: false,
        dropoutEnabled: false,
        pitchWobbleEnabled: false,
        masterEnabled: true,
      );
      final settingsFlat = settingsWithGains.copyWith(eqBandGains: [0.0, 0.0, 0.0, 0.0, 0.0]);

      // Use two fresh engines so stateful stages (echo/reverb/bandpass)
      // start from identical conditions for both runs.
      final engineA = EffectEngine(sampleRate: 16000)..updateFromSettings(settingsWithGains);
      final out3 = engineA.process(sineChunk);
      engineA.dispose();

      final engineB = EffectEngine(sampleRate: 16000)..updateFromSettings(settingsFlat);
      final out4 = engineB.process(sineChunk);
      engineB.dispose();

      expect(out3, equals(out4),
          reason: 'EQ must not run when radio filter is disabled');
    });

    test('pitch wobble enabled path pads back to original length', () {
      final s = const EffectSettings().copyWith(pitchWobbleEnabled: true);
      engine.updateFromSettings(s);
      final out = engine.process(sineChunk);
      expect(out.length, sineChunk.length);
    });

    test('updateFromSettings forwards toggles to engine flags', () {
      engine.updateFromSettings(const EffectSettings(radioFilterEnabled: false));
      expect(engine.radioFilterEnabled, isFalse);
      engine.updateFromSettings(const EffectSettings(radioFilterEnabled: true));
      expect(engine.radioFilterEnabled, isTrue);
    });
  });
}
