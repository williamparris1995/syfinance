// TemplateLocalDataSource tests — record linkage (creates the local txn,
// advances nextDate per the copied AdvanceNextDate rules), optimistic lock,
// pause/resume flip.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/account_dao.dart';
import 'package:yucai_client/core/localdb/daos/template_dao.dart';
import 'package:yucai_client/template/data/template_local_ds.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

void main() {
  late db.AppDatabase database;
  late TemplateLocalDataSource ds;
  late TransactionLocalDataSource txnDs;
  late TemplateDao dao;
  late AccountDao accounts;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    txnDs = TransactionLocalDataSource(database);
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
}
