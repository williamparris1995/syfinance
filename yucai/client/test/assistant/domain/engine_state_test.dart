import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/assistant/domain/engine_state.dart';

/// F66 T1:EngineState sealed 四态 + EngineFailureReason(FR-1/FR-3,ADR-5)
/// —— 值语义(同形相等,ValueListenable 去重通知的前提)、reason 枚举面、
/// toString 全 English(NFR-3 结构化日志可直接携带)。
void main() {
  group('states', () {
    test('four sealed subtypes are distinct EngineState values', () {
      const stopped = EngineStopped();
      const starting = EngineStarting();
      final ready = EngineReady(Uri.parse('http://127.0.0.1:8080/v1'));
      const error = EngineError(EngineFailureReason.modelMissing);

      expect(stopped, isA<EngineState>());
      expect(starting, isA<EngineState>());
      expect(ready, isA<EngineState>());
      expect(error, isA<EngineState>());
      expect(stopped, isNot(starting));
      expect(ready, isNot(error));
    });

    test('fieldless states are const-canonical (identical instances)', () {
      expect(identical(const EngineStopped(), const EngineStopped()), isTrue);
      expect(identical(const EngineStarting(), const EngineStarting()), isTrue);
    });

    test('ready equality is value-based on endpoint', () {
      final a = EngineReady(Uri.parse('http://127.0.0.1:9000/v1'));
      final b = EngineReady(Uri.parse('http://127.0.0.1:9000/v1'));
      final c = EngineReady(Uri.parse('http://127.0.0.1:9001/v1'));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('error equality is value-based on reason', () {
      const a = EngineError(EngineFailureReason.crashed);
      const b = EngineError(EngineFailureReason.crashed);
      const c = EngineError(EngineFailureReason.startFailed);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('EngineFailureReason', () {
    test('covers exactly the FR-1 failure causes', () {
      expect(EngineFailureReason.values, [
        EngineFailureReason.modelMissing,
        EngineFailureReason.crashed,
        EngineFailureReason.startFailed,
      ]);
    });
  });

  group('toString (NFR-3 English logs)', () {
    test('all states render ASCII-only, no CJK', () {
      final states = <EngineState>[
        const EngineStopped(),
        const EngineStarting(),
        EngineReady(Uri.parse('http://127.0.0.1:8080/v1')),
        const EngineError(EngineFailureReason.modelMissing),
      ];
      final ascii = RegExp(r'^[\x20-\x7E]*$');
      for (final state in states) {
        expect(
          state.toString(),
          matches(ascii),
          reason: '${state.runtimeType} toString must be ASCII',
        );
      }
    });
  });

  group('sealed exhaustiveness', () {
    test('switch over EngineState covers all four states', () {
      String label(EngineState state) => switch (state) {
            EngineStopped() => 'stopped',
            EngineStarting() => 'starting',
            EngineReady() => 'ready',
            EngineError() => 'error',
          };
      expect(label(const EngineStopped()), 'stopped');
      expect(label(const EngineStarting()), 'starting');
      expect(
        label(EngineReady(Uri.parse('http://127.0.0.1:8080/v1'))),
        'ready',
      );
      expect(label(const EngineError(EngineFailureReason.crashed)), 'error');
    });
  });
}
