import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/rules/r5_large_single.dart';

import '../mda_fixtures.dart';

/// F44 T1:R5 大额单笔(FR-2 双门槛)。
///
/// 单笔支出 ≥ 当期日均支出×3 且 ≥ 当期总支出 20% → info;
/// 日均 = 总支出 ÷ 当期自然天数(报告期含首尾)。
/// 注:月/年报期天数恒 ≥28 → 3×日均恒 ≤ 总支出 9.7%,即占比门槛
/// 恒更严——「占比达 20% 但日均倍数不足」的组合在真实报告期不可达,
/// 两门槛以「单边不触发 + 边界等号」双向钉死。
/// 文案带年付语境句(若为年付/预付类支出属正常现象)。
void main() {
  const rule = R5LargeSingle();

  // 2026-08(31 天)总支出 ¥10,000 → 日均 ¥322.58(32258.06 分);
  // ×3 = ¥967.74;20% = ¥2,000。
  final doc = mdaDoc(incomeCents: 1_500_000, expenseCents: 1_000_000);

  test('家电 ¥6,000:达 18.6 倍日均且占 60% → info,结论含年付语境句', () {
    final findings = rule.evaluate(
      doc,
      mdaSupplement(transactions: [
        txn('t1', DateTime(2026, 8, 15), '家电', 600_000),
      ]),
    );

    expect(findings, hasLength(1));
    expect(findings.single.ruleId, 'R5');
    expect(findings.single.severity, MdaSeverity.info);
    expect(findings.single.conclusion, contains('¥6,000.00'));
    expect(findings.single.conclusion, contains('18.6'));
    expect(findings.single.conclusion, contains('60.0%'));
    expect(findings.single.conclusion, contains('若为年付/预付类支出属正常现象'));
  });

  test('门槛单边:¥1,500 达 3 倍日均(4.6 倍)但占比 15% <20% → 不触发', () {
    final findings = rule.evaluate(
      doc,
      mdaSupplement(transactions: [
        txn('t1', DateTime(2026, 8, 15), '家电', 150_000),
      ]),
    );

    expect(findings, isEmpty);
  });

  test('门槛单边:占比 19.9% → 不触发(严格小于 20%)', () {
    final findings = rule.evaluate(
      doc,
      mdaSupplement(transactions: [
        txn('t1', DateTime(2026, 8, 15), '家电', 199_000),
      ]),
    );

    expect(findings, isEmpty);
  });

  test('边界:恰 ¥2,000(占比 20.0%,且 6.2 倍日均)→ 触发(含等号)', () {
    final findings = rule.evaluate(
      doc,
      mdaSupplement(transactions: [
        txn('t1', DateTime(2026, 8, 15), '家电', 200_000),
      ]),
    );

    expect(findings, hasLength(1));
    expect(findings.single.conclusion, contains('20.0%'));
  });

  test('小额定投式支出(多笔各 ¥500)→ 均不触发', () {
    final findings = rule.evaluate(
      doc,
      mdaSupplement(transactions: [
        txn('t1', DateTime(2026, 8, 3), '日用', 50_000),
        txn('t2', DateTime(2026, 8, 10), '日用', 50_000),
        txn('t3', DateTime(2026, 8, 20), '日用', 50_000),
      ]),
    );

    expect(findings, isEmpty);
  });

  test('两笔均达双门槛 → 两条 finding(逐笔独立)', () {
    final findings = rule.evaluate(
      doc,
      mdaSupplement(transactions: [
        txn('t1', DateTime(2026, 8, 5), '家电', 600_000),
        txn('t2', DateTime(2026, 8, 22), '旅行', 300_000), // 占比 30%,9.3 倍日均
      ]),
    );

    expect(findings, hasLength(2));
  });

  test('空交易列表与总支出为 0 → 不触发', () {
    expect(rule.evaluate(doc, mdaSupplement()), isEmpty);
    expect(
      rule.evaluate(
        mdaDoc(incomeCents: 1_000_000, expenseCents: 0),
        mdaSupplement(transactions: [
          txn('t1', DateTime(2026, 8, 5), '家电', 600_000),
        ]),
      ),
      isEmpty,
    );
  });
}
