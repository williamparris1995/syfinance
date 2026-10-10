// TDD RED → GREEN:F51 loan 派生四值纯函数(derivedLoanFields + 下一未还期
// 投影 debtNextPeriod/DebtNextPeriod)单测。
//
// F51 FR-1(spec)/ADR-1、U1、U2(design):「loan·invest 双重表示规则化」
// —— 账户侧 loan 双重表示与债务域共用同一套派生口径,规则落 domain 纯函数
// (照 F50 cardLoanOccupationCents 在 debt_query.dart 的先例):
//   totalPrincipalCents    = Σ debt.totalPrincipalCents;
//   remainingPrincipalCents = Σ debt.remainingPrincipalCents;
//   nextPaymentCents  = Σ 各债下一未还期 total(无期表债计 0;全无 → null);
//   nextPaymentDate   = min 各债下一未还期日(全无 → null)。
// 下一未还期定义 = payment_schedule paid=false 中 payment_date 最早
// (含逾期未付 —— 过去日期仍是下期;与 DebtLocalDataSource._toEntity 的
// 既有 next 口径同源,不造第二套)。
// 金额 fixtures 用 spec 校准数(单位 cents):两债总额 3,500,000 + 910,000
// → 4,410,000;剩余 2,968,344 + 454,032 → 3,422,376;下期 163,046@
// 2026-10-12 与 44,744@2026-10-25 → Σ 207,790 / min 2026-10-12。
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/debt/domain/debt_query.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

/// 债 fixture(照 card_loan_occupation_test._debt 范式,只留本测所需字段)。
Debt _debt(String id, int totalPrincipalCents, int remainingPrincipalCents) =>
    Debt(
      id: id,
      accountId: 'loan-$id',
      counterparty: '银行$id',
      interestRate: 3,
      amortization: AmortizationMethod.equalPrincipalInterest,
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2027, 1, 1),
      totalPrincipalCents: totalPrincipalCents,
      remainingPrincipalCents: remainingPrincipalCents,
      version: 1,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

/// 期表行 fixture(paid 期已还;未还期 principal/interest 拆分不影响本测)。
PaymentEntry _entry(
  String id,
  DateTime paymentDate,
  int totalCents, {
  required bool paid,
}) =>
    PaymentEntry(
      id: id,
      paymentDate: paymentDate,
      principalCents: 0,
      interestCents: 0,
      totalCents: totalCents,
      paid: paid,
      paidCents: paid ? totalCents : 0,
      transactionId: '',
    );

