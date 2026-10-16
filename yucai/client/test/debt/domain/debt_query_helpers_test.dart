// TDD RED → GREEN:F9-T3 债务查询助手(搜索匹配 + 四态排序)纯函数单测。
//
// F9 FR-4 / ADR-3:债务/债权列表的搜索(counterparty contains)与排序
// (总金额/到期日 × 升降)以**纯 domain 函数**落地(debt/domain/debt_query.dart),
// DS 层与两页(债务/债权)共用同一实现 —— 复用第一,避免 DS/页面两套口径漂移。
// 纯函数不依赖 Flutter/drift,直接单测。
//
// 默认序不变式(NFR-2):(dueDate, asc) == 既有 debtCompareList(未结清在前 +
// 到期升序)逐位一致 —— 列表页初始态即现状序。
//
// F49-T5(FR-4a)追加:cardInstallmentSummary 纯函数组 —— 挂接信用卡的
// 并入型分期摘要(卡面徽标/F50 额度占用同源单实现)。
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/debt/domain/debt_query.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

Debt _d(
  String id,
  String counterparty,
  DateTime dueDate,
  int totalPrincipalCents, {
  int remainingPrincipalCents = -1, // -1 = 未结清默认(= total)
}) =>
    Debt(
      id: id,
      accountId: 'a-$id',
      counterparty: counterparty,
      interestRate: 3,
      amortization: AmortizationMethod.equalPrincipalInterest,
      startDate: DateTime(2026, 1, 1),
      dueDate: dueDate,
      totalPrincipalCents: totalPrincipalCents,
      remainingPrincipalCents: remainingPrincipalCents == -1
          ? totalPrincipalCents
          : remainingPrincipalCents,
      version: 1,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('F61 paymentEntryStatusMap(账单口径逾期)', () {
    PaymentEntry pe(String id, DateTime d, {bool paid = false}) =>
        PaymentEntry(
          id: id,
          paymentDate: d,
          principalCents: 100000,
          interestCents: 1000,
          totalCents: 101000,
          paid: paid,
          paidCents: 0,
          transactionId: '',
        );

    test('card_loan 自由窗口不红:出账后到下期出账前 = pending', () {
      final sched = [
        pe('a', DateTime(2026, 9, 12)),
        pe('b', DateTime(2026, 10, 12)),
        pe('c', DateTime(2026, 11, 12)),
      ];
      final st = paymentEntryStatusMap(sched,
          cardLoanBilling: true, now: DateTime(2026, 10, 5));
      expect(st['a'], PaymentStatus.pending,
          reason: '09-12 已出账但到期=10-12 未到 → 自由窗口不红(F58)');
      final st2 = paymentEntryStatusMap(sched,
          cardLoanBilling: true, now: DateTime(2026, 10, 14));
      expect(st2['a'], PaymentStatus.overdue, reason: '过下期出账日 → 逾期');
      expect(st2['b'], PaymentStatus.pending);
    });

    test('card_loan 末期到期=自身+1 月(月钳)', () {
      final st = paymentEntryStatusMap([pe('x', DateTime(2026, 1, 31))],
          cardLoanBilling: true, now: DateTime(2026, 3, 1));
      expect(st['x'], PaymentStatus.overdue, reason: '末期 1-31 到期=2-28');
    });

    test('普通债口径不变:自身 paymentDate 判逾期', () {
      final sched = [pe('n', DateTime(2026, 10, 1)), pe('m', DateTime(2026, 11, 1))];
      final st = paymentEntryStatusMap(sched, now: DateTime(2026, 10, 14));
      expect(st['n'], PaymentStatus.overdue);
      expect(st['m'], PaymentStatus.pending);
    });

    test('已还恒为 paid', () {
      final st = paymentEntryStatusMap([pe('p', DateTime(2026, 9, 1), paid: true)],
          cardLoanBilling: true, now: DateTime(2026, 12, 1));
      expect(st['p'], PaymentStatus.paid);
    });
  });

  // 夹具:金额与到期日均乱序注入,已结清(settled)沉底一支验证默认序分组。
  final debts = [
    _d('mid', '招商银行', DateTime(2027, 6, 1), 1500000),
    _d('big', 'Zhang San', DateTime(2028, 1, 1), 9000000),
    _d('small', '亲友借款', DateTime(2026, 9, 1), 200000),
    _d('settled-early', '已结清但到期早', DateTime(2025, 1, 1), 5000000,
        remainingPrincipalCents: 0),
  ];

  group('debtSearchMatches(counterparty contains 忽略大小写)', () {
    test('中文名片段命中', () {
      expect(debtSearchMatches(debts[0], '招商'), isTrue);
      expect(debtSearchMatches(debts[0], '银行'), isTrue);
    });

    test('英文名忽略大小写命中', () {
      expect(debtSearchMatches(debts[1], 'zhang'), isTrue);
      expect(debtSearchMatches(debts[1], 'SAN'), isTrue);
    });

    test('未命中 / 空白 / null(不过滤)', () {
      expect(debtSearchMatches(debts[0], 'zhang'), isFalse);
      expect(debtSearchMatches(debts[0], '  '), isTrue);
      expect(debtSearchMatches(debts[0], ''), isTrue);
      expect(debtSearchMatches(debts[0], null), isTrue);
    });
  });

  group('debtCompareQuery 四态排序', () {
    test('金额降序:按 totalPrincipalCents 大→小', () {
      final sorted = [...debts]
        ..sort((a, b) =>
            debtCompareQuery(a, b, DebtSortKey.amount, DebtSortDir.desc));
      expect(sorted.map((d) => d.id).toList(),
          ['big', 'settled-early', 'mid', 'small']);
    });

    test('金额升序:按 totalPrincipalCents 小→大', () {
      final sorted = [...debts]
        ..sort((a, b) =>
            debtCompareQuery(a, b, DebtSortKey.amount, DebtSortDir.asc));
      expect(sorted.map((d) => d.id).toList(),
          ['small', 'mid', 'settled-early', 'big']);
    });

    test('到期日降序:dueDate 晚→早(不受结清分组影响)', () {
      final sorted = [...debts]
        ..sort((a, b) =>
            debtCompareQuery(a, b, DebtSortKey.dueDate, DebtSortDir.desc));
      expect(sorted.map((d) => d.id).toList(),
          ['big', 'mid', 'small', 'settled-early']);
    });

    test('到期日升序(默认态):与既有 debtCompareList 逐位一致(NFR-2)', () {
      final byQuery = [...debts]
        ..sort((a, b) =>
            debtCompareQuery(a, b, DebtSortKey.dueDate, DebtSortDir.asc));
      final byLegacy = [...debts]..sort(debtCompareList);
      expect(byQuery.map((d) => d.id).toList(),
          byLegacy.map((d) => d.id).toList());
      // 现状语义:未结清在前(settled-early 到期最早但沉底)。
      expect(byQuery.map((d) => d.id).toList(),
          ['small', 'mid', 'big', 'settled-early']);
    });

    test('同键 tie-break 落回默认序(未结清在前),确定性', () {
      // 两支同金额:未结清在前。
      final pair = [
        _d('settled', 'A', DateTime(2027, 1, 1), 100,
            remainingPrincipalCents: 0),
        _d('active', 'B', DateTime(2027, 1, 1), 100),
      ];
      final sorted = pair
        ..sort((a, b) =>
            debtCompareQuery(a, b, DebtSortKey.amount, DebtSortDir.desc));
      expect(sorted.map((d) => d.id).toList(), ['active', 'settled']);
    });
  });

  group('F37 到期紧迫度', () {
    final today = DateTime(2026, 9, 19, 14, 30); // 带时刻,验证按日归零
    Debt due(String id, DateTime dueDate, {int remaining = 100}) =>
        _d(id, '债务$id', dueDate, 1000, remainingPrincipalCents: remaining);

    test('已结清 → none', () {
      expect(debtDueUrgency(due('x', DateTime(2026, 1, 1), remaining: 0), today),
          DebtDueUrgency.none);
    });
    test('昨日到期 → overdue', () {
      expect(debtDueUrgency(due('x', DateTime(2026, 9, 18)), today),
          DebtDueUrgency.overdue);
    });
    test('当天/7 天内 → within7', () {
      expect(debtDueUrgency(due('x', DateTime(2026, 9, 19)), today),
          DebtDueUrgency.within7);
      expect(debtDueUrgency(due('x', DateTime(2026, 9, 26)), today),
          DebtDueUrgency.within7);
    });
    test('8..15 天 → within15', () {
      expect(debtDueUrgency(due('x', DateTime(2026, 9, 27)), today),
          DebtDueUrgency.within15);
      expect(debtDueUrgency(due('x', DateTime(2026, 10, 4)), today),
          DebtDueUrgency.within15);
    });
    test('16 天以上 → none', () {
      expect(debtDueUrgency(due('x', DateTime(2026, 10, 5)), today),
          DebtDueUrgency.none);
    });
    test('默认序:最近到期未结清置顶,已结清沉底', () {
      final list = [
        _d('far', '远期', DateTime(2027, 1, 1), 100),
        _d('settled', '已结清', DateTime(2026, 1, 1), 100,
            remainingPrincipalCents: 0),
        _d('soon', '最近到期', DateTime(2026, 9, 25), 100),
      ]..sort(debtCompareList);
      expect(list.first.id, 'soon');
      expect(list[1].id, 'far');
      expect(list.last.id, 'settled');
    });
  });

  group('F49 cardInstallmentSummary(卡面分期徽标数据源;F58 未出账口径)', () {
    /// 测试注入「当前时刻」锚(期表日期 UTC 绝对日期,口径钉死)。
    final nowAnchor = DateTime.utc(2026, 6, 1);

    /// card_loan 借入债夹具:默认挂接卡 card-1、未结清(剩余=总额)。
    Debt cardDebt(
      String id,
      int total, {
      String? cardId = 'card-1',
      int? remaining,
      String subtype = DebtSubtypes.cardLoan,
      String? accountId,
      DebtType type = DebtType.borrowedIn,
    }) =>
        Debt(
          id: id,
          accountId: accountId ?? 'a-$id',
          counterparty: '债权方$id',
          interestRate: 0.6,
          amortization: AmortizationMethod.equalPrincipalInterest,
          startDate: DateTime(2026, 8, 10),
          dueDate: DateTime(2027, 8, 10),
          totalPrincipalCents: total,
          remainingPrincipalCents: remaining ?? total,
          version: 1,
          createdAt: DateTime(2026, 8, 10),
          updatedAt: DateTime(2026, 8, 10),
          type: type,
          subtype: subtype,
          collectionAccountId: cardId,
        );

    /// 未出账期次(单条未来 unpaid,principal = [principal])。
    List<PaymentEntry> unbilled(int principal) => [
          PaymentEntry(
            id: 'e-$principal',
            paymentDate: DateTime.utc(2026, 12, 1),
            principalCents: principal,
            interestCents: 0,
            totalCents: principal,
            paid: false,
            paidCents: 0,
            transactionId: '',
          ),
        ];

    test('挂接归集:仅 card_loan 且 collectionAccountId==cardId 计入', () {
      final debts = [
        cardDebt('hit', 840000), // 命中:挂接本卡
        cardDebt('other-card', 100000, cardId: 'card-2'), // 挂接他卡 → 不计
        cardDebt('indep', 100000, cardId: null), // 独立账单(无挂接)→ 不计
        cardDebt('mortgage', 100000,
            cardId: 'card-1',
            subtype: 'mortgage'), // 非 card_loan → 不计
        cardDebt('lendout', 100000,
            cardId: 'card-1',
            type: DebtType.borrowedOut), // 借出方向 → 不计
      ];
      final schedules = {'hit': unbilled(840000)};
      final s = cardInstallmentSummary(debts, 'card-1', schedules,
          now: nowAnchor);
      expect(s.count, 1);
      expect(s.remainingCents, 840000);
    });

    test('多笔求和:同卡多笔未出账本金累加', () {
      final debts = [
        cardDebt('a', 840000, remaining: 300000),
        cardDebt('b', 1200000, remaining: 500000),
      ];
      final schedules = {'a': unbilled(300000), 'b': unbilled(500000)};
      final s = cardInstallmentSummary(debts, 'card-1', schedules,
          now: nowAnchor);
      expect(s.count, 2);
      expect(s.remainingCents, 800000);
    });

    test('期表全已出账的债不计入笔数与金额(银行分期剩余不含已出账)', () {
      final debts = [
        cardDebt('active', 840000, remaining: 400000),
        cardDebt('billed', 600000, remaining: 600000), // 全部期次已出账
      ];
      final schedules = {
        'active': unbilled(400000),
        // billed:仅一条已出账(过去)未还期次 = 自由窗口 → 不计。
        'billed': [
          PaymentEntry(
            id: 'billed-e0',
            paymentDate: DateTime.utc(2026, 5, 1),
            principalCents: 600000,
            interestCents: 0,
            totalCents: 600000,
            paid: false,
            paidCents: 0,
            transactionId: '',
          ),
        ],
      };
      final s = cardInstallmentSummary(debts, 'card-1', schedules,
          now: nowAnchor);
      expect(s.count, 1, reason: '无未出账期次的债不计笔数');
      expect(s.remainingCents, 400000, reason: '剩余仅未出账部分');
    });

    test('F58 边界:出账日当天不计,次日及以后出账才计', () {
      final debts = [cardDebt('d', 999999, remaining: 999999)];
      final schedules = {
        'd': [
          PaymentEntry(
              id: 'e0',
              paymentDate: DateTime.utc(2026, 6, 1), // 今日出账 → 不计
              principalCents: 400000,
              interestCents: 0,
              totalCents: 400000,
              paid: false,
              paidCents: 0,
              transactionId: ''),
          PaymentEntry(
              id: 'e1',
              paymentDate: DateTime.utc(2026, 6, 2), // 次日出账 → 计
              principalCents: 300000,
              interestCents: 0,
              totalCents: 300000,
              paid: false,
              paidCents: 0,
              transactionId: ''),
        ],
      };
      final s = cardInstallmentSummary(debts, 'card-1', schedules,
          now: nowAnchor);
      expect(s.count, 1, reason: '尚有未出账期次 → 计 1 笔');
      expect(s.remainingCents, 300000, reason: '仅次日及以后出账的本金');
    });

    test('无挂接空态:空表/无命中/期表缺项均返回 (0, 0)', () {
      expect(
          cardInstallmentSummary(const [], 'card-1', const {}, now: nowAnchor),
          (count: 0, remainingCents: 0));
      expect(
          cardInstallmentSummary([cardDebt('x', 1, cardId: 'card-9')],
              'card-1', const {},
              now: nowAnchor),
          (count: 0, remainingCents: 0));
      expect(
          cardInstallmentSummary([cardDebt('y', 123, cardId: 'card-1')],
              'card-1', const {},
              now: nowAnchor),
          (count: 0, remainingCents: 0),
          reason: '缺期表 = 无未出账期次,计 0 不回退整债剩余');
    });
  });
}
