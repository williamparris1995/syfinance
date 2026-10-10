// TDD RED → GREEN:F50 卡贷额度占用纯函数(cardLoanOccupationCents)单测。
//
// F50 FR-1/FR-2(spec)/ADR-1/ADR-2(design):银行口径 —— 仅 Σ剩余本金
// (remainingPrincipalCents,期表口径),不含未还利息(unpaidInterestCents),
// 更不得用载体户余额;过滤三条件:subtype==card_loan ∧ 挂接该卡
// (collectionAccountId == cardId)∧ 债级开关开(countsTowardCardLimit)。
// 金额 fixtures 用 spec 平安真值校准数(单位 cents):
//   三笔挂接 215,368 / 454,032 / 425,807(开)+ 一笔 2,968,344(关)
//   → occupation 1,095,207;额度 5,000,000 − 卡欠款 31,963 − 占用
//   → 可用 3,872,830(= ¥38,728.30,spec FR 真值)。
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/debt/domain/debt_query.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

/// 卡贷/其他债 fixture(照 debt_query_helpers_test._d 范式)。
Debt _debt(
  String id,
  int remainingPrincipalCents, {
  String subtype = DebtSubtypes.cardLoan,
  String? cardId,
  bool countsTowardCardLimit = true,
}) =>
    Debt(
      id: id,
      accountId: 'loan-$id',
      counterparty: '银行$id',
      interestRate: 3,
      amortization: AmortizationMethod.equalPrincipalInterest,
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2027, 1, 1),
      totalPrincipalCents: remainingPrincipalCents,
      remainingPrincipalCents: remainingPrincipalCents,
      version: 1,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      subtype: subtype,
      collectionAccountId: cardId,
      countsTowardCardLimit: countsTowardCardLimit,
    );

void main() {
  group('cardLoanOccupationCents(F50 银行口径:仅剩余本金,期表口径)', () {
    test('平安真值:挂接三笔计入 + 开关关一笔排除;卡可用 == 3,872,830 cents',
        () {
      const pinganCard = 'pingan-card';
      final debts = [
        // 挂接平安卡的三笔卡贷(开关开):剩余本金校准数。
        _debt('e-zhi', 215368, cardId: pinganCard),
        _debt('wan-yong-jin', 454032, cardId: pinganCard),
        _debt('cai-zhi-tong', 425807, cardId: pinganCard),
        // 备用金类(开关关):挂接同卡但独立额度,不计入。
        _debt('bei-yong-jin', 2968344,
            cardId: pinganCard, countsTowardCardLimit: false),
      ];
      final occupation = cardLoanOccupationCents(debts, pinganCard);
      expect(occupation, 1095207); // 215,368+454,032+425,807

      // 组合断言卡可用(spec 真值 ¥38,728.30):
      // 额度 5,000,000 − 卡欠款 31,963 − 占用 1,095,207 == 3,872,830。
      const limitCents = 5000000;
      const cardUsedCents = 31963;
      expect(limitCents - cardUsedCents - occupation, 3872830);
    });

    test('e招贷零占用:collectionAccountId 为空(独立账单,不挂卡)', () {
      final debts = [
        _debt('e-dai', 2606286, cardId: null), // 2,606,286 cents e招贷
      ];
      expect(cardLoanOccupationCents(debts, 'cmb-card'), 0);
    });

    test('开关排除:同卡两债一开一关,只计开的', () {
      final debts = [
        _debt('on', 100000, cardId: 'x-card', countsTowardCardLimit: true),
        _debt('off', 200000, cardId: 'x-card', countsTowardCardLimit: false),
      ];
      expect(cardLoanOccupationCents(debts, 'x-card'), 100000);
    });

    test('subtype 过滤:同卡 cash_installment 债不计入', () {
      final debts = [
        _debt('card-loan', 50000, cardId: 'y-card'),
        _debt('cash-inst', 70000,
            subtype: DebtSubtypes.cashInstallment, cardId: 'y-card'),
      ];
      expect(cardLoanOccupationCents(debts, 'y-card'), 50000);
    });

    test('挂接他卡的债不计入(精确 cardId 匹配)', () {
      final debts = [
        _debt('other-card', 999999, cardId: 'other-card'),
      ];
      expect(cardLoanOccupationCents(debts, 'y-card'), 0);
    });

    test('空列表 → 0', () {
      expect(cardLoanOccupationCents(const [], 'any'), 0);
    });
  });

  group('Debt.countsTowardCardLimit(F50 债级开关字段)', () {
    test('构造缺省 true(既有调用点行为不变)', () {
      final d = _debt('default', 100);
      expect(d.countsTowardCardLimit, isTrue);
    });

    test('参与 equals(开关不同即不同实体)', () {
      final a = _debt('d9', 100, countsTowardCardLimit: true);
      final b = _debt('d9', 100, countsTowardCardLimit: false);
      expect(a, isNot(equals(b)));
    });
  });
}