void main() {
  group('derivedLoanFields(F51 loan 四值聚合)', () {
    test('两债聚合 spec 真值:{4,410,000; 3,422,376; 207,790; 2026-10-12}', () {
      final debts = [
        _debt('wan-yong-jin', 3500000, 2968344),
        _debt('e-zhi', 910000, 454032),
      ];
      final nextByDebtId = {
        'wan-yong-jin': DebtNextPeriod(
            totalCents: 163046, date: DateTime(2026, 10, 12)),
        'e-zhi': DebtNextPeriod(
            totalCents: 44744, date: DateTime(2026, 10, 25)),
      };
      final r = derivedLoanFields(debts, nextByDebtId);
      expect(r.totalPrincipalCents, 4410000); // 3,500,000 + 910,000
      expect(r.remainingPrincipalCents, 3422376); // 2,968,344 + 454,032
      expect(r.nextPaymentCents, 207790); // 163,046 + 44,744
      expect(r.nextPaymentDate, DateTime(2026, 10, 12)); // min(10-12, 10-25)
    });

    test('一债无期表投影 → 该债月供计 0、下期日不参与(另一债照常计入)', () {
      final debts = [
        _debt('with-schedule', 3500000, 2968344),
        _debt('no-schedule', 910000, 454032), // 剩余>0 但无期表投影
      ];
      final nextByDebtId = {
        'with-schedule': DebtNextPeriod(
            totalCents: 163046, date: DateTime(2026, 10, 12)),
      };
      final r = derivedLoanFields(debts, nextByDebtId);
      // 无期表债计 0:nextPaymentCents 只含有投影的 163,046。
      expect(r.nextPaymentCents, 163046);
      expect(r.nextPaymentDate, DateTime(2026, 10, 12));
      // 债头两值不受投影有无影响,仍为全量和。
      expect(r.totalPrincipalCents, 4410000);
      expect(r.remainingPrincipalCents, 3422376);
    });

    test('两债全付清(投影空)→ nextPaymentCents == null 且下期日 == null', () {
      final debts = [
        _debt('paid-1', 3500000, 0),
        _debt('paid-2', 910000, 0),
      ];
      final r = derivedLoanFields(debts, const {});
      expect(r.nextPaymentCents, isNull);
      expect(r.nextPaymentDate, isNull);
      // 债头两值照常聚合(全付清 → remaining 0)。
      expect(r.totalPrincipalCents, 4410000);
      expect(r.remainingPrincipalCents, 0);
    });

    test('逾期期计入:下一未还期日期在过去仍作为下期(不按 now 过滤)', () {
      final debts = [_debt('overdue', 910000, 454032)];
      final nextByDebtId = {
        'overdue': DebtNextPeriod(
            totalCents: 44744, date: DateTime(2026, 9, 1)), // 已过去的期
      };
      final r = derivedLoanFields(debts, nextByDebtId);
      expect(r.nextPaymentCents, 44744);
      expect(r.nextPaymentDate, DateTime(2026, 9, 1));
    });

    test('空列表 → 全 0/null 空视图(不抛)', () {
      final r = derivedLoanFields(const [], const {});
      expect(r.totalPrincipalCents, 0);
      expect(r.remainingPrincipalCents, 0);
      expect(r.nextPaymentCents, isNull);
      expect(r.nextPaymentDate, isNull);
    });

    test('投影 map 含不在 debts 列表的 key → 不计入(以 debts 驱动)', () {
      final debts = [_debt('a', 100000, 50000)];
      final r = derivedLoanFields(debts, {
        'a': DebtNextPeriod(totalCents: 1000, date: DateTime(2026, 10, 12)),
        'ghost': DebtNextPeriod(totalCents: 999999, date: DateTime(2026, 1, 1)),
      });
      expect(r.nextPaymentCents, 1000); // ghost 的 999999 不入和
      expect(r.nextPaymentDate, DateTime(2026, 10, 12)); // ghost 的更早日不参与
    });
  });

  group('debtNextPeriod(下一未还期投影:paid=false 最早,含逾期)', () {
    test('多未还期取最早(乱序注入)', () {
      final schedule = [
        _entry('p3', DateTime(2026, 12, 25), 300000, paid: false),
        _entry('p1', DateTime(2026, 10, 12), 163046, paid: false),
        _entry('p2', DateTime(2026, 11, 12), 162000, paid: false),
      ];
      final next = debtNextPeriod(schedule)!;
      expect(next.totalCents, 163046);
      expect(next.date, DateTime(2026, 10, 12));
    });

    test('已还期跳过:最早的 paid 期不算,取最早未还期', () {
      final schedule = [
        _entry('p1', DateTime(2026, 9, 12), 160000, paid: true),
        _entry('p2', DateTime(2026, 10, 12), 163046, paid: false),
        _entry('p3', DateTime(2026, 11, 12), 162000, paid: false),
      ];
      final next = debtNextPeriod(schedule)!;
      expect(next.totalCents, 163046);
      expect(next.date, DateTime(2026, 10, 12));
    });

    test('逾期未付仍算下期:过去日期的未还期被选中', () {
      final schedule = [
        _entry('overdue', DateTime(2026, 9, 1), 44744, paid: false),
        _entry('future', DateTime(2026, 10, 25), 44000, paid: false),
      ];
      final next = debtNextPeriod(schedule)!;
      expect(next.date, DateTime(2026, 9, 1)); // 过去日期仍是下期
      expect(next.totalCents, 44744);
    });

    test('全付清 → null;空期表 → null', () {
      expect(
          debtNextPeriod([
            _entry('p1', DateTime(2026, 9, 12), 160000, paid: true),
          ]),
          isNull);
      expect(debtNextPeriod(const []), isNull);
    });
  });
}
