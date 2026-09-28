/// F46 T2「AI 解读」入口 + 解读小节旁挂 widget 测试(seam =
/// FinancialReportPage 公共构造 + narrator/llmSettings 注入缝;真实 bloc +
/// mock ReportAssemblyService + fake MdaNarrator —— narrate 经构造注入替换,
/// 零真实网络)。
///
/// 覆盖:按钮可见性两态(ready && Loaded 才可见)/旁挂三态(loading→done
/// + 「由 {model} 生成」chip)/NarrationFailure → 错误态 + 重试/重新解读/
/// 清空语义(期变更、重新生成、在途丢弃)/健康态零发现(小节缺席,点击
/// 零调用)/narrate 入参 = 当前文档 + 诊断发现。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/llm/llm_settings.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/mda_narrator.dart';
import 'package:yucai_client/report/domain/report_assembly_service.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/presentation/financial_report_bloc.dart';
import 'package:yucai_client/report/presentation/pages/financial_report_page.dart';

class _MockAssembly extends Mock implements ReportAssemblyService {}

/// Fake LlmSettings(注入缝):notifier 驱动 ready 门,model 供 chip。
class _StubLlmSettings implements LlmSettings {
  _StubLlmSettings(LlmConfig initial)
      : _notifier = ValueNotifier<LlmConfig>(initial);
  final ValueNotifier<LlmConfig> _notifier;

  void update(LlmConfig config) => _notifier.value = config;

  @override
  LlmConfig get value => _notifier.value;

  @override
  ValueListenable<LlmConfig> get listenable => _notifier;

  @override
  bool get ready => _notifier.value.ready;

  @override
  Future<void> load() async {}

  @override
  Future<void> setConfig(LlmConfig config) async =>
      _notifier.value = config;
}

/// Fake narrator:记录调用(文档+发现);可门控(gate)/抛错(error)。
class _FakeNarrator implements MdaNarrator {
  final calls = <(ReportDocument, List<MdaFinding>)>[];
  String text = '总体评价:本期储蓄率 45.6%,高于 20% 的健康线,财务状况稳健…';
  Object? error;
  Completer<void>? gate;

  @override
  Future<String> narrate(ReportDocument doc, List<MdaFinding> findings) async {
    calls.add((doc, findings));
    final g = gate;
    if (g != null) await g.future;
    final e = error;
    if (e != null) throw e;
    return text;
  }
}

/// ready 配置(zhipu 预设端点 + Key + 模型齐备)。
const _readyCfg = LlmConfig(
  enabled: true,
  apiKey: 'sk-test',
  model: 'glm-4.6',
);

const _fixPeriod = ReportMonthly(2026, 8);

/// 三发现文档(照 financial_report_page_test fixture 口径,含 mda)。
ReportDocument _doc({required MdaSection mda}) => ReportDocument(
      period: _fixPeriod,
      generatedAt: DateTime.utc(2026, 9, 1),
      overview: OverviewSection.create(
        netWorthStartCents: 28645000,
        netWorthEndCents: 30128000,
        incomeCents: 3250000,
        expenseCents: 1767000,
        cashDeltaCents: 853000,
        notes: const [
          ReportNote(title: '口径说明', lines: ['期初/期末余额由全量分录回放重建。']),
        ],
      ),
      balanceSheet: BalanceSheetSection.create(
        assets: [
          CategoryAmount.create(
              category: 'savings', amountCents: 5373000, totalCents: 5373000),
        ],
        liabilities: [
          CategoryAmount.create(
              category: 'loan', amountCents: 10784000, totalCents: 10784000),
        ],
        changes: [
          BalanceChange.create(
              category: 'savings', startCents: 4520000, endCents: 5373000),
        ],
      ),
      incomeStatement: IncomeStatementSection(
        income: [
          CategoryAmount.create(
              category: 'income-salary',
              name: '工资',
              amountCents: 2800000,
              totalCents: 3250000),
        ],
        expense: [
          CategoryAmount.create(
              category: 'expense-food',
              name: '伙食费',
              amountCents: 620000,
              totalCents: 1767000),
        ],
        dailyAvgCents: 57000,
        priorComparison: null,
      ),
      cashFlow: CashFlowSection(
        operating:
            ActivityFlow.create(inflowCents: 3250000, outflowCents: 1697000),
        investing: ActivityFlow.create(inflowCents: 0, outflowCents: 500000),
        financing: ActivityFlow.create(inflowCents: 0, outflowCents: 200000),
        netDeltaCents: 853000,
        reconciled: true,
      ),
      budget: null,
      investment: null,
      mda: mda,
      excludedSections: const [],
    );

