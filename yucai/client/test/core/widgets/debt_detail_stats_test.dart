// F61 评审 fixlist-3:buildDebtDetailStats 逾期口径账单感知钉测
// (card_loan 自由窗口不进逾期卡;普通债自身日期口径)。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/widgets/debt_detail_widgets.dart';
import 'package:yucai_client/core/widgets/debt_view_semantics.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

PaymentEntry _e(String id, DateTime d, {bool paid = false}) => PaymentEntry(
    id: id,
    paymentDate: d,
    principalCents: 100000,
    interestCents: 1000,
    totalCents: 101000,
    paid: paid,
    paidCents: 0,
    transactionId: '');

Debt _debt(String subtype) => Debt(
    id: 'd1',
    accountId: 'a1',
    counterparty: '平安银行',
    interestRate: 0.05,
    amortization: AmortizationMethod.equalPrincipalInterest,
    startDate: DateTime(2026, 1, 1),
    dueDate: DateTime(2028, 1, 1),
    totalPrincipalCents: 300000,
    remainingPrincipalCents: 200000,
    version: 1,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    subtype: subtype);

void main() {
  testWidgets('card_loan 自由窗口:出账过、到期未到 → 逾期卡显「无逾期」',
      (t) async {
    // 相对今天构造自由窗口:期0=30 天前已出账,期1(=期0 到期)=+7 天未到。
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 30));
    final d1 = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 7));
    final d2 = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 37));
    final detail = DebtDetail(
      debt: _debt(DebtSubtypes.cardLoan),
      schedule: [_e('a', d0), _e('b', d1), _e('c', d2)],
    );
    late List<DebtStatCardData> stats;
    await t.pumpWidget(MaterialApp(
      builder: (context, _) {
        stats = buildDebtDetailStats(
            context, detail, 'CNY', DebtViewSemantics.debt);
        return const SizedBox();
      },
    ));
    final overdue = stats.firstWhere((s) => s.sub.contains('逾期') || s.sub == '无逾期');
    expect(overdue.sub, '无逾期',
        reason: '自由窗口(09-12 已出账但到期=10-12 未到)不进逾期卡');
  });

  testWidgets('普通债:期次日已过 → 逾期卡计数(口径不变)', (t) async {
    final now = DateTime.now();
    final detail = DebtDetail(
      debt: _debt(DebtSubtypes.other),
      schedule: [
        _e('n', DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 15))),
        _e('m', DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 15))),
      ],
    );
    late List<DebtStatCardData> stats;
    await t.pumpWidget(MaterialApp(
      builder: (context, _) {
        stats = buildDebtDetailStats(
            context, detail, 'CNY', DebtViewSemantics.debt);
        return const SizedBox();
      },
    ));
    final overdue = stats.firstWhere((s) => s.sub.contains('逾期'));
    expect(overdue.sub.contains('1 期'), isTrue,
        reason: '普通债 10-01 已过自身期次日 → 逾期 1 期');
  });
}
