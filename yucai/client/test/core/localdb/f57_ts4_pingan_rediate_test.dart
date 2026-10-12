import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/localdb/repairs.dart';

/// F57-TS4 平安四笔期表前移修复:首期=放款日当天(银行当期起扣口径)。
/// 照 e_dai_unhook_test 范式:合成库种同 ID 债,跑修复断言。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  Future<void> seedDebt(String id, List<DateTime> dates, List<bool> paid,
      {DateTime? due}) async {
    await db.into(db.accounts).insert(AccountsCompanion.insert(
        id: 'acc-$id',
        name: '载体 $id',
        accountType: 2,
        category: 7,
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
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1)));
    await db.into(db.debts).insert(DebtsCompanion.insert(
        id: id,
        accountId: 'acc-$id',
        counterparty: '平安银行',
        interestRate: 0.1,
        amortizationMethod: 1,
        contact: '',
        contractRef: '',
        totalPrincipalCents: 100000,
        debtType: 1,
        subtype: 'card_loan',
        startDate: DateTime.utc(2024, 12, 24),
        dueDate: due ?? dates.last,
        version: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1)));
    for (var i = 0; i < dates.length; i++) {
      await db.into(db.paymentScheduleEntries).insert(
          PaymentScheduleEntriesCompanion.insert(
              id: '$id-e$i',
              debtId: id,
              paymentDate: dates[i],
              principalCents: 1000,
              interestCents: 100,
              totalCents: 1100,
              paid: paid[i],
              paidCents: paid[i] ? 1100 : 0));
    }
  }

  test('四笔期表整体前移一月,首期即放款日;due 同步;35k 开关置关', () async {
    await seedDebt('88f3f34b-a6cb-48af-b1ec-b30c79c519ec',
        [DateTime.utc(2025, 1, 24), DateTime.utc(2025, 2, 24)], [true, false]);
    await seedDebt('1bc53282-cf9d-4091-bf0d-2f9ee2058d79',
        [DateTime.utc(2026, 7, 12), DateTime.utc(2026, 8, 12)], [true, false]);
    // 无关债:不受影响。
    await seedDebt('other-debt',
        [DateTime.utc(2025, 6, 1), DateTime.utc(2025, 7, 1)], [false, false]);

    // 空库 open 时 beforeOpen 链已种 marker(seed-stage 语义,照 e_dai 先例);
    // 测试手动调用前删 marker 以模拟「真数据在场、链内首跑」。
    await (db.delete(db.appMeta)
          ..where((m) => m.key.equals('f57_ts4_pingan_redate_v1')))
        .go();
    await runF57Ts4PingAnRedate(db);

    Future<List<DateTime>> datesOf(String id) async {
      final rows = await (db.select(db.paymentScheduleEntries)
            ..where((e) => e.debtId.equals(id)))
          .get();
      return rows.map((e) => e.paymentDate).toList()..sort();
    }
    expect(await datesOf('88f3f34b-a6cb-48af-b1ec-b30c79c519ec'),
        [DateTime.utc(2024, 12, 24), DateTime.utc(2025, 1, 24)]);
    expect(await datesOf('1bc53282-cf9d-4091-bf0d-2f9ee2058d79'),
        [DateTime.utc(2026, 6, 12), DateTime.utc(2026, 7, 12)]);
    expect(await datesOf('other-debt'),
        [DateTime.utc(2025, 6, 1), DateTime.utc(2025, 7, 1)]);

    final due25k = await (db.select(db.debts)
          ..where((d) => d.id.equals('88f3f34b-a6cb-48af-b1ec-b30c79c519ec')))
        .getSingle();
    expect(due25k.dueDate, DateTime.utc(2025, 1, 24));
    final sw35k = await (db.select(db.debts)
          ..where((d) =>
              d.id.equals('1bc53282-cf9d-4091-bf0d-2f9ee2058d79')))
        .getSingle();
    expect(sw35k.countsTowardCardLimit, isFalse);
    final sw25k = due25k;
    expect(sw25k.countsTowardCardLimit, isTrue); // 其余债开关不动(默认开)
  });

  test('幂等:marker 后二次运行零变化', () async {
    await seedDebt('f47c78a1-4b14-4629-9cde-49b262fda44b',
        [DateTime.utc(2026, 9, 2), DateTime.utc(2026, 10, 2)], [true, false]);
    // 空库 open 时 beforeOpen 链已种 marker(seed-stage 语义,照 e_dai 先例);
    // 测试手动调用前删 marker 以模拟「真数据在场、链内首跑」。
    await (db.delete(db.appMeta)
          ..where((m) => m.key.equals('f57_ts4_pingan_redate_v1')))
        .go();
    await runF57Ts4PingAnRedate(db);
    final after = await (db.select(db.paymentScheduleEntries)
          ..where((e) =>
              e.debtId.equals('f47c78a1-4b14-4629-9cde-49b262fda44b')))
        .get();
    await runF57Ts4PingAnRedate(db); // 二次
    final again = await (db.select(db.paymentScheduleEntries)
          ..where((e) =>
              e.debtId.equals('f47c78a1-4b14-4629-9cde-49b262fda44b')))
        .get();
    expect(
        again.map((e) => e.paymentDate).toList(),
        containsAll(after.map((e) => e.paymentDate).toList()));
    expect(again.length, after.length);
  });
}
