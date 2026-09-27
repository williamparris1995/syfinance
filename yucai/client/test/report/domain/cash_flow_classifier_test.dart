import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/report/domain/cash_flow_classifier.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/domain/report_ledger_store.dart';

/// T1 report domain:现金流分类器(FR-5/ADR-4 表驱动矩阵 + 勾稽不变式)。
///
/// 现金 = 仅 savings 类账户;对手 income/expense 科目 → 经营;对手投资类
/// 资产(investment/fixedDeposit/goldFx/storedValue/realEstate/otherAsset)
/// → 投资;对手负债/权益 → 融资;现金↔现金、非现金×非现金 → 不计。
/// 期望值全部手算(G oracle),期初/期末现金由用例手工给出(回放在
/// balance_replay_test 单独钉死)。
void main() {
  // 便捷构造:分录行(所属交易 t、账户 a、类型/类别、日期、借/贷)。
  LedgerEntryRow e(String t, String a, DateTime date,
          {int debitCents = 0,
          int creditCents = 0,
          int type = 1,
          String? category = 'savings'}) =>
      LedgerEntryRow(
        transactionId: t,
        accountId: a,
        accountType: type,
        category: category,
        date: date,
        debitCents: debitCents,
        creditCents: creditCents,
      );

  final aug = ReportPeriod.monthly(2026, 8);

  ActivityFlow flowOf(CashFlowSection s, String name) => switch (name) {
        'operating' => s.operating,
        'investing' => s.investing,
        _ => s.financing,
      };

  Matcher zeroFlow() => isA<ActivityFlow>()
      .having((f) => f.inflowCents, 'inflow', 0)
      .having((f) => f.outflowCents, 'outflow', 0)
      .having((f) => f.netCents, 'net', 0);

  test('FR-5 场景1:储蓄→储值卡 500 → 投资流出 500、现金净 −500(期内过滤)', () {
    final section = const CashFlowClassifier().classify(
      entries: [
        // 8-08 储蓄→储值卡充值 500。
        e('t1', 'S', DateTime(2026, 8, 8), creditCents: 500),
        e('t1', 'V', DateTime(2026, 8, 8), debitCents: 500, category: 'storedValue'),
        // 9-05 的同类交易不在 8 月报告期内,不得计入。
        e('t2', 'S', DateTime(2026, 9, 5), creditCents: 999),
        e('t2', 'V', DateTime(2026, 9, 5), debitCents: 999, category: 'storedValue'),
      ],
      period: aug,
      cashStartCents: 0,
      cashEndCents: -500,
    );
    expect(section.investing.outflowCents, 500);
    expect(section.investing.inflowCents, 0);
    expect(section.investing.netCents, -500);
    expect(section.operating, zeroFlow());
    expect(section.financing, zeroFlow());
    expect(section.netDeltaCents, -500);
    expect(section.reconciled, isTrue);
  });

  test('FR-5 场景2:储蓄→expense 消费 300 → 经营流出 300', () {
    final section = const CashFlowClassifier().classify(
      entries: [
        e('t1', 'S', DateTime(2026, 8, 3), creditCents: 300),
        e('t1', 'E', DateTime(2026, 8, 3), debitCents: 300, type: 5, category: null),
      ],
      period: aug,
      cashStartCents: 0,
      cashEndCents: -300,
    );
    expect(section.operating.outflowCents, 300);
    expect(section.operating.netCents, -300);
    expect(section.investing, zeroFlow());
    expect(section.financing, zeroFlow());
    expect(section.netDeltaCents, -300);
  });

  test('FR-5 场景3:信用卡刷卡(不涉现金)+ 月末储蓄还款 → 经营 0、融资流出 300', () {
    final section = const CashFlowClassifier().classify(
      entries: [
        // 8-10 刷卡消费 300:信用卡 credit × expense debit,无现金参与 → 不计。
        e('t1', 'C', DateTime(2026, 8, 10), creditCents: 300, type: 2, category: 'creditCard'),
        e('t1', 'E', DateTime(2026, 8, 10), debitCents: 300, type: 5, category: null),
        // 8-31 储蓄→信用卡还款 300 → 融资流出。
        e('t2', 'S', DateTime(2026, 8, 31), creditCents: 300),
        e('t2', 'C', DateTime(2026, 8, 31), debitCents: 300, type: 2, category: 'creditCard'),
      ],
      period: aug,
      cashStartCents: 1000, // 储蓄 initial 1000
      cashEndCents: 700, // 1000 − 300
    );
    expect(section.operating, zeroFlow());
    expect(section.financing.outflowCents, 300);
    expect(section.financing.netCents, -300);
    expect(section.investing, zeroFlow());
    expect(section.netDeltaCents, -300);
  });

  test('FR-5 勾稽反例:三类净额 ≠ 期末−期初现金 → 必抛 StateError(消息含两侧数值)', () {
    final entries = [
      e('t1', 'S', DateTime(2026, 8, 3), creditCents: 300),
      e('t1', 'E', DateTime(2026, 8, 3), debitCents: 300, type: 5, category: null),
    ];
    // 真实现金净变动 −300,故意喂 0 → 勾稽失败。
    expect(
      () => const CashFlowClassifier().classify(
        entries: entries,
        period: aug,
        cashStartCents: 0,
        cashEndCents: 0,
      ),
      throwsA(isA<StateError>().having(
        (err) => err.message,
        'message',
        allOf(contains('-300'), contains('0')),
      )),
    );
  });

  test('勾稽反例2:单边现金分录(无对手)无法归因 → 必抛 StateError', () {
    expect(
      () => const CashFlowClassifier().classify(
        entries: [e('t1', 'S', DateTime(2026, 8, 3), debitCents: 1000)],
        period: aug,
        cashStartCents: 0,
        cashEndCents: 1000,
      ),
      throwsStateError,
    );
  });

  test('现金↔现金内部划转不计:三类活动全零、净变动 0', () {
    final section = const CashFlowClassifier().classify(
      entries: [
        e('t1', 'S1', DateTime(2026, 8, 6), creditCents: 100),
        e('t1', 'S2', DateTime(2026, 8, 6), debitCents: 100),
      ],
      period: aug,
      cashStartCents: 500, // S1 300 + S2 200
      cashEndCents: 500, // S1 200 + S2 300,总额不变
    );
    expect(section.operating, zeroFlow());
    expect(section.investing, zeroFlow());
    expect(section.financing, zeroFlow());
    expect(section.netDeltaCents, 0);
  });

  test('矩阵穷举:现金本方 × 全部对手类别 → 归类与流向逐一命中', () {
    // (对手类型, 对手 category, 期望活动, 现金变动符号;金额恒 100)。
    const cases = <(int, String?, String, int)>[
      (4, null, 'operating', 1), // 收入 → 经营流入
      (5, null, 'operating', -1), // 支出 → 经营流出
      (1, 'investment', 'investing', -1),
      (1, 'fixedDeposit', 'investing', -1),
      (1, 'goldFx', 'investing', -1),
      (1, 'storedValue', 'investing', -1),
      (1, 'realEstate', 'investing', -1),
      (1, 'otherAsset', 'investing', -1),
      (2, 'creditCard', 'financing', -1), // 还款 → 融资流出
      (2, 'loan', 'financing', -1), // 偿还贷款 → 融资流出
      (3, null, 'financing', 1), // 权益投入 → 融资流入
    ];
    for (final (cpType, cpCategory, activity, sign) in cases) {
      final d = DateTime(2026, 8, 10);
      final section = const CashFlowClassifier().classify(
        entries: [
          // sign>0:现金 debit 100(流入)/ 对手 credit 100;sign<0 镜像。
          e('t', 'S', d, debitCents: sign > 0 ? 100 : 0, creditCents: sign < 0 ? 100 : 0),
          e('t', 'CP', d,
              debitCents: sign < 0 ? 100 : 0,
              creditCents: sign > 0 ? 100 : 0,
              type: cpType,
              category: cpCategory),
        ],
        period: aug,
        cashStartCents: 0,
        cashEndCents: 100 * sign,
      );
      final flow = flowOf(section, activity);
      expect(flow.inflowCents, sign > 0 ? 100 : 0,
          reason: '$cpType/$cpCategory 应为 $activity 流入');
      expect(flow.outflowCents, sign < 0 ? 100 : 0,
          reason: '$cpType/$cpCategory 应为 $activity 流出');
      expect(flow.netCents, 100 * sign,
          reason: '$cpType/$cpCategory 净额');
      final others = ['operating', 'investing', 'financing']..remove(activity);
      for (final other in others) {
        expect(flowOf(section, other), zeroFlow(),
            reason: '$cpType/$cpCategory 不应计入 $other');
      }
      expect(section.netDeltaCents, 100 * sign);
    }
  });

  test('矩阵穷举:非现金本方(储值卡)× 各类对手 → 一律不计', () {
    const counterparties = <(int, String?)>[
      (4, null), // 储值卡消费替代现金的收益场景
      (5, null), // 储值卡消费(典型:不出现金流)
      (2, 'creditCard'),
      (3, null),
      (1, 'investment'),
    ];
    for (final (cpType, cpCategory) in counterparties) {
      final d = DateTime(2026, 8, 12);
      final section = const CashFlowClassifier().classify(
        entries: [
          e('t', 'V', d, debitCents: 100, category: 'storedValue'),
          e('t', 'CP', d, creditCents: 100, type: cpType, category: cpCategory),
        ],
        period: aug,
        cashStartCents: 0,
        cashEndCents: 0,
      );
      expect(section.operating, zeroFlow(), reason: '$cpType/$cpCategory 非现金本方');
      expect(section.investing, zeroFlow(), reason: '$cpType/$cpCategory 非现金本方');
      expect(section.financing, zeroFlow(), reason: '$cpType/$cpCategory 非现金本方');
      expect(section.netDeltaCents, 0);
    }
  });

  test('期内过滤:期前交易不计入本期现金流(期初现金已含其影响)', () {
    final section = const CashFlowClassifier().classify(
      entries: [
        // 7 月储蓄→expense 400:属 7 月报告期,8 月现金流不计。
        e('t0', 'S', DateTime(2026, 7, 20), creditCents: 400),
        e('t0', 'E', DateTime(2026, 7, 20), debitCents: 400, type: 5, category: null),
        // 8 月无现金流。
      ],
      period: aug,
      cashStartCents: 600,
      cashEndCents: 600,
    );
    expect(section.operating, zeroFlow());
    expect(section.netDeltaCents, 0);
  });
}
