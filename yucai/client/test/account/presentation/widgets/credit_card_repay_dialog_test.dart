// CreditCardRepayDialog widget 测试:三方式交互 + 储蓄卡余额不足拦截 +
// 最低/分期后自动挂失本期催办。对话框纯回调,无需 DI。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/widgets/credit_card_repay_dialog.dart';
import 'package:yucai_client/core/theme/app_theme.dart';

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
  testWidgets('全额:余额不足禁用提交并提示,足额后提交回调正确金额与账户',
      (tester) async {
    final repayments = <(int, String)>[];
    var dismissed = 0;
    await _pump(
        tester,
        CreditCardRepayDialog(
          card: _card(debtCents: 500000),
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

  testWidgets('最低:预填 10%,提交后还款并挂失本期', (tester) async {
    final repayments = <(int, String)>[];
    var dismissed = 0;
    await _pump(
        tester,
        CreditCardRepayDialog(
          card: _card(debtCents: 500000),
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

  testWidgets('分期:利率必填,提交建分期债并挂失;已挂账时分段禁用', (tester) async {
    final installments = <(int, int, double)>[];
    var dismissed = 0;

    Widget dialog({required bool hasInstallment}) => CreditCardRepayDialog(
          card: _card(debtCents: 500000),
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
}
