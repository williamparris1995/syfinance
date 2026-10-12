// TDD RED → GREEN:F50 卡贷额度占用纯函数(cardLoanOccupationCents)单测;
// F58 改未出账口径(2026-10-12):只计 unpaid 且 paymentDate > now 的期次
// 本金 —— 银行「分期剩余」不含已出账期次(已出账未到期 = 自由窗口,已
// 到期者经卡待还计入),故期表级收窄,不再用整债 remainingPrincipalCents。
//
// 过滤三条件不变:subtype==card_loan ∧ 挂接该卡(collectionAccountId ==
// cardId)∧ 债级开关开(countsTowardCardLimit)。金额 fixtures 用 spec 平安
// 真值校准数(单位 cents):
//   三笔挂接 215,368 / 454,032 / 425,807(开)+ 一笔 2,968,344(关)
//   → occupation 1,095,207;额度 5,000,000 − 卡欠款 31,963 − 占用
//   → 可用 3,872,830(= ¥38,728.30,spec FR 真值)。
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/debt/domain/debt_query.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

/// 测试注入的「当前时刻」锚(期表日期均 UTC 绝对日期,口径钉死不随真实
/// 时钟漂移)。
final DateTime nowAnchor = DateTime.utc(2026, 6, 1);

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

/// 期次 fixture:id、出账日、本金;paid 缺省 false。
PaymentEntry _entry(
  String id,
  DateTime paymentDate,
  int principalCents, {
  bool paid = false,
}) =>
    PaymentEntry(
      id: id,
      paymentDate: paymentDate,
      principalCents: principalCents,
      interestCents: 0,
      totalCents: principalCents,
      paid: paid,
      paidCents: paid ? principalCents : 0,
      transactionId: '',
    );

/// 「整债剩余全部未出账」的期表(单条未来 unpaid 期次,principal = 剩余):
/// F50 校准数在新口径下的等价形态。
Map<String, List<PaymentEntry>> _allUnbilled(List<Debt> debts) => {
      for (final d in debts)
        d.id: [_entry('${d.id}-e0', DateTime.utc(2026, 12, 1),
            d.remainingPrincipalCents)],
    };

void main() {
  group('cardLoanOccupationCents(F58 未出账口径:unpaid 且 paymentDate > now)', () {
    test('平安真值:挂接三笔计入 + 开关关一笔排除;卡可用 == 3,872,830 cents',
        () {
      const pinganCard = 'pingan-card';
      final debts = [
        // 挂接平安卡的三笔卡贷(开关开):剩余本金校准数(全未出账)。
        _debt('e-zhi', 215368, cardId: pinganCard),
        _debt('wan-yong-jin', 454032, cardId: pinganCard),
        _debt('cai-zhi-tong', 425807, cardId: pinganCard),
        // 备用金类(开关关):挂接同卡但独立额度,不计入。
        _debt('bei-yong-jin', 2968344,
            cardId: pinganCard, countsTowardCardLimit: false),
      ];
      final occupation = cardLoanOccupationCents(
          debts, pinganCard, _allUnbilled(debts),
          now: nowAnchor);
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
      expect(
          cardLoanOccupationCents(
              debts, 'cmb-card', _allUnbilled(debts),
              now: nowAnchor),
          0);
    });

    test('广发挂接对照组:广发卡两笔计入,平安挂接债不计入广发', () {
      const gdbCard = 'gdb-card';
      final debts = [
        // 广发卡挂接两笔卡贷(开关开,真库形态数字)。
        _debt('gf-cash-inst', 2653182, cardId: gdbCard),
        _debt('gf-card-loan', 1000000, cardId: gdbCard),
        // 平安挂接债:计入平安侧,不计入广发(精确 cardId 对照)。
        _debt('pa-hold', 215368, cardId: 'pingan-card'),
      ];
      // 2,653,182 + 1,000,000 == 3,653,182(平安债不入和)。
      expect(
          cardLoanOccupationCents(
              debts, gdbCard, _allUnbilled(debts),
              now: nowAnchor),
          3653182);
    });

    test('开关排除:同卡两债一开一关,只计开的', () {
      final debts = [
        _debt('on', 100000, cardId: 'x-card', countsTowardCardLimit: true),
        _debt('off', 200000, cardId: 'x-card', countsTowardCardLimit: false),
      ];
      expect(
          cardLoanOccupationCents(
              debts, 'x-card', _allUnbilled(debts),
              now: nowAnchor),
          100000);
    });

    test('subtype 过滤:同卡 cash_installment 债不计入', () {
      final debts = [
        _debt('card-loan', 50000, cardId: 'y-card'),
        _debt('cash-inst', 70000,
            subtype: DebtSubtypes.cashInstallment, cardId: 'y-card'),
      ];
      expect(
          cardLoanOccupationCents(
              debts, 'y-card', _allUnbilled(debts),
              now: nowAnchor),
          50000);
    });

    test('挂接他卡的债不计入(精确 cardId 匹配)', () {
      final debts = [
        _debt('other-card', 999999, cardId: 'other-card'),
      ];
      expect(
          cardLoanOccupationCents(
              debts, 'y-card', _allUnbilled(debts),
              now: nowAnchor),
          0);
    });

    test('空列表 → 0;期表缺项 → 0(调用方须为挂卡卡贷供期表)', () {
      expect(
          cardLoanOccupationCents(const [], 'any', const {}, now: nowAnchor),
          0);
      final debts = [_debt('missing', 123456, cardId: 'z-card')];
      expect(
          cardLoanOccupationCents(debts, 'z-card', const {}, now: nowAnchor),
          0,
          reason: '缺期表按无未出账期次计 0,不回退整债剩余');
    });

    test('F58 口径①:出账日当天不计(已出账),次日及以后出账才计', () {
      final debts = [_debt('d', 999999, cardId: 'c')];
      final schedules = {
        'd': [
          _entry('e0', DateTime.utc(2026, 6, 1), 400000), // 出账日 = 今日 → 不计
          _entry('e1', DateTime.utc(2026, 6, 2), 300000), // 次日出账 → 计
          _entry('e2', DateTime.utc(2026, 7, 1), 200000), // 未来出账 → 计
        ],
      };
      expect(
          cardLoanOccupationCents(debts, 'c', schedules, now: nowAnchor),
          500000,
          reason: '仅未来出账的未还期次本金计入(300,000+200,000)');
    });

    test('F58 口径②:已出账未还(自由窗口)与已还期次均不计入', () {
      final debts = [_debt('d', 999999, cardId: 'c')];
      final schedules = {
        'd': [
          _entry('e0', DateTime.utc(2026, 5, 1), 400000,
              paid: true), // 已出账已还(并入)→ 不计
          _entry('e1', DateTime.utc(2026, 5, 1), 350000), // 已出账未还(自由窗口)→ 不计
          _entry('e2', DateTime.utc(2026, 6, 1), 250000), // 今日出账 → 不计
          _entry('e3', DateTime.utc(2026, 9, 1), 150000), // 未出账 → 计
        ],
      };
      expect(
          cardLoanOccupationCents(debts, 'c', schedules, now: nowAnchor),
          150000,
          reason: '银行分期剩余不含已出账期次;已到期者经卡待还计入');
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
