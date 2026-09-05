// TemplateLocalDataSource tests — record linkage (creates the local txn,
// advances nextDate per the copied AdvanceNextDate rules), optimistic lock,
// pause/resume flip.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/account_dao.dart';
import 'package:yucai_client/core/localdb/daos/template_dao.dart';
import 'package:yucai_client/core/notifications/auto_record_scheduler.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/template/data/template_local_ds.dart';
import 'package:yucai_client/template/data/template_remote_ds.dart';
import 'package:yucai_client/template/data/template_repository_impl.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

class _MockRemote extends Mock implements TemplateRemoteDataSource {}

class _FakeNotifier implements ReminderNotifier {
  final sent = <DueNotificationCopy>[];
  @override
  Future<void> show(DueNotificationCopy copy) async => sent.add(copy);
}

void main() {
  late db.AppDatabase database;
  late TemplateLocalDataSource ds;
  late TransactionLocalDataSource txnDs;
  late TemplateDao dao;
  late AccountDao accounts;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    txnDs = TransactionLocalDataSource(database, BalanceLocalUpdater(database));
    ds = TemplateLocalDataSource(database, txnDs);
    dao = database.templateDao;
    accounts = database.accountDao;
  });

  tearDown(() => database.close());

  Future<String> seedAccount(String name, int type) async {
    final id = 'acc-$name';
    if (await accounts.getAccountById(id) != null) return id;
    await accounts.insertAccount(db.AccountsCompanion.insert(
      id: id,
      name: name,
      accountType: type,
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
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    ));
    return id;
  }

  Future<Template> seedTemplate(
      {required TemplateCycle cycle,
      int cycleDays = 0,
      TemplateDirection direction = TemplateDirection.expense}) async {
    final cash = await seedAccount('cash', 1);
    final food = await seedAccount('food', 5);
    return ds.create(
      name: 'rent',
      amountCents: 300000,
      direction: direction,
      sourceAccountId: cash,
      cycle: cycle,
      cycleDays: cycleDays,
      category: food,
    );
  }

  test('record creates the paired txn and advances monthly nextDate',
      () async {
    final t = await seedTemplate(cycle: TemplateCycle.monthly);
    final row = await dao.getTemplateById(t.id);
    final result = await ds.record(t.id);

    // Transaction created at the template's nextDate with expense pairing.
    final txn = await database.transactionDao.getTransactionById(
        result.transactionId);
    expect(txn, isNotNull);
    expect(txn!.transactionDate, row!.nextDate);
    final entries =
        await database.transactionDao.watchEntriesByTransaction(txn.id).first;
    expect(entries, hasLength(2));
    expect(entries.map((e) => e.debitCents), contains(300000));
    expect(entries.map((e) => e.creditCents), contains(300000));

    // nextDate advanced by one month (AddDate direct).
    final advanced =
        DateTime.utc(row.nextDate.year, row.nextDate.month + 1, row.nextDate.day);
    expect(result.nextDate, advanced);
    final updated = await dao.getTemplateById(t.id);
    expect(updated!.version, row.version + 1);
    expect(updated.lastTransactionId, result.transactionId);
  });

  test('record advances weekly/yearly/custom per the copied rules', () async {
    // Capture each row BEFORE recording: nextDate advances from the old value.
    final weekly = await seedTemplate(cycle: TemplateCycle.weekly);
    final wBefore = (await dao.getTemplateById(weekly.id))!.nextDate;
    final r1 = await ds.record(weekly.id);
    expect(r1.nextDate, wBefore.add(const Duration(days: 7)));

    final yearly = await seedTemplate(cycle: TemplateCycle.yearly);
    final yBefore = (await dao.getTemplateById(yearly.id))!.nextDate;
    final r2 = await ds.record(yearly.id);
    expect(r2.nextDate,
        DateTime.utc(yBefore.year + 1, yBefore.month, yBefore.day));

    final custom = await seedTemplate(
        cycle: TemplateCycle.custom, cycleDays: 10);
    final cBefore = (await dao.getTemplateById(custom.id))!.nextDate;
    final r3 = await ds.record(custom.id);
    expect(r3.nextDate, cBefore.add(const Duration(days: 10)));
  });

  test('paused template refuses to record', () async {
    final t = await seedTemplate(cycle: TemplateCycle.monthly);
    await ds.pause(t.id);
    expect(() => ds.record(t.id), throwsA(isA<ServerFailure>()));
  });

  test('pause/resume flips paused and bumps the version', () async {
    final t = await seedTemplate(cycle: TemplateCycle.monthly);
    final paused = await ds.pause(t.id);
    expect(paused.paused, isTrue);
    expect(paused.version, t.version + 1);
    final resumed = await ds.resume(t.id);
    expect(resumed.paused, isFalse);
    expect(resumed.version, t.version + 2);
  });

  test('update with a stale version is rejected', () async {
    final t = await seedTemplate(cycle: TemplateCycle.monthly);
    expect(
      () => ds.update(id: t.id, version: 99, name: 'x'),
      throwsA(isA<ServerFailure>()),
    );
  });

  test('transfer template requires a destination account', () async {
    final cash = await seedAccount('cash', 1);
    final t = await ds.create(
      name: 'move',
      amountCents: 100,
      direction: TemplateDirection.transfer,
      sourceAccountId: cash,
      cycle: TemplateCycle.monthly,
    );
    expect(() => ds.record(t.id), throwsA(isA<ValidationFailure>()));
  });

  // ───────── F14 疑点 #2:endDate 永续语义 ─────────
  // 缺陷:解析层曾把 null/空 endDate 兜底成「今天」落库 → 实体 endDate 非 null
  // → 调度 _catchUpOne 按「≤ endDate 才记」截断 → 次日起永续订阅停记。
  // 契约对齐:server handler `req.EndDate != ""` 门(空串 → DB NULL = 永续),
  // proto 空串即「未设置」;本地解析层必须同语义。
  group('F14 #2 endDate 解析(null/空 = 永续,fail-closed 不可解析)', () {
    test('create endDate=null → 落库 NULL + 实体 null(永续,不兜底今天)',
        () async {
      final t = await seedTemplate(cycle: TemplateCycle.monthly);
      final row = await dao.getTemplateById(t.id);
      expect(row!.endDate, isNull,
          reason: 'null endDate 语义 = 永续,不得兜底存成创建当天');
      expect(t.endDate, isNull);
    });

    test('create endDate=空串 → 同 null(永续)', () async {
      final cash = await seedAccount('cash', 1);
      final t = await ds.create(
        name: 'rent',
        amountCents: 100,
        direction: TemplateDirection.expense,
        sourceAccountId: cash,
        cycle: TemplateCycle.monthly,
        endDate: '',
      );
      expect((await dao.getTemplateById(t.id))!.endDate, isNull);
      expect(t.endDate, isNull);
    });

    test('create endDate=合法日期 → 正常解析存储(截断语义不受影响)', () async {
      final cash = await seedAccount('cash', 1);
      final t = await ds.create(
        name: 'rent',
        amountCents: 100,
        direction: TemplateDirection.expense,
        sourceAccountId: cash,
        cycle: TemplateCycle.monthly,
        endDate: '2030-12-31',
      );
      expect((await dao.getTemplateById(t.id))!.endDate,
          DateTime.utc(2030, 12, 31));
      expect(t.endDate, '2030-12-31');
    });

    test('create endDate=不可解析串 → fail-closed 兜底今天(不永续)', () async {
      final cash = await seedAccount('cash', 1);
      final now = DateTime.now().toUtc();
      final today = DateTime.utc(now.year, now.month, now.day);
      final t = await ds.create(
        name: 'rent',
        amountCents: 100,
        direction: TemplateDirection.expense,
        sourceAccountId: cash,
        cycle: TemplateCycle.monthly,
        endDate: 'not-a-date',
      );
      // 语义裁定:脏串兜底「今天」(fail-closed 停记),而非永续 —— 脏数据被
      // 当成无期限订阅会无限生成交易,资金侧风险更大;与 server 对不可解析
      // 串的零值(公元 1 年,等效已到期)同向 fail-closed。本测试钉住该裁定。
      expect((await dao.getTemplateById(t.id))!.endDate, today);
    });

    test('update endDate=空串 → 清空(对齐 server ClearEndDate 永续语义)',
        () async {
      final cash = await seedAccount('cash', 1);
      final t = await ds.create(
        name: 'rent',
        amountCents: 100,
        direction: TemplateDirection.expense,
        sourceAccountId: cash,
        cycle: TemplateCycle.monthly,
        endDate: '2030-12-31',
      );
      final updated = await ds.update(
          id: t.id, version: t.version, endDate: '');
      expect(updated.endDate, isNull,
          reason: '远端 update 空串 → server ClearEndDate;本地必须同语义');
      expect((await dao.getTemplateById(t.id))!.endDate, isNull);
    });

    test('scheduler 全链:null endDate 模板跨多期补账不截断(永续)', () async {
      // 全链验证(DS 落库 → TemplateRepositoryImpl(guest)→ 调度适配器 →
      // AutoRecordScheduler):nextDate 回拨 3 天(custom 每日),模拟「次日」
      // 调度(today=明天)。永续语义应记 d-3..d+1 共 5 笔;若解析层把 null
      // 兜底存成「创建当天」(d0),调度按 endDate=d0 截断 → 只记 4 笔(缺陷)。
      final remote = _MockRemote();
      final repo = TemplateRepositoryImpl(
          remote, ds, SessionModeTracker()..isGuest = true);
      final created = await repo.create(
        name: 'daily',
        amountCents: 100,
        direction: TemplateDirection.expense,
        sourceAccountId: await seedAccount('cash2', 1),
        cycle: TemplateCycle.custom,
        cycleDays: 1,
        autoRecord: true,
      );
      final t = created.fold(
          (f) => throw StateError('create failed: $f'), (v) => v);
      final now = DateTime.now().toUtc();
      final d0 = DateTime.utc(now.year, now.month, now.day);
      await dao.updateTemplate(db.TransactionTemplatesCompanion(
        id: Value(t.id),
        nextDate: Value(d0.subtract(const Duration(days: 3))),
      ));

      final result = await AutoRecordScheduler(
        templates: TemplateRepoAutoRecord(repo),
        notifier: _FakeNotifier(),
      ).run(d0.add(const Duration(days: 1)));

      expect(result.failed, 0);
      expect(result.recorded, 5,
          reason: 'null endDate = 永续:次日调度仍补齐到期各期,不截断到创建日');
    });
  });
}
