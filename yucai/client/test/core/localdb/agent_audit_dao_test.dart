// F71-T1 TDD:AgentAuditDao 查询面(spec FR-1/FR-3,design ADR-2/ADR-3)。
//
// insertEvent 追加 + count + watchPage 时间倒序分页(createdMillis DESC,
// id DESC 同毫秒次锚)—— 对话框「加载更多」式分页的 DAO 契约钉。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db;

void main() {
  late db.AppDatabase database;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  Future<void> seed(int id, int createdMillis,
      {String tool = 'transaction_add', bool ok = true}) {
    return database.agentAuditDao.insertEvent(db.AgentAuditsCompanion.insert(
      createdMillis: createdMillis,
      tool: tool,
      summary: 's$id',
      ok: ok,
      reason: Value(ok ? null : 'versionConflict'),
      entityId: Value(ok ? 'txn-$id' : null),
      idempotencyKey: 'key-$id',
    ));
  }

  test('count:空库 0,追加后递增', () async {
    expect(await database.agentAuditDao.count(), 0);
    await seed(1, 1000);
    await seed(2, 2000);
    expect(await database.agentAuditDao.count(), 2);
  });

  test('watchPage:时间倒序(最新在前),nullable 列逐字段往返', () async {
    await seed(1, 1000, ok: false);
    await seed(2, 3000);
    await seed(3, 2000);

    final page = await database.agentAuditDao.watchPage().first;

    expect(page.map((r) => r.id), equals([2, 3, 1]),
        reason: 'createdMillis 严格倒序');
    // 逐字段往返(nullable reason/entityId 保真)。
    final failed = page.firstWhere((r) => !r.ok);
    expect(failed.reason, 'versionConflict');
    expect(failed.entityId, isNull);
    final okRow = page.firstWhere((r) => r.ok);
    expect(okRow.reason, isNull);
    expect(okRow.entityId, 'txn-${okRow.id}');
    expect(okRow.tool, 'transaction_add');
    expect(okRow.idempotencyKey, 'key-${okRow.id}');
  });

  test('watchPage 分页:limit+offset 窗口滑动,尾窗越界取空', () async {
    for (var i = 1; i <= 5; i++) {
      await seed(i, i * 1000);
    }

    final dao = database.agentAuditDao;
    final first = await dao.watchPage(limit: 2, offset: 0).first;
    final second = await dao.watchPage(limit: 2, offset: 2).first;
    final third = await dao.watchPage(limit: 2, offset: 4).first;
    final past = await dao.watchPage(limit: 2, offset: 6).first;

    expect(first.map((r) => r.id), [5, 4]);
    expect(second.map((r) => r.id), [3, 2]);
    expect(third.map((r) => r.id), [1]);
    expect(past, isEmpty, reason: '越界偏移 = 空页(加载更多终止条件)');
  });

  test('watchPage 同毫秒并列:id 倒序次锚(后写先出)', () async {
    await seed(1, 5000);
    await seed(2, 5000);
    await seed(3, 5000);

    final page = await database.agentAuditDao.watchPage().first;

    expect(page.map((r) => r.id), [3, 2, 1],
        reason: '同 createdMillis 按自增 id 倒序,追加序可预期');
  });
}
