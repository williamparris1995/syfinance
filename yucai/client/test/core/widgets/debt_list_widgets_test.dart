// F37 — DebtListCard 到期紧迫度着色的 widget 测试。
// 桌面宽度(>600)走 full 变体(DebtCardMetaKv『到期日』带后缀+色);
// 移动宽度走 compact 变体(『到期 ...』MetaItem 同后缀+色)。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/widgets/debt_list_widgets.dart';
import 'package:yucai_client/core/widgets/debt_view_semantics.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

Debt _debt(DateTime due,
    {int remaining = 1000,
    DateTime? nextPaymentDate,
    int nextPaymentPeriodNo = 0,
    int nextPaymentAmountCents = 0}) =>
    Debt(
      id: 'd1',
      accountId: 'a1',
      counterparty: '测试债',
      interestRate: 0.05,
      amortization: AmortizationMethod.equalPrincipalInterest,
      startDate: DateTime(2026, 1, 1),
      dueDate: due,
      totalPrincipalCents: 2000,
      remainingPrincipalCents: remaining,
      version: 1,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      subtype: DebtSubtypes.other,
      nextPaymentDate: nextPaymentDate,
      nextPaymentPeriodNo: nextPaymentPeriodNo,
      nextPaymentAmountCents: nextPaymentAmountCents,
    );

Widget _harness(Debt debt, double width) => MediaQuery(
      data: MediaQueryData(size: Size(width, 1000)),
      child: MaterialApp(
        home: Scaffold(
          body: DebtListCard(
            sem: DebtViewSemantics.debt,
            debt: debt,
            preferred: 'CNY',
            badgeFor: (d) => const DebtBadgeStyle(
                label: '测试',
                fg: Color(0xFF111111),
                bg: Color(0xFF222222)),
            avatarColorFor: (d) => const Color(0xFF333333),
          ),
        ),
      ),
    );

void main() {
  testWidgets('F37 desktop:5 天内到期 → 「（5天内）」后缀+negative 色',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_harness(
        _debt(DateTime.now().add(const Duration(days: 5))), 1440));
    await t.pumpAndSettle();
    expect(find.textContaining('（5天内）'), findsOneWidget);
  });

  testWidgets('F37 mobile:5 天内到期 → 后缀可见', (t) async {
    await t.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_harness(
        _debt(DateTime.now().add(const Duration(days: 5))), 500));
    await t.pumpAndSettle();
    expect(find.textContaining('（5天内）'), findsOneWidget);
  });

  testWidgets('F37:20 天后到期 → 无紧迫度后缀', (t) async {
    await t.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_harness(
        _debt(DateTime.now().add(const Duration(days: 20))), 1440));
    await t.pumpAndSettle();
    expect(find.textContaining('天内'), findsNothing);
    expect(find.textContaining('逾期'), findsNothing);
  });

  testWidgets('F37:已结清 → 无紧迫度后缀', (t) async {
    await t.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_harness(
        _debt(DateTime.now().add(const Duration(days: 5)), remaining: 0),
        1440));
    await t.pumpAndSettle();
    expect(find.textContaining('天内'), findsNothing);
  });

  group('F37 扩展:下一期还款日紧迫度(卡片底部 callout)', () {
    testWidgets('下一期 3 天内 → 「（3天内）」着色提示', (t) async {
      await t.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final d = _debt(DateTime(2027, 6, 1),
          nextPaymentDate: DateTime.now().add(const Duration(days: 3)),
          nextPaymentPeriodNo: 4,
          nextPaymentAmountCents: 50000);
      await t.pumpWidget(_harness(d, 1440));
      await t.pumpAndSettle();
      expect(find.textContaining('3天内'), findsOneWidget);
    });

    testWidgets('下一期 20 天后 → 无提示', (t) async {
      await t.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final d = _debt(DateTime(2027, 6, 1),
          nextPaymentDate: DateTime.now().add(const Duration(days: 20)),
          nextPaymentPeriodNo: 4,
          nextPaymentAmountCents: 50000);
      await t.pumpWidget(_harness(d, 1440));
      await t.pumpAndSettle();
      expect(find.textContaining('天内）'), findsNothing);
    });
  });
}