MdaSection _mda({bool empty = false}) => MdaSection.create(
      findings: empty
          ? const []
          : const [
              MdaFinding(
                ruleId: 'R2',
                severity: MdaSeverity.warn,
                conclusion: '购物超预算:4,120/3,500(118%),超支 620.00',
                advice: '建议复盘该类别或上调预算至实际水平',
              ),
              MdaFinding(
                ruleId: 'R5',
                severity: MdaSeverity.info,
                conclusion: '大额单笔:9 月 2 日单笔 3,600.00(年卡)',
                advice: '若为年付/预付类支出属正常现象',
              ),
            ],
      healthyRunwayMonths: empty ? 3.2 : null,
    );

void Function(ReportPhase)? _onPhaseOf(Invocation inv) =>
    inv.namedArguments[const Symbol('onPhase')]
        as void Function(ReportPhase)?;

void main() {
  late _MockAssembly assembly;

  setUpAll(() {
    registerFallbackValue(const ReportMonthly(2026, 8));
  });

  setUp(() {
    assembly = _MockAssembly();
  });

  Widget harness({
    _StubLlmSettings? llm,
    _FakeNarrator? narrator,
  }) {
    final bloc = FinancialReportBloc(assembly);
    return MaterialApp(
      home: BlocProvider<FinancialReportBloc>.value(
        value: bloc,
        child: FinancialReportPage(
          initialPeriod: _fixPeriod,
          llmSettings: llm,
          narrator: narrator,
        ),
      ),
    );
  }

  /// 生成到 Loaded(解读前提态;注入缝须全程同实例,照 export 测试注)。
  Future<void> pumpLoaded(
    WidgetTester t, {
    _StubLlmSettings? llm,
    _FakeNarrator? narrator,
    MdaSection? mda,
  }) async {
    when(() => assembly.generate(any(), onPhase: any(named: 'onPhase')))
        .thenAnswer((inv) async {
      final onPhase = _onPhaseOf(inv);
      for (final p in ReportPhase.values) {
        onPhase?.call(p);
      }
      return _doc(mda: mda ?? _mda());
    });
    await t.pumpWidget(harness(llm: llm, narrator: narrator));
    await t.tap(find.byKey(const ValueKey('generateReportButton')));
    await t.pumpAndSettle();
  }

  group('按钮可见性(仅 LlmConfig.ready 且 Loaded)', () {
    testWidgets('未配置(not ready):Loaded 后仍无「AI 解读」按钮', (t) async {
      await pumpLoaded(t, llm: _StubLlmSettings(const LlmConfig()));
      expect(find.byKey(const ValueKey('analystNarrateButton')), findsNothing);
      expect(find.text('AI 解读'), findsNothing);
    });

    testWidgets('ready 但未生成(非 Loaded):无按钮;生成后出现', (t) async {
      final llm = _StubLlmSettings(_readyCfg);
      when(() => assembly.generate(any(), onPhase: any(named: 'onPhase')))
          .thenAnswer((inv) async {
        final onPhase = _onPhaseOf(inv);
        for (final p in ReportPhase.values) {
          onPhase?.call(p);
        }
        return _doc(mda: _mda());
      });
      await t.pumpWidget(harness(llm: llm));
      await t.pumpAndSettle();
      // Initial 态:非 Loaded,按钮缺席。
      expect(find.byKey(const ValueKey('analystNarrateButton')), findsNothing);
      await t.tap(find.byKey(const ValueKey('generateReportButton')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('analystNarrateButton')), findsOneWidget);
      expect(find.text('AI 解读'), findsOneWidget);
    });

    testWidgets('ready→关掉配置:按钮实时消失(listenable 驱动)', (t) async {
      final llm = _StubLlmSettings(_readyCfg);
      await pumpLoaded(t, llm: llm);
      expect(find.byKey(const ValueKey('analystNarrateButton')), findsOneWidget);
      llm.update(const LlmConfig()); // enabled=false → not ready
      await t.pump();
      expect(find.byKey(const ValueKey('analystNarrateButton')), findsNothing);
    });
  });

  group('旁挂三态(点击 → narrate → 小节)', () {
    testWidgets('点击:loading「解读生成中…」→ done 文本 + 「由 glm-4.6 生成」chip',
        (t) async {
      final narrator = _FakeNarrator();
      await pumpLoaded(t, llm: _StubLlmSettings(_readyCfg), narrator: narrator);
      // 门控 narrate:稳定观察 loading 态(spinner 不 settle,pump 即可)。
      narrator.gate = Completer<void>();
      await t.tap(find.byKey(const ValueKey('analystNarrateButton')));
      await t.pump();
      expect(find.text('解读生成中…'), findsOneWidget);
      expect(find.text('分析师解读'), findsOneWidget);
      expect(narrator.calls, hasLength(1));
      narrator.gate!.complete();
      await t.pump();
      expect(find.textContaining('总体评价:本期储蓄率 45.6%'), findsOneWidget);
      expect(find.text('由 glm-4.6 生成'), findsOneWidget);
      expect(find.text('解读生成中…'), findsNothing);
    });

    testWidgets('narrate 入参 = 当前文档 + 诊断发现(mda.findings)', (t) async {
      final narrator = _FakeNarrator();
      await pumpLoaded(t, llm: _StubLlmSettings(_readyCfg), narrator: narrator);
      await t.tap(find.byKey(const ValueKey('analystNarrateButton')));
      await t.pump();
      final (doc, findings) = narrator.calls.single;
      expect(doc.period, isA<ReportMonthly>());
      expect(findings, hasLength(2));
      expect(findings.first.ruleId, 'R2');
      expect(findings.first.conclusion, contains('购物超预算'));
    });

    testWidgets('错误态:NarrationFailure → 「解读失败:{msg}」+ 重试恢复',
        (t) async {
      final narrator = _FakeNarrator()
        ..error = const NarrationFailure('HTTP 401(open.bigmodel.cn)');
      await pumpLoaded(t, llm: _StubLlmSettings(_readyCfg), narrator: narrator);
      await t.tap(find.byKey(const ValueKey('analystNarrateButton')));
      await t.pump();
      expect(find.text('解读失败:HTTP 401(open.bigmodel.cn)'), findsOneWidget);
      // 重试:清错后同缝重发 → done(小节在页底,先滚入视口再点)。
      narrator.error = null;
      await t.ensureVisible(find.text('重试'));
      await t.pumpAndSettle();
      await t.tap(find.text('重试'));
      await t.pump();
      expect(narrator.calls, hasLength(2));
      expect(find.textContaining('总体评价:'), findsOneWidget);
    });

    testWidgets('重新解读:done 态脚注「重新解读」→ 再次 narrate', (t) async {
      final narrator = _FakeNarrator();
      await pumpLoaded(t, llm: _StubLlmSettings(_readyCfg), narrator: narrator);
      await t.tap(find.byKey(const ValueKey('analystNarrateButton')));
      await t.pump();
      expect(narrator.calls, hasLength(1));
      // 小节在页底,先滚入视口再点「重新解读」。
      await t.ensureVisible(find.text('重新解读'));
      await t.pumpAndSettle();
      await t.tap(find.text('重新解读'));
      await t.pump();
      expect(narrator.calls, hasLength(2));
      expect(find.textContaining('总体评价:'), findsOneWidget);
    });
  });

  group('清空语义(期变更/重新生成 → idle;在途丢弃)', () {
    testWidgets('done 后切上一期:小节回 idle 缺席', (t) async {
      final narrator = _FakeNarrator();
      await pumpLoaded(t, llm: _StubLlmSettings(_readyCfg), narrator: narrator);
      await t.tap(find.byKey(const ValueKey('analystNarrateButton')));
      await t.pump();
      expect(find.textContaining('总体评价:'), findsOneWidget);
      await t.tap(find.byTooltip('上一期'));
      await t.pumpAndSettle();
      expect(find.text('分析师解读'), findsNothing, reason: '期变更 → idle 清空');
    });

    testWidgets('done 后重新生成:小节回 idle 缺席', (t) async {
      final narrator = _FakeNarrator();
      await pumpLoaded(t, llm: _StubLlmSettings(_readyCfg), narrator: narrator);
      await t.tap(find.byKey(const ValueKey('analystNarrateButton')));
      await t.pump();
      expect(find.textContaining('总体评价:'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('generateReportButton')));
      await t.pumpAndSettle();
      expect(find.text('分析师解读'), findsNothing, reason: '重新生成 → idle 清空');
    });

    testWidgets('在途切期:迟到的 narrate 结果不回填(仍 idle)', (t) async {
      final narrator = _FakeNarrator();
      await pumpLoaded(t, llm: _StubLlmSettings(_readyCfg), narrator: narrator);
      narrator.gate = Completer<void>();
      await t.tap(find.byKey(const ValueKey('analystNarrateButton')));
      await t.pump();
      expect(find.text('解读生成中…'), findsOneWidget);
      await t.tap(find.byTooltip('上一期'));
      await t.pumpAndSettle();
      narrator.gate!.complete();
      await t.pump();
      await t.pumpAndSettle();
      expect(find.text('解读生成中…'), findsNothing);
      expect(find.textContaining('总体评价:'), findsNothing,
          reason: '在途结果被会话令牌丢弃');
    });
  });

  group('健康态(零发现,原型 mood-healthy 隐藏解读小节)', () {
    testWidgets('小节缺席;点击按钮零 narrate 调用', (t) async {
      final narrator = _FakeNarrator();
      await pumpLoaded(
        t,
        llm: _StubLlmSettings(_readyCfg),
        narrator: narrator,
        mda: _mda(empty: true),
      );
      expect(find.text('本期诊断未发现需关注项'), findsOneWidget);
      expect(find.byKey(const ValueKey('analystNarrateButton')), findsOneWidget,
          reason: '按钮门 = ready+Loaded,与健康态无关');
      await t.tap(find.byKey(const ValueKey('analystNarrateButton')));
      await t.pump();
      expect(narrator.calls, isEmpty);
      expect(find.text('分析师解读'), findsNothing);
    });
  });
}
