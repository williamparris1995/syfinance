// T8 C:「账单周期」面板 widget 测试 —— 四行值/强调色/降级态/副标注。
// 纯展示组件:breakdown 由页面经 CreditCardStatementDue.breakdown 算好注入,
// 此处直接构造值对象断言渲染(页面级集成见 account_detail_page_test)。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/account/presentation/widgets/credit_card_statement_panel.dart';
import 'package:yucai_client/core/notifications/credit_card_statement.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// 夹具:账单 3000、还 1000、再刷 500 → current 2500(250000 分)。
CreditCardStatementBreakdown _breakdown({
  int statement = 300000,
  int repaid = 100000,
  int cycleNew = 50000,
  int remaining = 200000,
}) =>
    CreditCardStatementBreakdown(
      billingDate: DateTime(2026, 9, 15),
      statementCents: statement,
      repaidSinceCents: repaid,
      cycleNewCents: cycleNew,
      remainingCents: remaining,
    );

Widget _harness(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('四行:上期账单/上期已还/上期剩余/本期账单(未出账)+ 金额千分位', (tester) async {
    await tester.pumpWidget(_harness(CreditCardStatementPanel(
      billingDay: 15,
      repaymentDay: 5,
      currencyCode: 'CNY',
      breakdown: _breakdown(),
    )));

    // 标题 + 副标注(取卡字段)。
    expect(find.text('账单周期'), findsOneWidget);
    expect(find.text('账单日 15日 · 还款日 5日'), findsOneWidget);
    // 四行 label。
    expect(find.text('上期账单'), findsOneWidget);
    expect(find.text('上期已还'), findsOneWidget);
    expect(find.text('上期剩余'), findsOneWidget);
    expect(find.text('本期账单(未出账)'), findsOneWidget);
    // 四行金额(千分位两位小数,同详情页 _fmtSigned 口径)。
    expect(find.text('¥3,000.00'), findsOneWidget);
    expect(find.text('¥1,000.00'), findsOneWidget);
    expect(find.text('¥2,000.00'), findsOneWidget);
    expect(find.text('¥500.00'), findsOneWidget);
  });

  testWidgets('强调断言:上期剩余金额 accent + 加粗(= 还款日应还,与催办同数)', (tester) async {
    await tester.pumpWidget(_harness(CreditCardStatementPanel(
      billingDay: 15,
      repaymentDay: 5,
      currencyCode: 'CNY',
      breakdown: _breakdown(),
    )));

    // 裸 MaterialApp → context.yucai 回落亮色令牌(= AppColors 系)。
    final remaining =
        tester.widget<Text>(find.text('¥2,000.00'));
    expect(remaining.style?.color, AppColors.accent,
        reason: '上期剩余 = 还款日应还,须强调色');
    expect(remaining.style?.fontWeight, FontWeight.w600);

    // 其余三行非强调:fg 常规。
    for (final data in ['¥3,000.00', '¥1,000.00', '¥500.00']) {
      final t = tester.widget<Text>(find.text(data));
      expect(t.style?.color, AppColors.fg, reason: '$data 应为常规 fg 色');
      expect(t.style?.fontWeight, isNot(FontWeight.w600));
    }
  });

  testWidgets('降级态:账单日未设 → 只渲染标题 + muted 提示,不渲染四行', (tester) async {
    await tester.pumpWidget(_harness(const CreditCardStatementPanel(
      billingDay: null,
      repaymentDay: null,
      currencyCode: 'CNY',
      breakdown: null,
    )));

    expect(find.text('账单周期'), findsOneWidget);
    final hint = tester.widget<Text>(find.text('设置账单日后可查看账单周期明细'));
    expect(hint.style?.color, AppColors.muted, reason: '降级提示为 muted');
    // 四行 label 与任何金额都不渲染。
    expect(find.text('上期账单'), findsNothing);
    expect(find.text('本期账单(未出账)'), findsNothing);
    expect(find.text('¥2,000.00'), findsNothing);
  });

  testWidgets('breakdown 未加载(null)→ 标题/副标注在,四行不渲染', (tester) async {
    await tester.pumpWidget(_harness(const CreditCardStatementPanel(
      billingDay: 15,
      repaymentDay: 5,
      currencyCode: 'CNY',
      breakdown: null,
    )));

    expect(find.text('账单周期'), findsOneWidget);
    expect(find.text('账单日 15日 · 还款日 5日'), findsOneWidget);
    expect(find.text('上期账单'), findsNothing);
    expect(find.text('上期剩余'), findsNothing);
  });

  testWidgets('还款日未设 → 副标注只显账单日段', (tester) async {
    await tester.pumpWidget(_harness(CreditCardStatementPanel(
      billingDay: 15,
      repaymentDay: null,
      currencyCode: 'CNY',
      breakdown: _breakdown(),
    )));

    expect(find.text('账单日 15日'), findsOneWidget);
    expect(find.textContaining('还款日'), findsNothing);
  });
}
