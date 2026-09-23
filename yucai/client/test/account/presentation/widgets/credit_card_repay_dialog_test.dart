// CreditCardRepayDialog widget 测试:三方式交互 + 储蓄卡余额不足拦截 +
// 最低/分期后自动挂失本期催办。对话框纯回调,无需 DI。
// T7 起全额/最低/分期基数 = 上期账单应还(statementDueCents,经共享推导
// 由组合根算好注入;账单日未设降级 = 当前欠款,文案「全额」维持)。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/widgets/credit_card_repay_dialog.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/notifications/credit_card_due_source.dart';
import 'package:yucai_client/core/notifications/credit_card_statement.dart';
import 'package:yucai_client/core/theme/app_theme.dart';
import 'package:yucai_client/core/widgets/amount_input.dart';

Account _card({int debtCents = 500000}) => Account(
      id: 'card1',
      name: '招行信用卡',
      accountType: AccountType.liability,
      category: AccountCategory.creditCard,
      currencyCode: 'CNY',
      initialBalanceCents: debtCents,
      currentBalanceCents: debtCents,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

Account _savings(String id, String name, int balanceCents) => Account(
      id: id,
      name: name,
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: balanceCents,
      currentBalanceCents: balanceCents,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

Future<void> _pump(WidgetTester tester, Widget dialog) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: FilledButton(
            key: const Key('open'),
            onPressed: () => showDialog<void>(context: ctx, builder: (_) => dialog),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('repaySubmitBtn')));
  await tester.pumpAndSettle();
  // AppToast 3 秒自动消失的 Timer 须在测试内走完,否则 pending timer 断言失败。
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('全额(降级:未设账单日):余额不足禁用提交并提示,足额后提交回调正确金额与账户',
      (tester) async {
    final repayments = <(int, String)>[];
    var dismissed = 0;
    await _pump(
        tester,
        CreditCardRepayDialog(
          card: _card(debtCents: 500000),
          statementDueCents: 500000, // 账单日未设 → 降级 = 当前欠款
          hasBillingDay: false,
          savingsAccounts: [
            _savings('poor', '穷储蓄', 10000), // ¥100 < ¥5000
            _savings('rich', '富储蓄', 900000),
          ],
          hasActiveInstallment: false,
          onRepay: (cents, from) async {
            repayments.add((cents, from));
            return true;
          },
          onInstallment: (p, n, r) async => true,
          onDismissCycle: () async => dismissed++,
        ));

    // 降级文案:「全额」(不带上期账单后缀)。
    expect(find.text('全额'), findsOneWidget);

    // 预选第一个储蓄卡(穷储蓄 ¥100)→ 余额不足。
    expect(find.byKey(const ValueKey('repayInsufficientHint')), findsOneWidget);
    expect(tester.widget<ElevatedButton>(
            find.byKey(const ValueKey('repaySubmitBtn'))).enabled, isFalse);

    // 换富储蓄卡 → 可提交,全额 = 欠款 5000.00。
    await tester.tap(find.byKey(const ValueKey('repaySavingsField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('富储蓄（余额 ¥9000.00）'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('repayInsufficientHint')), findsNothing);

    await _submit(tester);
    expect(repayments, [(500000, 'rich')]);
    // 全额还清,不挂失(无未清欠款可催)。
    expect(dismissed, 0);
    expect(find.text('信用卡还款'), findsNothing); // 对话框已关闭
  });

  testWidgets('T7 全额(账单日已设):基数 = 上期账单应还,标签「全额(上期账单)」,概览仍示当前欠款',
      (tester) async {
    final repayments = <(int, String)>[];
    await _pump(
        tester,
        CreditCardRepayDialog(
          card: _card(debtCents: 500000),
          statementDueCents: 420000, // 应还 4200.00 ≠ 当前欠款 5000.00
          hasBillingDay: true,
          savingsAccounts: [_savings('rich', '富储蓄', 900000)],
          hasActiveInstallment: false,
          onRepay: (cents, from) async {
            repayments.add((cents, from));
            return true;
          },
          onInstallment: (p, n, r) async => true,
          onDismissCycle: () async {},
        ));

    expect(find.text('全额(上期账单)'), findsOneWidget);
    // 只读金额 = 应还 4200.00;卡片概览「当前欠款 ¥5000.00」照旧(两数分开)。
    expect(find.text('¥4200.00'), findsOneWidget);
    expect(find.textContaining('当前欠款 ¥5000.00'), findsOneWidget);

    await _submit(tester);
    expect(repayments, [(420000, 'rich')]); // 全额 = 上期账单应还
  });

  testWidgets('T7 最低:预填 ⌈10% × 应还⌉(基数 = 上期账单应还)', (tester) async {
    final repayments = <(int, String)>[];
    var dismissed = 0;
    await _pump(
        tester,
        CreditCardRepayDialog(
          card: _card(debtCents: 500000),
          statementDueCents: 420000,
          hasBillingDay: true,
          savingsAccounts: [_savings('rich', '富储蓄', 900000)],
          hasActiveInstallment: false,
          onRepay: (cents, from) async {
            repayments.add((cents, from));
            return true;
          },
          onInstallment: (p, n, r) async => true,
          onDismissCycle: () async => dismissed++,
        ));

    await tester.tap(find.text('最低'));
    await tester.pumpAndSettle();
    // 预填 ⌈10% × 4200.00⌉ = 420.00(基数是应还,不是当前欠款 5000)。
    expect(find.text('420.00'), findsOneWidget);

    await _submit(tester);
    expect(repayments, [(42000, 'rich')]);
    expect(dismissed, 1); // 最低还款后自动不再催办本期
  });

  testWidgets('T7 分期:金额预填 = 上期账单应还', (tester) async {
    final installments = <(int, int, double)>[];
    await _pump(
        tester,
        CreditCardRepayDialog(
          card: _card(debtCents: 500000),
          statementDueCents: 420000,
          hasBillingDay: true,
          savingsAccounts: [_savings('rich', '富储蓄', 900000)],
          hasActiveInstallment: false,
          onRepay: (c, f) async => true,
          onInstallment: (p, n, r) async {
            installments.add((p, n, r));
            return true;
          },
          onDismissCycle: () async {},
        ));

    await tester.tap(find.text('分期'));
    await tester.pumpAndSettle();
    // 分期金额预填 = 应还 4200.00。
    expect(
        tester
            .widget<AmountInput>(
                find.byKey(const ValueKey('repayAmountField')))
            .controller
            .text,
        '4200.00');

    await tester.enterText(
        find.byKey(const ValueKey('repayRateField')), '3.6');
    await tester.pumpAndSettle();
    await _submit(tester);
    expect(installments, [(420000, 12, 3.6)]);
  });

  testWidgets('最低(降级):预填 10% × 当前欠款,提交后还款并挂失本期', (tester) async {
    final repayments = <(int, String)>[];
    var dismissed = 0;
    await _pump(
        tester,
        CreditCardRepayDialog(
          card: _card(debtCents: 500000),
          statementDueCents: 500000, // 降级 = 当前欠款
          hasBillingDay: false,
          savingsAccounts: [_savings('rich', '富储蓄', 900000)],
          hasActiveInstallment: false,
          onRepay: (cents, from) async {
            repayments.add((cents, from));
            return true;
          },
          onInstallment: (p, n, r) async => true,
          onDismissCycle: () async => dismissed++,
        ));

    await tester.tap(find.text('最低'));
    await tester.pumpAndSettle();
    // 预填 ⌈10% × 5000.00⌉ = 500.00。
    expect(find.text('500.00'), findsOneWidget);

    await _submit(tester);
    expect(repayments, [(50000, 'rich')]);
    expect(dismissed, 1); // 最低还款后自动不再催办本期
    expect(find.text('信用卡还款'), findsNothing);
  });

  testWidgets('分期(降级):利率必填,提交建分期债并挂失;已挂账时分段禁用', (tester) async {
    final installments = <(int, int, double)>[];
    var dismissed = 0;

    Widget dialog({required bool hasInstallment}) => CreditCardRepayDialog(
          card: _card(debtCents: 500000),
          statementDueCents: 500000, // 降级 = 当前欠款
          hasBillingDay: false,
          savingsAccounts: [_savings('rich', '富储蓄', 900000)],
          hasActiveInstallment: hasInstallment,
          onRepay: (c, f) async => true,
          onInstallment: (p, n, r) async {
            installments.add((p, n, r));
            return true;
          },
          onDismissCycle: () async => dismissed++,
        );

    // 已挂分期 → 分期段禁用。
    await _pump(tester, dialog(hasInstallment: true));
    // 泛型私有类型参数不能用 byType 精确匹配,改用谓词。
    final seg = tester.widget<SegmentedButton>(
        find.byWidgetPredicate((w) => w is SegmentedButton));
    expect(seg.segments.any((s) => !s.enabled), isTrue);
    expect(find.text('该卡已有挂账分期/债务，不能再创建分期'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    // 正常分期:利率未填 → 提交禁用;填 3.6% + 12 期 → 提交。
    await _pump(tester, dialog(hasInstallment: false));
    await tester.tap(find.text('分期'));
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(
            find.byKey(const ValueKey('repaySubmitBtn'))).enabled, isFalse);

    await tester.enterText(
        find.byKey(const ValueKey('repayRateField')), '3.6');
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(
            find.byKey(const ValueKey('repaySubmitBtn'))).enabled, isTrue);
    // 每期预览出现(12 期等额本息,每期约 ¥424.83 含手续费)。
    expect(find.textContaining('每期约 ¥424.8'), findsOneWidget);

    await _submit(tester);
    expect(installments, [(500000, 12, 3.6)]);
    expect(dismissed, 1);
    expect(find.text('信用卡还款'), findsNothing);
  });

  testWidgets('「本期不再提醒」独立挂失,不产生任何还款', (tester) async {
    var dismissed = 0;
    var repaid = 0;
    await _pump(
        tester,
        CreditCardRepayDialog(
          card: _card(),
          statementDueCents: 500000,
          hasBillingDay: false,
          savingsAccounts: [_savings('rich', '富储蓄', 900000)],
          hasActiveInstallment: false,
          onRepay: (c, f) async {
            repaid++;
            return true;
          },
          onInstallment: (p, n, r) async => true,
          onDismissCycle: () async => dismissed++,
        ));

    await tester.tap(find.text('本期不再提醒'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(dismissed, 1);
    expect(repaid, 0);
    expect(find.text('信用卡还款'), findsNothing);
  });

  testWidgets('T7 与提醒源同一数字:同 fixture 下对话框全额 = 源候选金额(共享推导)',
      (tester) async {
    // 同一内存库 fixture:时钟 2026-09-22,账单日 15 → D = 09-15;
    // 欠款 500000 = 账单内 100000(09-10)+ 本周期 80000(09-18)+ 更早 320000。
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(() => database.close());
    await database.into(database.accounts).insert(
          db.AccountsCompanion.insert(
            id: 'card1',
            name: '招行信用卡',
            accountType: 2,
            category: 2,
            currencyCode: 'CNY',
            initialBalanceCents: 0,
            currentBalanceCents: 500000,
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
            creditRepaymentDay: const Value(25),
            creditBillingDay: const Value(15),
          ),
        );
    for (final (id, day, cents) in [
      ('s1', 10, 100000),
      ('s2', 18, 80000),
    ]) {
      final date = DateTime(2026, 9, day);
      await database.into(database.transactions).insert(
            db.TransactionsCompanion.insert(
              id: id,
              transactionDate: date,
              description: 'fixture',
              version: 1,
              createdAt: DateTime.now().toUtc(),
              updatedAt: DateTime.now().toUtc(),
            ),
          );
      await database.into(database.transactionEntries).insert(
            db.TransactionEntriesCompanion.insert(
              id: 'e-$id',
              transactionId: id,
              accountId: 'card1',
              chartOfAccountCode: '',
              debitCents: 0,
              creditCents: cents,
              note: '',
            ),
          );
    }
    DateTime clock() => DateTime(2026, 9, 22, 10);

    // 源候选金额 与 共享推导 同数(对话框经组合根也取自该推导)。
    final sourceTotal = (await CreditCardDueSource(database, clock: clock)
            .unpaidDueCandidates())
        .single
        .totalCents;
    final computed = await CreditCardStatementDue.compute(
      db: database,
      accountId: 'card1',
      accountType: 2,
      currentBalanceCents: 500000,
      billingDay: 15,
      clock: clock,
    );
    expect(sourceTotal, 420000);
    expect(computed, sourceTotal); // 同 fixture 断言相等

    final repayments = <(int, String)>[];
    await _pump(
        tester,
        CreditCardRepayDialog(
          card: _card(debtCents: 500000),
          statementDueCents: computed,
          hasBillingDay: true,
          savingsAccounts: [_savings('rich', '富储蓄', 900000)],
          hasActiveInstallment: false,
          onRepay: (cents, from) async {
            repayments.add((cents, from));
            return true;
          },
          onInstallment: (p, n, r) async => true,
          onDismissCycle: () async {},
        ));
    await _submit(tester);
    expect(repayments, [(sourceTotal, 'rich')]); // 对话框全额 = 源候选金额
  });
}
