// TDD RED → GREEN:F9-T3 债务查询助手(搜索匹配 + 四态排序)纯函数单测。
//
// F9 FR-4 / ADR-3:债务/债权列表的搜索(counterparty contains)与排序
// (总金额/到期日 × 升降)以**纯 domain 函数**落地(debt/domain/debt_query.dart),
// DS 层与两页(债务/债权)共用同一实现 —— 复用第一,避免 DS/页面两套口径漂移。
// 纯函数不依赖 Flutter/drift,直接单测。
//
// 默认序不变式(NFR-2):(dueDate, asc) == 既有 debtCompareList(未结清在前 +
// 到期升序)逐位一致 —— 列表页初始态即现状序。
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
}
