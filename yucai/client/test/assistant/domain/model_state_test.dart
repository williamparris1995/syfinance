import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/assistant/domain/model_state.dart';

/// F67 T1:ModelState sealed 五态 + ModelFailureReason(FR-1..4,ADR-7)
/// —— 值语义(同形相等,ValueListenable 去重通知的前提)、字段携带
/// (downloading 三参/paused 两参)、toString 全 English(NFR-3 结构化
/// 日志可直接携带)。
void main() {
  group('states', () {
    test('five sealed subtypes are distinct ModelState values', () {
      const notDownloaded = ModelNotDownloaded();
      const downloading = ModelDownloading(
        receivedBytes: 1024,
        totalBytes: 2048,
        bytesPerSec: 512,
      );
      const paused = ModelPaused(receivedBytes: 1024, totalBytes: 2048);
      const ready = ModelReady();
      const error = ModelError(ModelFailureReason.network);

      expect(notDownloaded, isA<ModelState>());
      expect(downloading, isA<ModelState>());
      expect(paused, isA<ModelState>());
      expect(ready, isA<ModelState>());
      expect(error, isA<ModelState>());
      expect(notDownloaded, isNot(ready));
      expect(downloading, isNot(paused));
    });

    test('fieldless states are const-canonical (identical instances)', () {
      expect(
        identical(const ModelNotDownloaded(), const ModelNotDownloaded()),
        isTrue,
      );
      expect(identical(const ModelReady(), const ModelReady()), isTrue);
    });

    test('downloading equality is value-based on all three fields', () {
      const a = ModelDownloading(
        receivedBytes: 1024,
        totalBytes: 4096,
        bytesPerSec: 256,
      );
      const b = ModelDownloading(
        receivedBytes: 1024,
        totalBytes: 4096,
        bytesPerSec: 256,
      );
      const otherReceived = ModelDownloading(
        receivedBytes: 2048,
        totalBytes: 4096,
        bytesPerSec: 256,
      );
      const otherTotal = ModelDownloading(
        receivedBytes: 1024,
        totalBytes: 8192,
        bytesPerSec: 256,
      );
      const otherSpeed = ModelDownloading(
        receivedBytes: 1024,
        totalBytes: 4096,
        bytesPerSec: 512,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(otherReceived));
      expect(a, isNot(otherTotal));
      expect(a, isNot(otherSpeed));
    });

    test('paused equality is value-based on both fields', () {
      const a = ModelPaused(receivedBytes: 1024, totalBytes: 4096);
      const b = ModelPaused(receivedBytes: 1024, totalBytes: 4096);
      const otherReceived = ModelPaused(receivedBytes: 2048, totalBytes: 4096);
      const otherTotal = ModelPaused(receivedBytes: 1024, totalBytes: 8192);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(otherReceived));
      expect(a, isNot(otherTotal));
    });

    test('error equality is value-based on reason', () {
      const a = ModelError(ModelFailureReason.network);
      const b = ModelError(ModelFailureReason.network);
      const c = ModelError(ModelFailureReason.corrupt);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('ModelFailureReason', () {
    test('covers exactly the download failure causes (cancel -> '
        'notDownloaded, no canceled reason per LLD)', () {
      expect(ModelFailureReason.values, [
        ModelFailureReason.network,
        ModelFailureReason.corrupt,
      ]);
    });
  });

  group('toString (NFR-3 English logs)', () {
    test('all states render ASCII-only, no CJK', () {
      final states = <ModelState>[
        const ModelNotDownloaded(),
        const ModelDownloading(
          receivedBytes: 1024,
          totalBytes: 4096,
          bytesPerSec: 256,
        ),
        const ModelPaused(receivedBytes: 1024, totalBytes: 4096),
        const ModelReady(),
        const ModelError(ModelFailureReason.corrupt),
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

    test('field-carrying states expose their fields in toString', () {
      const downloading = ModelDownloading(
        receivedBytes: 1024,
        totalBytes: 4096,
        bytesPerSec: 256,
      );
      expect(downloading.toString(), contains('receivedBytes=1024'));
      expect(downloading.toString(), contains('totalBytes=4096'));
      expect(downloading.toString(), contains('bytesPerSec=256'));

      const paused = ModelPaused(receivedBytes: 1024, totalBytes: 4096);
      expect(paused.toString(), contains('receivedBytes=1024'));
      expect(paused.toString(), contains('totalBytes=4096'));
    });
  });

  group('sealed exhaustiveness', () {
    test('switch over ModelState covers all five states', () {
      String label(ModelState state) => switch (state) {
            ModelNotDownloaded() => 'notDownloaded',
            ModelDownloading() => 'downloading',
            ModelPaused() => 'paused',
            ModelReady() => 'ready',
            ModelError() => 'error',
          };
      expect(label(const ModelNotDownloaded()), 'notDownloaded');
      expect(
        label(
          const ModelDownloading(
            receivedBytes: 0,
            totalBytes: 4096,
            bytesPerSec: 0,
          ),
        ),
        'downloading',
      );
      expect(
        label(const ModelPaused(receivedBytes: 0, totalBytes: 4096)),
        'paused',
      );
      expect(label(const ModelReady()), 'ready');
      expect(
        label(const ModelError(ModelFailureReason.network)),
        'error',
      );
    });
  });
}
