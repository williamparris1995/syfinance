/// T5 financial_report_bloc 状态机测试(seam = bloc 公共 Event/State API)。
///
/// 覆盖:Initial 态、GenerateRequested 四阶段 Loading→Loaded、失败→Error、
/// Error→Retry 同期重生成(FR-8 scenario 3)、无 Error 态 Retry 忽略。
/// oracle:期望序列手写;Loaded 断言用 stub 返回的同一 doc 实例(ReportDocument
/// 无 == 契约,T4 决策「快照无相等性需求」,同实例 identical 即等)。
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/report/domain/report_assembly_service.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/presentation/financial_report_bloc.dart';

class _MockAssembly extends Mock implements ReportAssemblyService {}

/// 最小可装载 ReportDocument(数值手算,仅验证 bloc 透传原样文档)。
ReportDocument _doc(ReportPeriod period) => ReportDocument(
      period: period,
      generatedAt: DateTime.utc(2026, 9, 1),
      overview: OverviewSection.create(
        netWorthStartCents: 28645000,
        netWorthEndCents: 30128000,
        incomeCents: 3250000,
        expenseCents: 1767000,
        cashDeltaCents: 853000,
        notes: const [],
      ),
      balanceSheet: const BalanceSheetSection(
        assets: [],
        liabilities: [],
        changes: [],
      ),
      incomeStatement: const IncomeStatementSection(
        income: [],
        expense: [],
        dailyAvgCents: 57000,
      ),
      cashFlow: CashFlowSection(
        operating:
            ActivityFlow.create(inflowCents: 3250000, outflowCents: 1697000),
        investing: ActivityFlow.create(inflowCents: 0, outflowCents: 500000),
        financing: ActivityFlow.create(inflowCents: 0, outflowCents: 200000),
        netDeltaCents: 853000,
        reconciled: true,
      ),
      excludedSections: const [],
    );

/// 把 mock 的 onPhase 命名参数取出并逐阶段回调(mocktail 不支持直接
/// 捕获类型化闭包,经 Invocation.namedArguments 取 Symbol('onPhase'))。
void Function(ReportPhase)? _onPhaseOf(Invocation inv) =>
    inv.namedArguments[const Symbol('onPhase')]
        as void Function(ReportPhase)?;

void main() {
  late _MockAssembly assembly;
  // bloc 契约:Error 固定中文文案(测试即钉死该文案)。
  const errMessage = '报告生成失败,请重试';
  const period = ReportMonthly(2026, 8);

  // 同实例传递:stub 返回与 expect 断言共用(ReportDocument 无 ==,靠
  // identical 判等)。跨用例复用,setUp 重置。
  ReportDocument? sharedDoc;

  setUpAll(() {
    registerFallbackValue(period);
  });

  setUp(() {
    sharedDoc = null;
    assembly = _MockAssembly();
  });

  blocTest<FinancialReportBloc, FinancialReportState>(
    'initial state is FinancialReportInitial',
    build: () => FinancialReportBloc(assembly),
    expect: () => const <FinancialReportState>[],
    verify: (b) => expect(b.state, isA<FinancialReportInitial>()),
  );

  blocTest<FinancialReportBloc, FinancialReportState>(
    'GenerateRequested emits four Loading phases in order then Loaded',
    build: () {
      sharedDoc = _doc(period);
      when(() => assembly.generate(any(), onPhase: any(named: 'onPhase')))
          .thenAnswer((inv) async {
        final onPhase = _onPhaseOf(inv);
        for (final p in ReportPhase.values) {
          onPhase?.call(p);
        }
        return sharedDoc!;
      });
      return FinancialReportBloc(assembly);
    },
    act: (b) => b.add(const GenerateRequested(period)),
    expect: () => <FinancialReportState>[
      const FinancialReportLoading(ReportPhase.loadingLedger, period),
      const FinancialReportLoading(ReportPhase.replaying, period),
      const FinancialReportLoading(ReportPhase.assembling, period),
      const FinancialReportLoading(ReportPhase.performance, period),
      FinancialReportLoaded(sharedDoc!),
    ],
  );

  blocTest<FinancialReportBloc, FinancialReportState>(
    'GenerateRequested failure emits Loading then Error with period',
    build: () {
      when(() => assembly.generate(any(), onPhase: any(named: 'onPhase')))
          .thenAnswer((inv) async {
        _onPhaseOf(inv)?.call(ReportPhase.loadingLedger);
        throw StateError('boom');
      });
      return FinancialReportBloc(assembly);
    },
    act: (b) => b.add(const GenerateRequested(period)),
    expect: () => const <FinancialReportState>[
      FinancialReportLoading(ReportPhase.loadingLedger, period),
      FinancialReportError(errMessage, period),
    ],
  );

  blocTest<FinancialReportBloc, FinancialReportState>(
    'Retry after Error regenerates the same period (FR-8 scenario 3)',
    build: () {
      sharedDoc = _doc(period);
      var calls = 0;
      when(() => assembly.generate(any(), onPhase: any(named: 'onPhase')))
          .thenAnswer((inv) async {
        calls++;
        final onPhase = _onPhaseOf(inv);
        if (calls == 1) {
          onPhase?.call(ReportPhase.loadingLedger);
          throw StateError('boom');
        }
        for (final p in ReportPhase.values) {
          onPhase?.call(p);
        }
        return sharedDoc!;
      });
      return FinancialReportBloc(assembly);
    },
    act: (b) => b
      ..add(const GenerateRequested(period))
      ..add(const RetryRequested()),
    expect: () => <FinancialReportState>[
      const FinancialReportLoading(ReportPhase.loadingLedger, period),
      const FinancialReportError(errMessage, period),
      const FinancialReportLoading(ReportPhase.loadingLedger, period),
      const FinancialReportLoading(ReportPhase.replaying, period),
      const FinancialReportLoading(ReportPhase.assembling, period),
      const FinancialReportLoading(ReportPhase.performance, period),
      // 同一 doc 实例由 stub 返回;Loaded 透传原样文档(identical 等)。
      FinancialReportLoaded(sharedDoc!),
    ],
  );

  blocTest<FinancialReportBloc, FinancialReportState>(
    'Retry outside Error state is ignored (no emission)',
    build: () => FinancialReportBloc(assembly),
    act: (b) => b.add(const RetryRequested()),
    expect: () => const <FinancialReportState>[],
    verify: (b) => expect(b.state, isA<FinancialReportInitial>()),
  );
}
