// F44 T4 —— NFR-1 性能门:8 规则引擎全跑(含大 supplement)wall clock
// ≤ 500ms(spec NFR-1「典型账本,测试环境」;阈值即 spec 值,不另留余量)。
//
// 大输入手算规模(典型账本上界放大):
//   200 支出模板 × 12 期内应扣日(≈隔日 custom 周期一个月的应扣密度)
//   + 500 大额交易候选 + 20 支出类别(当期/前期各 20,H2 环比全配对)。
// 种子确定性(无随机);oracle:发现集非空且规则命中可手推(R1 透支
// risk / R4 200 模板闲置合并 1 条 / R5 单笔 info),证明计时链路算的
// 是真数据而非空转。构造不计入计时窗口,只计 evaluate 全跑。
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/report/domain/mda/mda_engine.dart';

import 'mda_fixtures.dart';

void main() {
  const engine = MdaEngine();

  test('NFR-1:200 模板×12 应扣日 + 500 大额交易,8 规则全跑 ≤ 500ms', () {
    // —— 种子(不计入计时)——
    // 200 支出模板:月度 150.00,期内应扣日 12 个(8/2 起隔日),
    // nextDate = 2026-09-10(晚于期末超 grace 7 天窗口 → 不按即将扣费
    // 宽限跳过),从未记账 → 全部闲置(R4 候选全量)。
    final templates = [
      for (var i = 0; i < 200; i++)
        expenseTemplate(
          id: 'tpl-$i',
          name: '大账本订阅$i',
          amountCents: 15000 + i, // 金额各异,防编译期常量折叠式捷径
          nextDate: DateTime.utc(2026, 9, 10),
          expectedDates: [
            for (var j = 0; j < 12; j++) DateTime.utc(2026, 8, 2 + 2 * j),
          ],
        ),
    ];
    // 500 大额交易候选:8 月内逐日 499 笔 60.00 + 1 笔 9,000.00
    //(R5 双门槛:日均支出 3 倍 + 当期占比 20%,只有末笔命中 → info)。
    final transactions = [
      for (var i = 0; i < 499; i++)
        txn('tx-$i', DateTime.utc(2026, 8, 1 + i % 31), '日常$i', 6000),
      txn('tx-big', DateTime.utc(2026, 8, 20), '大额单笔', 900000),
    ];
    // 支出类别:当期 20 类各 5,000 + 首类 10,000(H1 取首条;
    // 前期同 20 类半额 → H2 全配对无命中,仍跑满映射查找)。
    const catCount = 20;
    final breakdown = [
      for (var i = 0; i < catCount; i++)
        expenseRow('cat$i', '类别$i', i == 0 ? 100000 : 50000,
            100000 + (catCount - 1) * 50000),
    ];
    final prior = [
      for (var i = 0; i < catCount; i++)
        expenseRow('cat$i', '类别$i', i == 0 ? 50000 : 25000,
            50000 + (catCount - 1) * 25000),
    ];
    final doc = mdaDoc(
      incomeCents: 100000, // 收入 1,000 << 支出 1,050,000 → R1 透支 risk
      expenseCents: 100000 + (catCount - 1) * 50000,
      expenseBreakdown: breakdown,
      assetsCents: 1000000,
      liabilitiesCents: 0,
    );
    final sup = mdaSupplement(
      templates: templates,
      transactions: transactions,
      trailing3mExpenseCents: 5100000, // 月均 1,700,000
      cashEndCents: 1000000, // runway ≈ 0.6 个月 → R6 risk
      priorExpense: prior,
    );

    // —— 计时窗口:8 规则全跑(evaluate = 遍历 + 排序 + 计数)——
    final sw = Stopwatch()..start();
    final section = engine.evaluate(doc, sup);
    sw.stop();
    // ignore: avoid_print
    print(
      'NFR-1 mda engine: 8 rules over '
      '${templates.length} templates(${templates.first.expectedDates.length} '
      'dates each) + ${transactions.length} txns, '
      '${sw.elapsedMilliseconds}ms (budget 500ms), '
      'findings=${section.findings.length}',
    );

    // —— 门:≤ 500ms(spec NFR-1)——
    expect(sw.elapsedMilliseconds, lessThanOrEqualTo(500));

    // —— 链路算的是真数据(oracle,防空转)——
    // 手推:R1 risk(透支)+ R6 risk(runway 0.6)+ R4 warn(200 闲置
    // 合并 1 条,月度等价 = Σ round(amount/1) = 200×15,000 起步再加
    // Σi(i=0..199)= 19,900 → 3,019,900 → ¥30,199.00)+ R5 info(1 笔)。
    expect(section.findings.map((f) => f.ruleId),
        containsAll(['R1', 'R6', 'R4', 'R5']));
    expect(section.riskCount, greaterThanOrEqualTo(2));
    expect(
      section.findings
          .firstWhere((f) => f.ruleId == 'R4')
          .conclusion
          .contains('200 个支出订阅'),
      isTrue,
      reason: 'R4 合并计数 = 200(模板全量入判)',
    );
    expect(
      section.findings
          .firstWhere((f) => f.ruleId == 'R4')
          .conclusion
          .contains('¥30,199.00'),
      isTrue,
      reason: 'R4 月度等价合计 = 3,019,900 分(每模板周期 1 个月)',
    );
    expect(
      section.findings
          .firstWhere((f) => f.ruleId == 'R5')
          .conclusion
          .contains('9,000.00'),
      isTrue,
      reason: 'R5 命中唯一大额笔(¥9,000 = 日均 ¥338.71 的 26.6 倍/占 85.7%)',
    );
  });
}
