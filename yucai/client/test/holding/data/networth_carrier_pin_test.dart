// F49 T4(FR-3/NFR-3)净资产钉死 —— 首页净资产 hero 数据源(NetWorthLocalDataSource):
// isSystem 载体户对金额计算零影响 —— 载体行照常入账面(资产侧按 accountType
// 跳过负债行),其关联 card_loan 借入债剩余照常计入总负债/净资产;
// isSystem 翻转逐位一致;对照无载体库数字不同(含载体余额证明)。
//
// 夹具:储蓄 ¥10,000(asset);载体「平安信用卡 · 卡贷」负债行 ¥8,400
// (isSystem 参数化)+ card_loan 借入债 totalPrincipal ¥8,400、无还款计划
// (paid=0)→ liabilities = 840,000;net = 1,000,000 − 840,000 = 160,000。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/holding/data/holding_local_ds.dart'
    show NetWorthLocalDataSource;

void main() {
  late db.AppDatabase database;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  Future<void> seedAccount(
    String id, {
    required int accountType,
    required int category,
    required int balance,
    bool isSystem = false,
  }) =>
      database.into(database.accounts).insert(
            db.AccountsCompanion.insert(
              id: id,
              name: id,
              accountType: accountType,
              category: category,
              currencyCode: 'CNY',
              initialBalanceCents: balance,
              currentBalanceCents: balance,
              ownership: 1,
              icon: '',
              color: '',
              chartCode: '',
              isSystem: isSystem,
              sortOrder: 0,
              institution: '',
              cardNumberTail: '',
              notes: '',
              goldProductType: '',
              status: 1, // active
              version: 1,
              createdAt: DateTime(2026, 9, 10).toUtc(),
              updatedAt: DateTime(2026, 9, 10).toUtc(),
            ),
          );

  /// 载体名下的 card_loan 借入债(并入型:挂 collectionAccountId)。
  Future<void> seedCardLoan(String id, String accountId, int principalCents) =>
      database.into(database.debts).insert(
            db.DebtsCompanion.insert(
              id: id,
              accountId: accountId,
              counterparty: '平安银行',
              interestRate: 0,
              amortizationMethod: 1,
              startDate: DateTime(2026, 9, 10),
              dueDate: DateTime(2027, 9, 10),
              totalPrincipalCents: principalCents,
              debtType: 1, // borrowedIn
              subtype: 'cardLoan',
              contact: '',
              contractRef: '',
              collectionAccountId: const Value('c1'),
              version: 1,
              createdAt: DateTime(2026, 9, 10),
              updatedAt: DateTime(2026, 9, 10),
            ),
          );

  Future<void> seedBase() => seedAccount('s1',
      accountType: 1, category: 1, balance: 1000000); // 储蓄 ¥10,000

  test('载体置位库:总负债/净资产逐位含载体余额(isSystem 不滤计算)', () async {
    await seedBase();
    await seedAccount('l-carrier',
        accountType: 2,
        category: 7, // loan
        balance: 840000,
        isSystem: true);
    await seedCardLoan('d-card', 'l-carrier', 840000);

    final view = await NetWorthLocalDataSource(database)
        .getNetWorth(baseCurrency: 'CNY');
    expect(view.totalAssetsCents, 1000000, reason: '资产只含储蓄');
    expect(view.totalLiabilitiesCents, 840000,
        reason: '载体关联 card_loan 债务剩余计入总负债');
    expect(view.netWorthCents, 160000);
  });

  test('isSystem 翻转(false 同库):三数逐位一致(计算与置位无关)', () async {
    await seedBase();
    await seedAccount('l-carrier',
        accountType: 2, category: 7, balance: 840000, isSystem: false);
    await seedCardLoan('d-card', 'l-carrier', 840000);

    final view = await NetWorthLocalDataSource(database)
        .getNetWorth(baseCurrency: 'CNY');
    expect(view.totalAssetsCents, 1000000);
    expect(view.totalLiabilitiesCents, 840000);
    expect(view.netWorthCents, 160000);
  });

  test('对照:不含载体库数字不同(证载体余额被计入)', () async {
    await seedBase(); // 仅储蓄,无载体行无债

    final view = await NetWorthLocalDataSource(database)
        .getNetWorth(baseCurrency: 'CNY');
    expect(view.totalAssetsCents, 1000000);
    expect(view.totalLiabilitiesCents, 0,
        reason: '无载体 → 与含载体库 840,000 逐位不同');
    expect(view.netWorthCents, 1000000);
  });
}
