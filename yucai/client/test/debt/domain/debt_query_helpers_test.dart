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

  group('F49 cardInstallmentSummary(卡面分期徽标数据源)', () {
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
      final s = cardInstallmentSummary(debts, 'card-1');
      expect(s.count, 1);
      expect(s.remainingCents, 840000);
    });

    test('多笔求和:同卡多笔剩余本金累加', () {
      final debts = [
        cardDebt('a', 840000, remaining: 300000),
        cardDebt('b', 1200000, remaining: 500000),
      ];
      final s = cardInstallmentSummary(debts, 'card-1');
      expect(s.count, 2);
      expect(s.remainingCents, 800000);
    });

    test('未结清口径:已清偿(剩余 0)不计入笔数与金额', () {
      final debts = [
        cardDebt('active', 840000, remaining: 400000),
        cardDebt('settled', 600000, remaining: 0),
      ];
      final s = cardInstallmentSummary(debts, 'card-1');
      expect(s.count, 1, reason: '已清偿不计笔数');
      expect(s.remainingCents, 400000, reason: '剩余仅未结清部分');
    });

    test('无挂接空态:空表/无命中均返回 (0, 0)', () {
      expect(cardInstallmentSummary(const [], 'card-1'),
          (count: 0, remainingCents: 0));
      expect(cardInstallmentSummary([cardDebt('x', 1, cardId: 'card-9')], 'card-1'),
          (count: 0, remainingCents: 0));
    });
  });
}
