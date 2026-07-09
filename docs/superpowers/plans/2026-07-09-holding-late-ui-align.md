# Holding 后期 4 项 UI 对齐 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 holding 4 个页面(performance / security / trade_sheet / holdings)的后期视觉差距对齐 OD 原型,纯 client 改动。

**Architecture:** 4 个独立 Task,各改一个 page 的 presentation 层。复用现有 bloc/state(`PerformanceLoaded` / `HoldingLoaded.lastPriceSyncedAt` / `RefreshPricesRequested`),不碰 server/proto。每项 TDD:widget test → 实现 → 跑 → commit。

**Tech Stack:** Flutter + flutter_bloc + mocktail(test)+ lucide_icons + 御财设计语言(`AppColors`:accent #B08D57 金 / positive #2D8A6E 绿 / negative #C4544D 红 / accentSoft #F3ECDD / muted #7A7770 / border #E6E3DC)

## Global Constraints
1. 分支 `holding-asset-management`(不新建 worktree)
2. 纯 client:不碰 server/proto/ent/wire
3. 复用第一:不重复现有 widget;色值用 `AppColors`,split 蓝灰(#6B7A8F)加局部 const
4. 多币种不硬编码(bench-mini 基准对比为 %,不涉币种)
5. English 结构化日志(本期纯 UI 基本无新日志)
6. `flutter analyze` 基线 22 error(全 pbserver)+ 3 预存 fail(account/debt/transaction_detail_page,非本 plan 引入)
7. 每 task commit(中文 conventional `feat(holding-late-align): ...`)
8. 路由不改(holding 路由已接入)
9. widget test 用 mocktail(`Mock`/`Fake`);`pump` 非 `pumpAndSettle`(有永不完成 Future);照 `test/holding/presentation/pages/holdings_page_test.dart` 现有 mock 模式
10. `PerfPoint` 字段为 `time`(DateTime)+ `value`(double),定义于 `holding/presentation/widgets/perf_curve_chart.dart`

---

## File Structure

| Task | 改动文件 | 新建 test | 责任 |
|------|---------|----------|------|
| 1 bench-mini | `performance_page.dart`(_annualCard 内加 `_BenchmarkMiniBar`) | `test/holding/presentation/pages/performance_page_test.dart` | ⑤ 基准对比中线条 + 超额 |
| 2 provider bar | `security_page.dart`(`_SyncDisabledBanner` → `_ProviderBar`) | `test/holding/presentation/pages/security_page_test.dart` | 行情源只读 chip + 同步时间 + 刷新 |
| 3 trade 色 | `trade_sheet_page.dart`(`_TypeChip`/`_livePreview`/split const) | `test/holding/presentation/pages/trade_sheet_page_test.dart` | 4 类型类型色 |
| 4 desk-grid | `holdings_page.dart`(主 build LayoutBuilder 断点) | `test/holding/presentation/pages/holdings_page_test.dart`(扩展) | desktop 饼图‖表 并排 |

## Test 基建(mock repo + 真实 bloc — 御财惯例,照 holdings_page_test.dart)

> ⚠️ **御财 widget test 不 mock Bloc**,而是 mock `Repository` + 用**真实 Bloc**(驱动真实状态机)。下方各 Task Step 1 的 test 代码块**仅示断言意图**(find/expect),其 `MockHoldingBloc`/`_holdingLoaded()` 等为示意 — **实际实现用本节 `_harness`**(mock repo + 真实 HoldingBloc + FakeCurrencyBloc + `_holding` fixture),代码照 `test/holding/presentation/pages/holdings_page_test.dart:27-83`。

```dart
class _MockRepo extends Mock implements HoldingRepository {}
class _FakeCurrencyBloc extends Fake implements CurrencyBloc {
  _FakeCurrencyBloc(this._state);
  final CurrencyState _state;
  @override CurrencyState get state => _state;
  @override Stream<CurrencyState> get stream => Stream.value(_state);
}
// _holding(...) fixture 照 holdings_page_test.dart:39-65

Widget _harness(List<Holding> holdings, {required Widget child}) {
  final repo = _MockRepo();
  registerFallbackValue(const LoadHoldingsRequested());
  when(() => repo.listHoldings(accountId: any(named: 'accountId')))
      .thenAnswer((_) async => dartz.Right(holdings));
  return MaterialApp(home: MultiBlocProvider(
    providers: [
      BlocProvider<HoldingBloc>(create: (_) => HoldingBloc(repo)),
      BlocProvider<CurrencyBloc>.value(value: _FakeCurrencyBloc(const CurrencyState())),
    ],
    child: child, // const PerformancePage()/SecurityPage()/TradeSheetPage(...)/HoldingsPage()
  ));
}
```

- **Task 1 performance_page**:harness 额外加 `BlocProvider<PerformanceBloc>`(mock `PerformanceRepository` + 真实 `PerformanceBloc`;implementer 确认其构造依赖,照 mock repo 模式)
- **Task 2/3**:harness 仅 `HoldingBloc(repo)`(security/trade_sheet 页只 HoldingBloc)
- 响应式断点:`tester.view.physicalSize = Size(1440, 900)` / `Size(400, 900)` + `devicePixelRatio = 1.0` + `addTearDown(tester.view.resetPhysicalSize)`
- `pump()` 非 `pumpAndSettle`(fl_chart / 永不完成 Future)

---

## Task 1: performance bench-mini(基准对比条)

**Files:**
- Modify: `yucai/client/lib/holding/presentation/pages/performance_page.dart`(`_annualCard` 内,累计行后插入)
- Test: `yucai/client/test/holding/presentation/pages/performance_page_test.dart`(新建)

**Interfaces:**
- Consumes: `PerformanceLoaded.performance`(`PortfolioPerformance`:`annualizedPct` double / `benchmarkPoints` `List<PerfPoint>` / `benchmarkName` String),`PerfPoint.time`/`.value`
- Produces: 私有 `_BenchmarkMiniBar` widget(同文件,参数 `myAnnualized`/`benchmarkPoints`/`benchmarkName`),ValueKey `benchmarkMiniBar`

- [ ] **Step 1: 写失败 test**

`test/holding/presentation/pages/performance_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_state.dart';
import 'package:yucai_client/holding/presentation/bloc/performance_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/performance_state.dart';
import 'package:yucai_client/holding/presentation/pages/performance_page.dart';
import 'package:yucai_client/holding/domain/entities/performance_entity.dart';
import 'package:yucai_client/holding/presentation/widgets/perf_curve_chart.dart' show PerfPoint;

import '../../../helpers/mock_holding_bloc.dart'; // 照 holdings_page_test 模式

class _MockPerfBloc extends Mock implements PerformanceBloc {}

void main() {
  testWidgets('bench-mini 渲染:有 benchmarkPoints → 中线条 + 超额', (tester) async {
    final hBloc = MockHoldingBloc();
    final pBloc = _MockPerfBloc();
    when(() => hBloc.state).thenReturn(_holdingLoaded());
    when(() => pBloc.state).thenReturn(PerformanceLoaded(performance: PortfolioPerformance(
      realizedCents: 100, unrealizedCents: 200, totalCents: 300,
      annualizedPct: 12.3, totalPct: 8.0,
      benchmarkName: '沪深300',
      benchmarkPoints: [
        PerfPoint(time: DateTime(2026, 1, 1), value: 100),
        PerfPoint(time: DateTime(2026, 7, 1), value: 105.4),
      ],
    )));
    await tester.pumpWidget(MaterialApp(
      home: MultiBlocProvider(providers: [
        BlocProvider<HoldingBloc>.value(value: hBloc),
        BlocProvider<PerformanceBloc>.value(value: pBloc),
      ], child: const PerformancePage()),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('benchmarkMiniBar')), findsOneWidget);
    expect(find.text('+12.3%'), findsWidgets);       // 我的年化
    expect(find.textContaining('超额'), findsOneWidget);
  });

  testWidgets('bench-mini 降级:无 benchmarkPoints → 不渲染超额', (tester) async {
    final hBloc = MockHoldingBloc();
    final pBloc = _MockPerfBloc();
    when(() => hBloc.state).thenReturn(_holdingLoaded());
    when(() => pBloc.state).thenReturn(PerformanceLoaded(performance: PortfolioPerformance(
      realizedCents: 0, unrealizedCents: 0, totalCents: 0,
      annualizedPct: 5.0, benchmarkPoints: const [],
    )));
    await tester.pumpWidget(MaterialApp(
      home: MultiBlocProvider(providers: [
        BlocProvider<HoldingBloc>.value(value: hBloc),
        BlocProvider<PerformanceBloc>.value(value: pBloc),
      ], child: const PerformancePage()),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('benchmarkMiniBar')), findsOneWidget);
    expect(find.textContaining('超额'), findsNothing);
  });
}

HoldingLoaded _holdingLoaded() => HoldingLoaded(
  holdings: const [], securities: const [],
  summary: _Summary(), typeFilter: null,
);
// _holdingLoaded 字段照 HoldingLoaded 实际构造(implementer 按现有 fixture 调整)
```
> 注:`MockHoldingBloc` / `_holdingLoaded` 照 `holdings_page_test.dart` 现有 helper/fixture。`PerformanceLoaded`/`HoldingLoaded` 构造参数以实际为准。

- [ ] **Step 2: 跑 test 确认 fail**

Run: `cd yucai/client && flutter test test/holding/presentation/pages/performance_page_test.dart`
Expected: FAIL(`benchmarkMiniBar` not found — `_BenchmarkMiniBar` 未实现)

- [ ] **Step 3: 实现 `_BenchmarkMiniBar`**

在 `performance_page.dart` 文件末尾(私有 widget 区)加:
```dart
/// ⑤ 基准对比 mini 条(对齐 OD .bench-mini):我的组合 vs 基准 中线对比 + 超额。
/// 数据:myAnnualized(server annualizedPct)+ benchmarkPoints(纯前端近似累计%/年化)。
/// benchmarkPoints < 2 → 降级(只显我的年化,无超额)。
class _BenchmarkMiniBar extends StatelessWidget {
  const _BenchmarkMiniBar({
    required this.myAnnualized,
    required this.benchmarkPoints,
    required this.benchmarkName,
  });
  final double myAnnualized;
  final List<PerfPoint> benchmarkPoints;
  final String benchmarkName;

  @override
  Widget build(BuildContext context) {
    final hasBench = benchmarkPoints.length >= 2;
    final name = benchmarkName.isNotEmpty ? benchmarkName : '沪深300';
    return Container(
      key: const ValueKey('benchmarkMiniBar'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(LucideIcons.barChart3, size: 13, color: AppColors.muted),
            const SizedBox(width: 5),
            Text('对比基准 $name · 近似',
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ]),
          const SizedBox(height: 8),
          _row('我的组合', myAnnualized, isMine: true),
          if (hasBench) ...[
            const SizedBox(height: 6),
            _row(name, _benchAnnualized(), isMine: false),
            const SizedBox(height: 6),
            _deltaRow(),
          ],
        ],
      ),
    );
  }

  double _benchCumulative() {
    final first = benchmarkPoints.first.value;
    final last = benchmarkPoints.last.value;
    return first != 0 ? (last - first) / first * 100 : 0.0;
  }

  double _benchAnnualized() {
    final cum = _benchCumulative();
    final days = benchmarkPoints.last.time.difference(benchmarkPoints.first.time).inDays;
    final years = days / 365;
    return years < 1 ? cum : cum / years; // 年数 < 1 不放大(避免短期失真)
  }

  Widget _deltaRow() {
    final delta = myAnnualized - _benchAnnualized();
    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Row(children: [
        const Text('超额', style: TextStyle(fontSize: 11, color: AppColors.muted)),
        const Spacer(),
        Text(
          '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: delta >= 0 ? AppColors.positive : AppColors.negative,
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
      ]),
    );
  }

  Widget _row(String label, double pct, {required bool isMine}) {
    final pos = pct >= 0;
    final fill = isMine ? (pos ? AppColors.accent : AppColors.negative) : AppColors.muted;
    final valColor = pos ? AppColors.positive : AppColors.negative;
    return Row(children: [
      SizedBox(width: 56, child: Text(label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted))),
      const SizedBox(width: 6),
      Expanded(child: _track(pos, pct.abs(), fill)),
      const SizedBox(width: 6),
      SizedBox(width: 52, child: Text(
        '${pos ? '+' : ''}${pct.toStringAsFixed(1)}%',
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: valColor, fontFeatures: AppTypography.tabularFigures),
      )),
    ]);
  }

  /// 中线对比条:track 底 + 中线(mid)+ fill 从中线向右(pos)/左(neg)。
  Widget _track(bool pos, double absPct, Color fill) {
    final w = (absPct.clamp(0, 50) / 100); // fill 占 track 宽比例(最大 50%)
    return LayoutBuilder(builder: (ctx, c) {
      final mid = c.maxWidth / 2;
      final fillW = w * c.maxWidth;
      return SizedBox(
        height: 8,
        child: Stack(children: [
          // track 底
          Positioned.fill(child: Container(
            decoration: BoxDecoration(color: AppColors.bg,
                borderRadius: BorderRadius.circular(4)),
          )),
          // 中线
          Positioned(left: mid - 0.5, top: 0, bottom: 0,
              child: Container(width: 1, color: AppColors.border)),
          // fill:pos 从中线右,neg 从中线左
          Positioned(
            left: pos ? mid : mid - fillW,
            top: 0, bottom: 0, width: fillW,
            child: Container(color: fill),
          ),
        ]),
      );
    });
  }
}
```

在 `_annualCard` 内,累计 `_annualRow(...)` 之后插入(loaded 非 null 时):
```dart
// ⑤ bench-mini(loaded 有数据时渲染;无 benchmarkPoints 内部降级)。
if (loaded != null && loaded.annualizedPct != 0)
  _BenchmarkMiniBar(
    myAnnualized: loaded.annualizedPct,
    benchmarkPoints: loaded.benchmarkPoints,
    benchmarkName: loaded.benchmarkName,
  ),
```

- [ ] **Step 4: 跑 test 确认 pass**

Run: `cd yucai/client && flutter test test/holding/presentation/pages/performance_page_test.dart`
Expected: PASS(2 tests)

- [ ] **Step 5: Commit**

```bash
cd yucai/client
git add lib/holding/presentation/pages/performance_page.dart test/holding/presentation/pages/performance_page_test.dart
git commit -m "feat(holding-late-align): performance bench-mini 基准对比条+超额(⑤)"
```

---

## Task 2: security provider bar(行情源 + 同步状态)

**Files:**
- Modify: `yucai/client/lib/holding/presentation/pages/security_page.dart`(`_SyncDisabledBanner` → `_ProviderBar`,line 345-395)
- Test: `yucai/client/test/holding/presentation/pages/security_page_test.dart`(新建)

**Interfaces:**
- Consumes: `HoldingLoaded.lastPriceSyncedAt`(DateTime?)+ `RefreshPricesRequested`(event)+ `HoldingBloc`(security_page 已 `BlocProvider<HoldingBloc>`)
- Produces: 私有 `_ProviderBar` widget,ValueKey `providerBar`;行情源常量 `新浪财经`(client 硬编码,对齐 server `price_history.Source="sina"`)

- [ ] **Step 1: 写失败 test**

`test/holding/presentation/pages/security_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_event.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_state.dart';
import 'package:yucai_client/holding/presentation/pages/security_page.dart';

import '../../../helpers/mock_holding_bloc.dart';

void main() {
  testWidgets('provider bar:显示新浪 + 同步时间 + 刷新触发 RefreshPricesRequested',
      (tester) async {
    final bloc = MockHoldingBloc();
    final syncedAt = DateTime(2026, 7, 9, 15, 0);
    when(() => bloc.state).thenReturn(_loaded(syncedAt));
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<HoldingBloc>.value(
        value: bloc, child: const SecurityPage()),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('providerBar')), findsOneWidget);
    expect(find.textContaining('新浪财经'), findsOneWidget);
    expect(find.byKey(const ValueKey('providerRefresh')), findsOneWidget);
    // 无 Switch(已去掉)
    expect(find.byType(Switch), findsNothing);
    // 触发刷新
    await tester.tap(find.byKey(const ValueKey('providerRefresh')));
    verify(() => bloc.add(const RefreshPricesRequested())).called(1);
  });
}

HoldingLoaded _loaded(DateTime? synced) => HoldingLoaded(
  holdings: const [], securities: const [],
  summary: _Summary(), typeFilter: null, lastPriceSyncedAt: synced,
);
```
> 注:`HoldingLoaded` 构造 + `_Summary` fixture 照 `holdings_page_test.dart`;`MockHoldingBloc` 现有 helper。`bloc.add` 验证需 `registerFallbackValue` / `verify` — 照现有 bloc test 模式。

- [ ] **Step 2: 跑 test 确认 fail**

Run: `cd yucai/client && flutter test test/holding/presentation/pages/security_page_test.dart`
Expected: FAIL(`providerBar` not found)

- [ ] **Step 3: 实现 `_ProviderBar`**

替换 `security_page.dart` 的 `_SyncDisabledBanner`(line 345-395)为:
```dart
/// 行情源 + 同步状态条(对齐 OD provider bar)。
/// server B-sync 已实现(scheduler + SinaProvider + SyncPrices),provider 链
/// 固定(client 不可选)→ 行情源只读 chip「新浪财经」+ 上次同步时间 + 手动刷新。
class _ProviderBar extends StatelessWidget {
  const _ProviderBar();

  static const _providerName = '新浪财经'; // 对齐 server price_history.Source="sina"

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HoldingBloc>().state;
    final synced = state is HoldingLoaded ? state.lastPriceSyncedAt : null;
    final syncing = state is HoldingSubmitting;
    return Container(
      key: const ValueKey('providerBar'),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        border: Border.all(color: AppColors.accentSoft),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(children: [
        const Icon(LucideIcons.globe, size: 16, color: AppColors.accentHover),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(TextSpan(children: [
                const TextSpan(text: '自动同步 · 行情源 ',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                TextSpan(text: _providerName,
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w600,
                        color: AppColors.accentHover)),
              ])),
              Text(synced == null ? '尚未同步' : '上次同步 ${_fmtTime(synced)}',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('providerRefresh'),
          tooltip: '刷新价格',
          onPressed: syncing
              ? null
              : () => context.read<HoldingBloc>().add(const RefreshPricesRequested()),
          icon: syncing
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(LucideIcons.refreshCw, size: 16, color: AppColors.accentHover),
        ),
      ]),
    );
  }

  String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }
}
```

把 `_SyncDisabledBanner()` 的调用点(主 build 内)改为 `const _ProviderBar()`。删除旧 `_SyncDisabledBanner` class。

- [ ] **Step 4: 跑 test 确认 pass**

Run: `cd yucai/client && flutter test test/holding/presentation/pages/security_page_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd yucai/client
git add lib/holding/presentation/pages/security_page.dart test/holding/presentation/pages/security_page_test.dart
git commit -m "feat(holding-late-align): security provider bar 行情源+同步时间+刷新(去 Switch)"
```

---

## Task 3: trade_sheet per-type 类型色

**Files:**
- Modify: `yucai/client/lib/holding/presentation/pages/trade_sheet_page.dart`(`_TypeSegmented._meta` + `_TypeChip`(line 820)+ `_livePreview`(line 610, amtColor + split preview))
- Test: `yucai/client/test/holding/presentation/pages/trade_sheet_page_test.dart`(新建)

**Interfaces:**
- Produces: 局部常量 `_kSplitColor = Color(0xFF6B7A8F)` / `_kSplitSoft = Color(0xFFE7EAEF)`;`_tradeTypeColor(TradeType)` / `_tradeTypeSoft(TradeType)` helper
- 色(对齐 `design-output/holding/styles.css:524-527`):buy=accent(金)/ sell=negative(红)/ dividend=positive(绿)/ split=_kSplitColor(蓝灰)

- [ ] **Step 1: 写失败 test**

`test/holding/presentation/pages/trade_sheet_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_state.dart';
import 'package:yucai_client/holding/presentation/pages/trade_sheet_page.dart';
import 'package:yucai_client/core/theme/app_design.dart';

import '../../../helpers/mock_holding_bloc.dart';

void main() {
  testWidgets('seg 选中态按类型色:buy=金', (tester) async {
    final bloc = MockHoldingBloc();
    when(() => bloc.state).thenReturn(_loaded());
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<HoldingBloc>.value(
        value: bloc,
        child: const TradeSheetPage(initialType: null)),
    ));
    await tester.pump();
    final chip = tester.widget<AnimatedContainer>(
      find.ancestor(of: find.text('买入'), matching: find.byType(AnimatedContainer)));
    final decor = chip.decoration as BoxDecoration;
    expect(decor.color, AppColors.accent); // buy=金
  });

  testWidgets('split 预览用蓝灰 soft 背景', (tester) async {
    final bloc = MockHoldingBloc();
    when(() => bloc.state).thenReturn(_loaded());
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<HoldingBloc>.value(
        value: bloc,
        child: const TradeSheetPage(initialType: null))..initialType /*=split via param */,
    ));
    // 切 split(构造 initialType: TradeType.split,见上)
    await tester.pump();
    final preview = tester.widget<Container>(find.byKey(const ValueKey('splitPreview')));
    final decor = preview.decoration as BoxDecoration;
    expect(decor.color, const Color(0xFFE7EAEF)); // split-soft
  });
}

HoldingLoaded _loaded() => HoldingLoaded(holdings: const [], securities: const [], summary: _Summary(), typeFilter: null);
```
> 注:`TradeSheetPage` 构造含 `initialType: TradeType.buy`(默认)+ `initialSecurityId`/`initialAccountId`(seed,见 line 60-66)。split test 传 `initialType: TradeType.split`。`HoldingLoaded`/`_Summary` fixture 照现有。helper `MockHoldingBloc` 现有。

- [ ] **Step 2: 跑 test 确认 fail**

Run: `cd yucai/client && flutter test test/holding/presentation/pages/trade_sheet_page_test.dart`
Expected: FAIL(buy chip color = accent 现状是 accent?现状 selected 全 accent — buy pass,但 sell/dividend/split 也 accent,fail 在 split preview 色)

- [ ] **Step 3: 实现类型色**

`trade_sheet_page.dart` 顶部(import 后)加常量 + helper:
```dart
// OD type 色(design-output/holding/styles.css:524-527)。
const _kSplitColor = Color(0xFF6B7A8F);
const _kSplitSoft = Color(0xFFE7EAEF);

Color _tradeTypeColor(TradeType t) {
  switch (t) {
    case TradeType.buy:      return AppColors.accent;     // 金
    case TradeType.sell:     return AppColors.negative;   // 红
    case TradeType.dividend: return AppColors.positive;   // 绿
    case TradeType.split:    return _kSplitColor;         // 蓝灰
    case TradeType.unspecified: return AppColors.accent;
  }
}

Color _tradeTypeSoft(TradeType t) {
  switch (t) {
    case TradeType.buy:      return AppColors.accentSoft;
    case TradeType.sell:     return AppColors.negative.withValues(alpha: 0.10);
    case TradeType.dividend: return AppColors.positive.withValues(alpha: 0.10);
    case TradeType.split:    return _kSplitSoft;
    case TradeType.unspecified: return AppColors.accentSoft;
  }
}
```

改 `_TypeSegmented._meta`(line 794)加色,`_TypeChip` 接 `type`:
```dart
class _TypeSegmented extends StatelessWidget {
  const _TypeSegmented({required this.current, required this.onSelect});
  final TradeType current;
  final ValueChanged<TradeType> onSelect;

  @override
  Widget build(BuildContext context) {
    const labels = <TradeType, (String, IconData)>{
      TradeType.buy: ('买入', LucideIcons.arrowDownCircle),
      TradeType.sell: ('卖出', LucideIcons.arrowUpCircle),
      TradeType.dividend: ('分红', LucideIcons.coins),
      TradeType.split: ('拆分', LucideIcons.gitMerge),
    };
    return Wrap(
      spacing: AppSpacing.xs, runSpacing: AppSpacing.xs,
      children: [
        for (final t in TradeType.values)
          _TypeChip(
            key: ValueKey('typeChip-${t.name}'),
            type: t,
            label: labels[t]!.$1, icon: labels[t]!.$2,
            selected: t == current,
            onTap: () => onSelect(t),
          ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    super.key,
    required this.type,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final TradeType type;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _tradeTypeColor(type);
    final bg = selected ? color : AppColors.surface;
    final fg = selected ? Colors.white : AppColors.muted;
    final border = selected ? color : AppColors.border;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              color: fg, fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}
```

改 `_livePreview` 的 `amtColor`(line 639-643)+ split preview(line 611-630):
```dart
// amtColor:类型色(对齐 OD amt-row.t-{type})。
final amtColor = _tradeTypeColor(_type);
```
split preview 容器(line 613-619)改:
```dart
return Container(
  key: const ValueKey('splitPreview'),
  padding: const EdgeInsets.all(AppSpacing.md),
  decoration: BoxDecoration(
    color: _kSplitSoft,                    // split-soft(原 accentSoft)
    borderRadius: BorderRadius.circular(8),
  ),
  child: Row(children: [
    Icon(LucideIcons.info, size: 16, color: _kSplitColor),  // split 色(原 accent)
    const SizedBox(width: 8),
    const Expanded(
      child: Text('无现金流 · 仅调整持有量与成本',
          style: TextStyle(fontSize: 12, color: AppColors.muted)),
    ),
  ]),
);
```
> 注:`_balanceRow`(余额 fail-fast)维持资金流向色(positive/negative),不改。

- [ ] **Step 4: 跑 test 确认 pass**

Run: `cd yucai/client && flutter test test/holding/presentation/pages/trade_sheet_page_test.dart`
Expected: PASS(2 tests)

- [ ] **Step 5: Commit**

```bash
cd yucai/client
git add lib/holding/presentation/pages/trade_sheet_page.dart test/holding/presentation/pages/trade_sheet_page_test.dart
git commit -m "feat(holding-late-align): trade per-type 类型色(seg+amount+split 蓝灰)"
```

---

## Task 4: holdings desktop desk-grid(饼图‖表 并排)

**Files:**
- Modify: `yucai/client/lib/holding/presentation/pages/holdings_page.dart`(主 build,`SingleChildScrollView` 内 Column,line 186-237)
- Test: `yucai/client/test/holding/presentation/pages/holdings_page_test.dart`(扩展)

**Interfaces:**
- Consumes: 现有 `_AllocCard`(饼图,line 208)/ `_ChipsRow` / `_SectionHead` / `_HoldingList`(表,line 221)
- Produces: desktop(≥1024)时饼图 + 持仓表组 并排(Row:饼图 320 + 表 Expanded);窄屏维持单列堆叠

- [ ] **Step 1: 写失败 test**

在 `test/holding/presentation/pages/holdings_page_test.dart` 加:
```dart
testWidgets('desktop:饼图与持仓表并排(desk-grid)', (tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  final bloc = MockHoldingBloc();
  when(() => bloc.state).thenReturn(_loadedWithHoldings()); // 现有 fixture
  await tester.pumpWidget(MaterialApp(
    home: BlocProvider<HoldingBloc>.value(
        value: bloc, child: const HoldingsPage()),
  ));
  await tester.pump();
  // desktop:AllocCard 与 HoldingList 同 Row(并排)
  final allocRow = tester.widget<Row>(find.ancestor(
    of: find.byType(/* _AllocCard — expose key */ find.byKey(const ValueKey('allocCard'))),
    matching: find.byType(Row)).first);
  expect(allocRow, isNotNull);
});

testWidgets('窄屏:饼图与持仓表堆叠(单列)', (tester) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  final bloc = MockHoldingBloc();
  when(() => bloc.state).thenReturn(_loadedWithHoldings());
  await tester.pumpWidget(MaterialApp(
    home: BlocProvider<HoldingBloc>.value(
        value: bloc, child: const HoldingsPage()),
  ));
  await tester.pump();
  // 窄屏:AllocCard 与 HoldingList 不在同 Row(堆叠)
  final sameRow = find.ancestor(
    of: find.byKey(const ValueKey('allocCard')),
    matching: find.ancestor(of: find.byKey(const ValueKey('holdingList')), matching: find.byType(Row)));
  expect(sameRow, findsNothing);
});
```
> 注:`_loadedWithHoldings` 照现有 fixture(至少 1 holding + slice)。需给 `_AllocCard`/`_HoldingList` 加 ValueKey `allocCard`/`holdingList`(Step 3)。

- [ ] **Step 2: 跑 test 确认 fail**

Run: `cd yucai/client && flutter test test/holding/presentation/pages/holdings_page_test.dart`
Expected: FAIL(desk-grid 并排未实现,allocCard/holdingList 无 key 或不同 Row)

- [ ] **Step 3: 实现 desk-grid 断点**

`holdings_page.dart` 主 build(line 186-237)的 Column children,把 `_AllocCard` + 持仓表组(`_ChipsRow`/`_SectionHead`/`_HoldingList`)包成响应式并排。给 `_AllocCard` 加 `key: const ValueKey('allocCard')`,`_HoldingList` 加 `key: const ValueKey('holdingList')`。

替换 line 207-225(`_AllocCard` ... `_HoldingList`)为:
```dart
// desk-grid:desktop(≥1024)饼图‖持仓表 并排;窄屏堆叠(对齐 OD .desk-grid 320px 1fr)。
LayoutBuilder(builder: (ctx, c) {
  final isDesktop = c.maxWidth >= 1024;
  final pie = _AllocCard(
    key: const ValueKey('allocCard'),
    slices: _slicesByType(loaded.holdings, toPreferred),
  );
  final tableGroup = Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ChipsRow(
        holdings: loaded.holdings,
        active: loaded.typeFilter,
        onSelect: (t) => context
            .read<HoldingBloc>()
            .add(LoadHoldingsRequested(typeFilter: t)),
      ),
      const SizedBox(height: AppSpacing.sm),
      _SectionHead(count: loaded.holdings.length),
      const SizedBox(height: AppSpacing.sm),
      _HoldingList(
        key: const ValueKey('holdingList'),
        holdings: _filtered(loaded),
        preferred: preferred,
        toPreferred: toPreferred,
      ),
    ],
  );
  if (!isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [pie, const SizedBox(height: AppSpacing.lg), tableGroup],
    );
  }
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 320, child: pie),
      const SizedBox(width: AppSpacing.lg),
      Expanded(child: tableGroup),
    ],
  );
}),
```
> 注:原 `_AllocCard` 后的 `SizedBox(height: AppSpacing.lg)` + `_ChipsRow` 段被并入 tableGroup;删除原散落行。`_StatGrid`(4 横排 desktop)维持不动。

- [ ] **Step 4: 跑 test 确认 pass**

Run: `cd yucai/client && flutter test test/holding/presentation/pages/holdings_page_test.dart`
Expected: PASS(含新增 2 + 现有)

- [ ] **Step 5: Commit**

```bash
cd yucai/client
git add lib/holding/presentation/pages/holdings_page.dart test/holding/presentation/pages/holdings_page_test.dart
git commit -m "feat(holding-late-align): holdings desktop desk-grid 饼图‖持仓表并排"
```

---

## 全量验证(plan 完成后)

- [ ] `cd yucai/client && flutter analyze`(基线 22 error,无新增)
- [ ] `cd yucai/client && flutter test`(3 预存 fail 不变,新增 4 文件全 pass)
- [ ] `cd yucai/client && flutter build windows --debug`(编译绿)
