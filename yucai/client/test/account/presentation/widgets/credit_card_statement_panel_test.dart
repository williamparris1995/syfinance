// v5 原型拍板 B「应还拆解」面板测试(2026-09-23,替代 T8 四行版断言 ——
// 口径扩展所致:四数不变,呈现改应答块 + 构成条)。
// 纯展示组件:breakdown 由页面经 CreditCardStatementDue.breakdown 算好注入,
// 此处直接构造值对象断言渲染(页面级集成见 account_detail_page_test)。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/account/presentation/widgets/credit_card_statement_panel.dart';
import 'package:yucai_client/core/notifications/credit_card_statement.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// 夹具:账单 3000、还 1000、再刷 500 → current 2500(250000 分)。
/// (DateTime 无 const 构造,默认参数不可用非常量 → 可空 + 内联缺省。)
CreditCardStatementBreakdown _breakdown({
  DateTime? billingDate,
  int statement = 300000,
  int repaid = 100000,
  int cycleNew = 50000,
  int remaining = 200000,
}) =>
    CreditCardStatementBreakdown(
      billingDate: billingDate ?? DateTime(2026, 9, 15),
      statementCents: statement,
      repaidSinceCents: repaid,
      cycleNewCents: cycleNew,
      remainingCents: remaining,
    );

/// 固定时钟 2026-09-20(还款日 5 → 下一还款日 10/5,差 15 天)。
DateTime _clock() => DateTime(2026, 9, 20);

