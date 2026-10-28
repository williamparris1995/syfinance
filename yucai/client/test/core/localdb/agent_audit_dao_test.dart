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

  group('F72 keyword 搜索(spec FR-2,design ADR-1:summary LIKE %kw%)', () {
    /// 自定摘要种子(createdMillis = id×1000,升序入库倒序读)。
    Future<void> seedSummary(int id, String summary) =>
        database.agentAuditDao.insertEvent(db.AgentAuditsCompanion.insert(
          createdMillis: id * 1000,
          tool: 'transaction_add',
          summary: summary,
          ok: true,
          idempotencyKey: 'key-$id',
        ));

    test('keyword 子串匹配:watchPage 与 count 同口径,时间倒序保持', () async {
      await seedSummary(1, '已记:支出 ¥35.00 午饭');
      await seedSummary(2, '已记:支出 ¥4.00 地铁');
      await seedSummary(3, '已记:支出 ¥12.00 午饭 加蛋');
      final dao = database.agentAuditDao;

      final matched = await dao.watchPage(keyword: '午饭').first;
      expect(matched.map((r) => r.id), [3, 1],
          reason: '匹配行倒序;kw 命中 = 任意子串位置');
      expect(await dao.count(keyword: '午饭'), 2);
      // null(缺省)= 全量,既有查询面零扰动。
      expect(await dao.count(), 3);
      expect((await dao.watchPage().first).length, 3);
    });

    test('LIKE 通配转义:%/_/\\ 按字面匹配,不当通配', () async {
      await seedSummary(1, '已记:支出 ¥10.00 100%off 折扣');
      await seedSummary(2, '已记:支出 ¥20.00 a_b 下划线');
      await seedSummary(3, '已记:支出 ¥30.00 普通行');
      await seedSummary(4, r'已记:支出 ¥40.00 反斜杠\字面');
      final dao = database.agentAuditDao;

      // '%' 裸传 LIKE 会全表命中(匹配任意串);转义后只匹配字面含 % 行。
      expect(await dao.count(keyword: '%'), 1,
          reason: '% 按字面,不当通配');
      expect((await dao.watchPage(keyword: '%').first).single.summary,
          contains('100%off'));
      // '_' 同理(裸传 = 任意单字符 → 全表)。
      expect(await dao.count(keyword: '_'), 1,
          reason: '_ 按字面,不当单字符通配');
      // 转义符 '\' 自身也翻倍后可字面匹配。
      expect(await dao.count(keyword: r'反斜杠\字面'), 1);
      // 转义后仍支持 % 包裹语义:含 kw 子串即可命中。
      expect(await dao.count(keyword: 'off'), 1);
    });

    test('空串/空白 keyword = 全量(等同 null);入参首尾空白被裁剪', () async {
      await seedSummary(1, '已记:支出 ¥35.00 午饭');
      await seedSummary(2, '已记:支出 ¥4.00 地铁');
      final dao = database.agentAuditDao;

      expect(await dao.count(keyword: ''), 2, reason: '空串 = 未过滤');
      expect(await dao.count(keyword: '   '), 2, reason: '纯空白 = 未过滤');
      expect((await dao.watchPage(keyword: '').first).length, 2);
      expect(await dao.count(keyword: ' 午饭 '), 1,
          reason: 'trim 后按「午饭」匹配');
    });

    test('大小写:SQLite LIKE 默认 ASCII 不敏感,中文精确', () async {
      await seedSummary(1, '已记:支出 ¥10.00 Lunch');
      await seedSummary(2, '已记:支出 ¥20.00 午饭');
      final dao = database.agentAuditDao;

      expect(await dao.count(keyword: 'lunch'), 1,
          reason: 'ASCII 小写 kw 命中大写列值(SQLite LIKE 默认行为)');
      expect(await dao.count(keyword: 'LUNCH'), 1,
          reason: '反向同理(kw 大写命中小写列值)');
      expect(await dao.count(keyword: 'lUnCh'), 1);
      expect(await dao.count(keyword: '午饭'), 1);
      expect(await dao.count(keyword: '晚饭'), 0, reason: '中文无大小写,精确子串');
    });

    test('keyword + 分页:matched 集内 limit/offset 滑窗,越界空页', () async {
      for (var i = 1; i <= 5; i++) {
        await seedSummary(i, '已记:支出 ¥$i.00 午饭');
      }
      await seedSummary(6, '已记:支出 ¥99.00 地铁');
      await seedSummary(7, '已记:支出 ¥98.00 打车');
      final dao = database.agentAuditDao;

      expect(await dao.count(keyword: '午饭'), 5);
      final first = await dao.watchPage(limit: 3, offset: 0, keyword: '午饭').first;
      final second =
          await dao.watchPage(limit: 3, offset: 3, keyword: '午饭').first;
      final past = await dao.watchPage(limit: 3, offset: 6, keyword: '午饭').first;

      expect(first.map((r) => r.id), [5, 4, 3]);
      expect(second.map((r) => r.id), [2, 1]);
      expect(past, isEmpty, reason: 'offset 相对 matched 集,不含未匹配行');
    });
  });
}
