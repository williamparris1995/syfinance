/// F33 债务 subtype 持久化链路 E2E。
///
/// 真实本地数据源管道(与 UI bloc 同一写管道,照 link_* 系列惯例):
/// ① 编辑改 subtype 落 drift 并读回(FR-1 存量修正端到端);
/// ② 空串更新保持原值(旧 client 兼容,NFR-2 端到端)。
///
/// 自包含夹具:`链路信用贷` 账户 + `链路银行` 债务,与演示数据零耦合。
/// 运行:`flutter test integration_test/link_debt_subtype_test.dart -d windows`
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/demo/demo_seed.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DebtLocalDataSource debts;
  late AccountLocalDataSource accounts;
  late String loanId;
  late String debtId;

  setUpAll(() async {
    // 确定性起点:删除本地库(含种子/演示数据),随后按需重建。
    final support = await getApplicationSupportDirectory();
    final dbFile = File('${support.path}/yucai_test.db');
    if (await dbFile.exists()) await dbFile.delete();
    await configureDependencies();
    await seedDemoData(getIt<AppDatabase>()); // 幂等;夹具独立于演示数据
    db = getIt<AppDatabase>();
    final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    debts = DebtLocalDataSource(db, txns);
    accounts = AccountLocalDataSource(db);

    // ---- 自包含夹具:贷款账户 + 房贷标签借款 ----
    final loan = await accounts.create(const CreateAccountParams(
      name: '链路信用贷',
      accountType: AccountType.liability,
      category: AccountCategory.loan,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    loanId = loan.id;
    final debt = await debts.create(
      accountId: loanId,
      counterparty: '链路银行',
      interestRate: 0.05,
      amortizationIndex: 1,
      startDate: DateTime.utc(2026, 1, 1),
      dueDate: DateTime.utc(2027, 1, 1),
      totalPrincipalCents: 10000000, // ¥100,000
      type: DebtType.borrowedIn,
      subtype: DebtSubtypes.mortgage,
    );
    debtId = debt.id;
  });

  testWidgets('F33① 编辑改 subtype 落库读回(mortgage→credit_loan)', (t) async {
    final before = await debts.get(debtId);
    expect(before.debt.subtype, DebtSubtypes.mortgage);

    await debts.update(
      id: debtId,
      counterparty: before.debt.counterparty,
      interestRate: before.debt.interestRate,
      version: before.debt.version,
      subtype: DebtSubtypes.creditLoan,
    );

    final after = await debts.get(debtId);
    expect(after.debt.subtype, DebtSubtypes.creditLoan);
    // 其余字段不受影响(counterparty 保真)。
    expect(after.debt.counterparty, '链路银行');
  });

  testWidgets('F33② 空串更新保持 subtype(旧 client 兼容,NFR-2)', (t) async {
    final before = await debts.get(debtId);
    expect(before.debt.subtype, DebtSubtypes.creditLoan);

    await debts.update(
      id: debtId,
      counterparty: '链路银行改',
      interestRate: before.debt.interestRate,
      version: before.debt.version,
      // subtype 缺省 = 空串:不得清洗已改的 credit_loan。
      contact: '13900000000',
    );

    final after = await debts.get(debtId);
    expect(after.debt.subtype, DebtSubtypes.creditLoan);
    expect(after.debt.contact, '13900000000'); // 其余字段正常更新
  });
}