Widget _harness(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('应答块:还款日应还大字(accent)+ 还有 N 天 chip + 恢复等式推导',
      (tester) async {
    await tester.pumpWidget(_harness(CreditCardStatementPanel(
      billingDay: 15,
      repaymentDay: 5,
      currencyCode: 'CNY',
      breakdown: _breakdown(),
      clock: _clock,
    )));

    // 标题 + 副标注(取卡字段)。
    expect(find.text('账单周期'), findsOneWidget);
    expect(find.text('账单日 15日 · 还款日 5日'), findsOneWidget);
    // 应答块:标签 + chip(9/20 → 下一还款日 10/5,15 天)。
    expect(find.text('还款日 5日 · 应还'), findsOneWidget);
    expect(find.text('还有 15 天'), findsOneWidget);
    // 应还大字(千分位两位小数,= breakdown.remainingCents,与催办同数)。
    final big = tester.widget<Text>(find.byKey(const ValueKey('ccAnswerAmount')));
    expect(big.data, '¥2,000.00');
    // 裸 MaterialApp → context.yucai 回落亮色令牌(= AppColors 系)。
    expect(big.style?.color, AppColors.accent, reason: '应还 = 还款日应还,须强调色');
    expect(big.style?.fontWeight, FontWeight.w800);
    // 恢复等式推导:上期账单(出账日)− 上期已还(Text.rich 断言用
    // textContaining 匹配整段 plain text 的子串)。
    expect(find.textContaining('= 上期账单 ¥3,000.00'), findsOneWidget);
    expect(find.textContaining('¥3,000.00'), findsOneWidget);
    expect(find.textContaining('(9/15 出账) − 上期已还 ¥1,000.00'),
        findsOneWidget);
  });

  testWidgets('构成:当前欠款合计 + 比例条 + 双行图例(80%/20%,下期出账日)',
      (tester) async {
    await tester.pumpWidget(_harness(CreditCardStatementPanel(
      billingDay: 15,
      repaymentDay: 5,
      currencyCode: 'CNY',
      breakdown: _breakdown(),
      clock: _clock,
    )));

    // 构成区标题 + 合计(remaining + cycleNew = 2500,未钳零时 = 当前欠款)。
    expect(find.text('当前欠款构成'), findsOneWidget);
    expect(find.text('¥2,500.00'), findsOneWidget);
    // 比例条存在。
    expect(find.byKey(const ValueKey('ccCompBar')), findsOneWidget);
    // 图例:上期剩余 80% / 本期账单 20%,下期出账日 = D+1 月(10/15)。
    expect(find.textContaining('上期剩余(应还) ¥2,000.00'), findsOneWidget);
    expect(find.textContaining(' · 80%'), findsOneWidget);
    expect(find.textContaining('本期账单(未出账) ¥500.00'), findsOneWidget);
    expect(find.textContaining('10/15 出账 · 20%'), findsOneWidget);
  });

  testWidgets('钳零:上期剩余 0(全为本期)→ 应还 ¥0.00,构成 0%/100%',
      (tester) async {
    await tester.pumpWidget(_harness(CreditCardStatementPanel(
      billingDay: 15,
      repaymentDay: 5,
      currencyCode: 'CNY',
      breakdown: _breakdown(
        statement: 0,
        repaid: 0,
        cycleNew: 50000,
        remaining: 0,
      ),
      clock: _clock,
    )));

    expect(tester.widget<Text>(find.byKey(const ValueKey('ccAnswerAmount'))).data,
        '¥0.00');
    expect(find.textContaining(' · 0%'), findsOneWidget);
    expect(find.textContaining('10/15 出账 · 100%'), findsOneWidget);
  });

  testWidgets('降级态:账单日未设 → 提示行 + 「去设置」回调;不渲染应答块',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(_harness(CreditCardStatementPanel(
      billingDay: null,
      repaymentDay: null,
      currencyCode: 'CNY',
      breakdown: null,
      onSetupBilling: () => tapped = true,
    )));

    expect(find.text('账单周期'), findsOneWidget);
    final hint = tester.widget<Text>(find.text('设置账单日后可查看账单周期明细'));
    expect(hint.style?.color, AppColors.muted, reason: '降级提示为 muted');
    expect(find.text('去设置'), findsOneWidget);
    await tester.tap(find.text('去设置'));
    expect(tapped, isTrue);
    // 应答块不渲染。
    expect(find.byKey(const ValueKey('ccAnswerAmount')), findsNothing);
    expect(find.text('当前欠款构成'), findsNothing);
  });

  testWidgets('降级态:onSetupBilling 缺省 → 无「去设置」按钮', (tester) async {
    await tester.pumpWidget(_harness(const CreditCardStatementPanel(
      billingDay: null,
      repaymentDay: null,
      currencyCode: 'CNY',
      breakdown: null,
    )));
    expect(find.text('设置账单日后可查看账单周期明细'), findsOneWidget);
    expect(find.text('去设置'), findsNothing);
  });

  testWidgets('breakdown 未加载(null)→ 标题/副标注在,应答块不渲染',
      (tester) async {
    await tester.pumpWidget(_harness(const CreditCardStatementPanel(
      billingDay: 15,
      repaymentDay: 5,
      currencyCode: 'CNY',
      breakdown: null,
    )));

    expect(find.text('账单周期'), findsOneWidget);
    expect(find.text('账单日 15日 · 还款日 5日'), findsOneWidget);
    expect(find.byKey(const ValueKey('ccAnswerAmount')), findsNothing);
    expect(find.text('当前欠款构成'), findsNothing);
  });

  testWidgets('还款日未设 → 标签退「应还」,无天数 chip,副标注只显账单日段',
      (tester) async {
    await tester.pumpWidget(_harness(CreditCardStatementPanel(
      billingDay: 15,
      repaymentDay: null,
      currencyCode: 'CNY',
      breakdown: _breakdown(),
      clock: _clock,
    )));

    expect(find.text('账单日 15日'), findsOneWidget);
    expect(find.textContaining('还款日'), findsNothing);
    expect(find.text('应还'), findsOneWidget);
    expect(find.textContaining('还有'), findsNothing);
  });

  testWidgets('chip 边界:还款日就在今天 → 「今天」', (tester) async {
    await tester.pumpWidget(_harness(CreditCardStatementPanel(
      billingDay: 15,
      repaymentDay: 20,
      currencyCode: 'CNY',
      breakdown: _breakdown(),
      clock: _clock, // 2026-09-20
    )));

    expect(find.text('今天'), findsOneWidget);
  });
}
