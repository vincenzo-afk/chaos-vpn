import 'package:flutter_test/flutter_test.dart';
import 'package:chaosvoice/audio/echo_buffer.dart';

void main() {
  group('EchoBuffer', () {
    late EchoBuffer buffer;

    setUp(() {
      buffer = EchoBuffer(sampleRate: 16000, maxDelayMs: 500);
    });

    test('initializes with correct capacity', () {
      // 16000 * 500 / 1000 = 8000 samples, +1
      expect(buffer.readAt(0, delayMs: 10), equals(0.0));
    });

    test('write and read back a sample', () {
      buffer.write(0, 0.5);
      buffer.advance(1);

      // Read at delayMs=0 should return 0 since buffer hasn't been advanced enough
      final result = buffer.readAt(0, delayMs: 0);
      expect(result, equals(0.0));
    });

    test('readAt with different offset', () {
      buffer.write(0, 0.25);
      buffer.write(1, 0.5);
      buffer.advance(2);

      final at0 = buffer.readAt(0, delayMs: 0);
      final at1 = buffer.readAt(1, delayMs: 0);
      expect(at0, equals(0.0)); // advanced past
      expect(at1, equals(0.0));
    });

    test('circular buffer wraps around correctly', () {
      // Fill buffer with sequential values
      for (int i = 0; i < 100; i++) {
        buffer.write(i, i.toDouble());
      }
      buffer.advance(100);

      // Read back delayed samples
      final lateSamples = buffer.readAt(50, delayMs: 100);
      expect(lateSamples, equals(0.0)); // values were moved past by advance
    });

    test('reset clears all samples', () {
      buffer.write(0, 0.99);
      buffer.advance(1);
      buffer.reset();

      final sample = buffer.readAt(0, delayMs: 10);
      expect(sample, equals(0.0));
    });

    test('readAt handles delay of 0ms', () {
      buffer.write(0, 0.75);
      buffer.advance(1);

      final result = buffer.readAt(0, delayMs: 0);
      expect(result, equals(0.0));
    });

    test('multiple write and advance cycles', () {
      for (int cycle = 0; cycle < 3; cycle++) {
        for (int i = 0; i < 50; i++) {
          buffer.write(i, 0.1 * cycle);
        }
        buffer.advance(50);
      }

      // Buffer should have retained nothing since we advanced past writes
      expect(buffer.readAt(0, delayMs: 0), equals(0.0));
    });

    test('delay of exactly maxDelayMs reads oldest sample', () {
      buffer.write(0, 0.88);
      buffer.advance(1);

      final result = buffer.readAt(0, delayMs: 500);
      expect(result, equals(0.0));
    });

    test('dispose does not throw', () {
      expect(() => buffer.dispose(), returnsNormally);
    });
  });
}
