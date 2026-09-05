// F12 T1(2026-09-05):PendingCountWatcher(spec FR-2,design ADR-2)。
// - 多源求和:任一源发射后按各源最新值重算总和;
// - 墓碑计入计数(forDatabase 真库链:删除也是待同步变更);
// - dispose 统一退订(fake 流手控验证无泄漏)。
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/binding/data/pending_count_watcher.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/sync_state.dart';

void main() {
  group('fake 流手控(核心聚合语义)', () {
    late PendingCountWatcher watcher;
    late List<StreamController<int>> sources;

    setUp(() {
      sources = List.generate(3, (_) => StreamController<int>());
      watcher = PendingCountWatcher(sources.map((s) => s.stream));
    });

    tearDown(() async {
      watcher.dispose(); // 幂等:用例内已 dispose 时此处为空操作。
      for (final s in sources) {
        await s.close();
      }
    });

    test('多源求和:各源发射后按最新值相加,流上得到合并计数', () async {
      final emitted = <int>[];
      final sub = watcher.stream.listen(emitted.add);

      sources[0].add(1);
      await Future<void>.delayed(Duration.zero);
      expect(emitted.last, 1); // 首源先到:部分和即当前已知计数。

      sources[1].add(2);
      await Future<void>.delayed(Duration.zero);
      expect(emitted.last, 3);

      sources[2].add(3);
      await Future<void>.delayed(Duration.zero);
      expect(emitted.last, 6);

      await sub.cancel();
    });

    test('任一源发射触发重算:替换该源最新值后重新求和', () async {
      final emitted = <int>[];
      final sub = watcher.stream.listen(emitted.add);

      sources[0].add(2);
      sources[1].add(3);
      sources[2].add(4);
      await Future<void>.delayed(Duration.zero);
      expect(emitted.last, 9);

      // 某模块清空(如上行回写后):该源归零,其余保持 → 重算。
      sources[1].add(0);
      await Future<void>.delayed(Duration.zero);
      expect(emitted.last, 6);

      await sub.cancel();
    });

    test('dispose 统一退订:之后源发射不再流出,全部源订阅取消', () async {
      // 构造即订阅各源。
      expect(sources.every((s) => s.hasListener), isTrue);

      final emitted = <int>[];
      final sub = watcher.stream.listen(emitted.add);
      sources[0].add(5);
      await Future<void>.delayed(Duration.zero);
      expect(emitted.last, 5);

      watcher.dispose();
      sources[0].add(7); // 退订后源再发射。
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emitted.last, 5, reason: 'dispose 后不应再有输出');
      expect(sources.every((s) => !s.hasListener), isTrue,
          reason: 'dispose 应统一 cancel 全部源订阅');

      await sub.cancel();
    });
  });

  group('forDatabase 真库链(8 头表 + 墓碑)', () {
    test('pending 实体与墓碑均计入(删除也是待同步变更)', () async {
      final database = db.AppDatabase(NativeDatabase.memory());
      final watcher = PendingCountWatcher.forDatabase(database);
      addTearDown(watcher.dispose);
      addTearDown(database.close);

      final emitted = <int>[];
      final sub = watcher.stream.listen(emitted.add);

      Future<void> until(bool Function() cond) async {
        final sw = Stopwatch()..start();
        while (!cond() && sw.elapsed < const Duration(seconds: 2)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(cond(), isTrue, reason: 'condition not met within timeout');
      }

      // 初值:各源首发射(全 0)。
      await until(() => emitted.isNotEmpty);
      expect(emitted.last, 0);

      // 1 条 pending 头行 + 1 条墓碑 → 计数 2。
      await database.accountDao.insertAccount(db.AccountsCompanion.insert(
        id: 'acc-1',
        name: '离线账户',
        accountType: 1,
        category: 2,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        currentBalanceCents: 0,
        ownership: 1,
        icon: '',
        color: '',
        chartCode: '',
        isSystem: false,
        sortOrder: 0,
        institution: '',
        cardNumberTail: '',
        notes: '',
        goldProductType: '',
        status: 1,
        version: 1,
        createdAt: DateTime.utc(2026, 9, 5),
        updatedAt: DateTime.utc(2026, 9, 5),
        syncState: const Value(SyncState.pending),
      ));
      await database.syncTombstoneDao.upsertTombstone(
          db.SyncTombstonesCompanion.insert(
              module: SyncModule.tag,
              entityId: 'tag-del',
              deletedAt: DateTime.utc(2026, 9, 5)));
      await until(() => emitted.last == 2);

      // 头行回写 synced → 仅剩墓碑 1。
      await database.accountDao.markAccountsSynced({'acc-1': 1});
      await until(() => emitted.last == 1);

      await sub.cancel();
    });
  });
}
