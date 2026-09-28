import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/llm/llm_settings.dart';
import 'package:yucai_client/report/data/llm/llm_payload.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/report_document.dart';

/// F46 T1:sanitizedPayload(FR-2 脱敏聚合包,隐私红线测试)。
///
/// 负面清单 = 红线:序列化文本**不得**含 accountId/交易描述/模板名
/// (订阅名 includeNames 开启时例外);金额 = mdaCny 口径元两位小数字符串。
void main() {
  /// 全字段夹具:收支构成(带科目账户 id + 科目名)/预算/投资/三类现金流。
  ReportDocument buildDoc() => ReportDocument(
        period: ReportPeriod.monthly(2026, 8),
        generatedAt: DateTime.utc(2026, 9, 1, 4, 5, 6),
        overview: OverviewSection.create(
          netWorthStartCents: 1_000_000,
          netWorthEndCents: 1_234_567,
          incomeCents: 1_234_567,
          expenseCents: 987_654,
          cashDeltaCents: 50_000,
          notes: const [
            ReportNote(title: '口径说明', lines: ['本地时区月界']),
          ],
        ),
        balanceSheet: BalanceSheetSection.create(
          assets: [
            CategoryAmount.create(
              category: 'cash',
              name: '招商银行储蓄卡',
              amountCents: 800_000,
              totalCents: 800_000,
            ),
          ],
          liabilities: const [],
          changes: const [],
        ),
        incomeStatement: IncomeStatementSection(
          income: [
            CategoryAmount.create(
              category: 'acct-salary-001', // 科目账户 id(负面清单)
              name: '工资',
              amountCents: 1_134_567,
              totalCents: 1_234_567,
            ),
          ],
          expense: [
            CategoryAmount.create(
              category: 'acct-food-002', // 科目账户 id(负面清单)
              name: '餐饮',
              amountCents: 500_000,
              totalCents: 987_654,
            ),
          ],
          dailyAvgCents: 31_861,
          priorComparison: PriorComparison.create(
            label: '较 2026 年 7 月',
            surplusCents: 246_913,
            priorSurplusCents: 200_000,
          ),
        ),
        cashFlow: CashFlowSection(
          operating: ActivityFlow.create(inflowCents: 1_234_567, outflowCents: 900_000),
          investing: ActivityFlow.create(inflowCents: 0, outflowCents: 80_000),
          financing: ActivityFlow.create(inflowCents: 0, outflowCents: 4_567),
          netDeltaCents: 250_000,
          reconciled: true,
        ),
        budget: BudgetSection(items: [
          ReportBudgetItem.create(
            name: '餐饮预算',
            actualCents: 500_000,
            limitCents: 400_000,
          ),
        ]),
        investment: InvestmentSection.create(
          mvStartCents: 200_000,
          mvEndCents: 234_567,
          netBuyCents: 10_000,
          twr: 12.3,
        ),
        excludedSections: const ['投资绩效(无持仓)'],
      );

  /// findings 夹具:R4(含订阅名)/R5(含交易描述)/R1(纯数字,安全)。
  const findings = [
    MdaFinding(
      ruleId: 'R4',
      severity: MdaSeverity.warn,
      conclusion:
          '可能闲置:1 个支出订阅(Netflix 视频会员)在本期有应扣日但未见关联记账,'
          '月度等价合计约 ¥45.00;若仍在使用,记一笔时请关联该订阅',
      advice: '到订阅中心核对:仍在使用则记账时关联该订阅(规则即可校准),'
          '已不用则暂停或删除模板',
      actionLink: '/accounts/subscriptions',
    ),
    MdaFinding(
      ruleId: 'R5',
      severity: MdaSeverity.info,
      conclusion: '单笔大额支出:8 月 15 日「和同事聚餐请客」¥3,200.00,'
          '约为日均支出 ¥318.61 的 10.0 倍,占当期总支出 32.4%',
      advice: '确认该笔是否年付/预付类一次性支出;若是,按年均摊口径观察更合理',
    ),
    MdaFinding(
      ruleId: 'R1',
      severity: MdaSeverity.warn,
      conclusion: '储蓄率 20.0%,低于 20.0%',
      advice: '向 50/30/20 法则的储蓄 20% 目标靠拢',
    ),
  ];

  MdaSection buildMda() => MdaSection.create(findings: findings);

  const baseConfig = LlmConfig(
    enabled: true,
    provider: LlmProvider.zhipu,
    apiKey: 'sk-redacted',
    model: 'glm-4-plus',
    cityTier: LlmCityTier.tier1,
  );

  group('sanitizedPayload structure (design LLD 字段)', () {
    test('carries period label, net worth and savings rate', () {
      final payload =
          sanitizedPayload(buildDoc(), buildMda(), baseConfig);

      expect(payload['period'], '2026 年 8 月');
      final netWorth = payload['netWorth'] as Map<String, Object?>;
      expect(netWorth['start'], '¥10,000.00');
      expect(netWorth['end'], '¥12,345.67');
      expect(netWorth['changePct'], 23.5);
      expect(payload['savingsRate'], 20.0);
    });

    test('income/expense byCategory uses display names with mdaCny amounts',
        () {
      final payload =
          sanitizedPayload(buildDoc(), buildMda(), baseConfig);

      final income = payload['income'] as Map<String, Object?>;
      expect(income['total'], '¥12,345.67');
      final incomeRows = income['byCategory'] as List<Object?>;
      expect(incomeRows, hasLength(1));
      expect((incomeRows[0] as Map)['name'], '工资');
      expect((incomeRows[0] as Map)['amount'], '¥11,345.67');
      expect((incomeRows[0] as Map)['pct'], 91.9);

      final expense = payload['expense'] as Map<String, Object?>;
      expect(expense['total'], '¥9,876.54');
      final expenseRows = expense['byCategory'] as List<Object?>;
      expect((expenseRows[0] as Map)['name'], '餐饮');
      expect((expenseRows[0] as Map)['amount'], '¥5,000.00');
    });

    test('cashFlow carries three activity nets', () {
      final payload =
          sanitizedPayload(buildDoc(), buildMda(), baseConfig);

      final cashFlow = payload['cashFlow'] as Map<String, Object?>;
      expect(cashFlow['operating'], '¥3,345.67');
      expect(cashFlow['investing'], '-¥800.00');
      expect(cashFlow['financing'], '-¥45.67');
    });

    test('budget items carry name/actual/limit/pct', () {
      final payload =
          sanitizedPayload(buildDoc(), buildMda(), baseConfig);

      final budget = payload['budget'] as Map<String, Object?>;
      final items = budget['items'] as List<Object?>;
      expect(items, hasLength(1));
      final item = items[0] as Map<String, Object?>;
      expect(item['name'], '餐饮预算');
      expect(item['actual'], '¥5,000.00');
      expect(item['limit'], '¥4,000.00');
      expect(item['pct'], 125.0);
    });

    test('investment section maps through and is omitted when absent', () {
      final withInvestment =
          sanitizedPayload(buildDoc(), buildMda(), baseConfig);
      final investment =
          withInvestment['investment'] as Map<String, Object?>;
      expect(investment['mvStart'], '¥2,000.00');
      expect(investment['mvEnd'], '¥2,345.67');
      expect(investment['netBuy'], '¥100.00');
      expect(investment['estGain'], '¥245.67');
      expect(investment['twrPct'], 12.3);

      final bare = ReportDocument(
        period: ReportPeriod.monthly(2026, 8),
        generatedAt: DateTime.utc(2026, 9, 1),
        overview: OverviewSection.create(
          netWorthStartCents: 0,
          netWorthEndCents: 0,
          incomeCents: 0,
          expenseCents: 0,
          cashDeltaCents: 0,
          notes: const [],
        ),
        balanceSheet: BalanceSheetSection.create(
          assets: const [],
          liabilities: const [],
          changes: const [],
        ),
        incomeStatement: const IncomeStatementSection(
          income: [],
          expense: [],
          dailyAvgCents: 0,
        ),
        cashFlow: const CashFlowSection(
          operating: ActivityFlow(inflowCents: 0, outflowCents: 0, netCents: 0),
          investing: ActivityFlow(inflowCents: 0, outflowCents: 0, netCents: 0),
          financing: ActivityFlow(inflowCents: 0, outflowCents: 0, netCents: 0),
          netDeltaCents: 0,
          reconciled: true,
        ),
        excludedSections: const [],
      );
      final payload =
          sanitizedPayload(bare, buildMda(), baseConfig);
      expect(payload.containsKey('investment'), isFalse);
      expect(payload.containsKey('budget'), isTrue); // 无预算也出空 items
    });

    test('cityTier carries a Chinese label for LLM context', () {
      final payload =
          sanitizedPayload(buildDoc(), buildMda(), baseConfig);
      expect(payload['cityTier'], '一线');
    });
  });

  group('negative list (privacy red line)', () {
    test('serialized payload contains no account ids / names / descriptions',
        () {
      final text =
          jsonEncode(sanitizedPayload(buildDoc(), buildMda(), baseConfig));

      // 科目账户 id(收支 CategoryAmount.category)不得外发
      expect(text.contains('acct-salary-001'), isFalse);
      expect(text.contains('acct-food-002'), isFalse);
      // 资产账户名(资产负债构成不进 payload)
      expect(text.contains('招商银行储蓄卡'), isFalse);
      // 交易描述(R5 conclusion 内嵌 → 整条 R5 被排除)
      expect(text.contains('和同事聚餐请客'), isFalse);
      expect(text.contains('单笔大额支出'), isFalse);
      // api key 不入 payload(配置字段仅 cityTier/includeNames 语义参与)
      expect(text.contains('sk-redacted'), isFalse);
    });

    test('subscription names are redacted while includeNames is off', () {
      final text = jsonEncode(sanitizedPayload(
        buildDoc(),
        buildMda(),
        baseConfig, // includeNames 默认 false
      ));

      expect(text.contains('Netflix 视频会员'), isFalse);
      // R4 整条被排除(结论内嵌模板名,无法外科摘除 → fail-closed)
      expect(text.contains('可能闲置'), isFalse);
      // 安全 finding 照常放行
      expect(text.contains('储蓄率 20.0%'), isTrue);
    });

    test('subscription names pass through while includeNames is on', () {
      final text = jsonEncode(sanitizedPayload(
        buildDoc(),
        buildMda(),
        const LlmConfig(
          enabled: true,
          provider: LlmProvider.zhipu,
          apiKey: 'sk-redacted',
          model: 'glm-4-plus',
          cityTier: LlmCityTier.tier1,
          includeNames: true,
        ),
      ));

      // 「订阅:名=月度等价」级别加入(R4 conclusion 自带该粒度)
      expect(text.contains('Netflix 视频会员'), isTrue);
      expect(text.contains('月度等价合计约 ¥45.00'), isTrue);
      // 交易描述仍被排除(无开关,红线不可选)
      expect(text.contains('和同事聚餐请客'), isFalse);
    });

    test('findings carry severity/conclusion/advice only (no rule ids/links)',
        () {
      final payload =
          sanitizedPayload(buildDoc(), buildMda(), baseConfig);
      final list = payload['findings'] as List<Object?>;
      // R4/R5 被排除后仅剩 R1
      expect(list, hasLength(1));
      final finding = list[0] as Map<String, Object?>;
      expect(finding.keys.toSet(), {'severity', 'conclusion', 'advice'});
      expect(finding['severity'], 'warn');
    });
  });
}
