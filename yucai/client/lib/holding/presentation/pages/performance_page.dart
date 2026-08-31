// 收益统计页(Task 9)。组合层面:总收益曲线 + realized/unrealized 分解 +
// 年化 + 持仓/类型贡献条。
//
// 消费 Task 4 HoldingBloc(LoadHoldingsRequested → HoldingLoaded
// (holdings + HoldingSummary + securities))。本页 initState dispatch
// LoadHoldingsRequested() 以确保 holdings 就绪(列表页若先访问则 bloc 复用)。
//
// 对齐 A-od 设计源 performance-{desktop,tablet,mobile}.html(6 组件):
//   ① 概览头(总收益 CNY + 收益率 pill + 成本/市值 sub)
//   ② 总收益曲线(PerfCurveChart · 日/月/年 tab · foot 浮动/已实现/总收益)
//   ③ 收益分解(realized/unrealized 条 + 图例)
//   ④ 年化收益率(累计 + 年化近似 + ⏳C 基准占位)
//   ⑤ 持仓贡献(按 holding · unrealized 占比 · 正绿负红)
//   ⑥ 类型贡献(按 SecurityType 聚合 · unrealized 占比)
//
// 复用 Task 8 的 PerfCurveChart / PerfRange / PerfPoint / PerfCurveFoot
// (见 widgets/perf_curve_chart.dart)。
//
// ⏳C 降级(proto 无 snapshot/price history/跨持仓 trades RPC):
//   - **总收益曲线**:行情 snapshot ⏳C 无 RPC → 空态(PerfCurveChart 自带
//     「⏳ 行情快照待后端」,brief:或前端从 holdings 近似;此处按 brief
//     ⏳C 降级 —— 曲线数据为空 → 空态 + "⏳C 待后端")。foot 仍渲染(从
//     holdings 算的 unrealized/realized 近似)。
//   - **unrealized** = Σ holding.unrealizedPnlCents(✅ proto 已给,有数据)。
//   - **realized** 需跨持仓 trades 聚合(每 holding 各自 listHoldingTransactions,
//     proto 无组合级 trades RPC)→ ⏳C 空态 + "⏳C 待后端"标注(brief 指定)。
//   - **年化**:从持仓时长近似(数据缺时占位;基准 mock ⏳C)。
//   - **贡献条**:按 holding / SecurityType 的 unrealized 占比(✅ 有数据)。
//
// 无 i18n(中文硬编码,对齐 Task 8 + brief)。金额 cents 格式化。
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_event.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_state.dart';
import 'package:yucai_client/holding/presentation/bloc/performance_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/performance_event.dart';
import 'package:yucai_client/holding/presentation/bloc/performance_state.dart';
import 'package:yucai_client/holding/presentation/widgets/holding_module_tabs.dart';
import 'package:yucai_client/holding/presentation/widgets/holding_pie_chart.dart';
import 'package:yucai_client/holding/presentation/widgets/perf_curve_chart.dart';

/// PerfRange enum → 大写英文串('DAY'/'MONTH'/'YEAR')。
///
/// **关键约束**:bloc/repo range 参数必须是大写英文串(mapper curveRangeToProto
/// 按此映射,未知折叠 DAY)。**不能传 PerfRange.label**(中文 '日/月/年')。
/// performance_page / holding_detail_page range tab 切换时经此函数转换。
String rangeName(PerfRange r) {
  switch (r) {
    case PerfRange.day:
      return 'DAY';
    case PerfRange.month:
      return 'MONTH';
    case PerfRange.year:
      return 'YEAR';
  }
}

/// 收益统计页。对齐 A-od performance-*.html。
class PerformancePage extends StatefulWidget {
  const PerformancePage({super.key});

  @override
  State<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends State<PerformancePage> {
  /// 总收益曲线区间(本页内联切换;复用 PerfCurveChart 的 日/月/年 tab)。
  /// 切换时同时派发 LoadPortfolioPerformanceRequested(range 大写串)重拉曲线。
  PerfRange _curveRange = PerfRange.day;

  /// 折算本位币(Task 12 D-currency)。从 CurrencySettings.getBaseCurrency()
  /// 异步读(CNY default);resolve 后 dispatch 组合收益曲线(透传 base 到
  /// proto base_currency)。HoldingBloc 列表加载与 baseCurrency 无关(前端
  /// 聚合 unrealized 不折算),故立即 dispatch。
  final CurrencySettings _currencySettings = getIt<CurrencySettings>();
  String _baseCurrency = '';

  @override
  void initState() {
    super.initState();
    // 确保持仓列表就绪(贡献/概览头用,前端聚合;列表页先访问则 bloc 复用)。
    context.read<HoldingBloc>().add(const LoadHoldingsRequested());
    // 折算本位币解析后再 dispatch 组合收益曲线(base 透传到 server)。
    _loadPortfolio();
    _currencySettings.listenable.addListener(_onBaseChanged);
  }

  /// 读 CurrencySettings base 后 dispatch 组合收益曲线。range 默认 DAY。
  Future<void> _loadPortfolio({String range = 'DAY'}) async {
    final base = await _currencySettings.getBaseCurrency();
    if (!mounted) return;
    setState(() => _baseCurrency = base);
    if (!mounted) return;
    context.read<PerformanceBloc>().add(LoadPortfolioPerformanceRequested(
      range: range,
      baseCurrency: base,
    ));
  }

  // Cross-page refresh: base currency changed in settings → re-dispatch the
  // portfolio curve with the current range and new reporting currency.
  void _onBaseChanged() {
    if (!mounted) return;
    _loadPortfolio(range: rangeName(_curveRange));
  }

  @override
  void dispose() {
    _currencySettings.listenable.removeListener(_onBaseChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yucai.bg,
      body: Column(
        children: [
          // 模块内 tab(Task 2 HoldingModuleTabs,收益统计 active 金下划线)。
          // 固定于内容区顶部常驻,不随滚动消失(对齐 Task 3-4 holdings/security 模式)。
          const HoldingModuleTabs(),
          Expanded(
            child: BlocBuilder<HoldingBloc, HoldingState>(
              builder: (context, state) {
                if (state is HoldingLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is HoldingLoaded) {
            // 4 个 ⏳C 点(曲线/realized/年化/基准)来自 PerformanceBloc;
            // 概览头/贡献/未实现仍从 HoldingBloc 前端聚合。
            return BlocBuilder<PerformanceBloc, PerformanceState>(
              builder: (context, perf) => _body(state, perf),
            );
          }
          if (state is HoldingError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(state.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.yucai.muted)),
              ),
            );
          }
          // HoldingInitial / HoldingSubmitting(无 last)→ 空占位。
          return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── body(6 组件 + api-note) ─────────────────────────

  Widget _body(HoldingLoaded state, PerformanceState perf) {
    final isMobile = MediaQuery.of(context).size.width <= 720;
    // 组合货币:取首个 holding 的 currency(或 CNY 兜底)。多币种混合时
    // 此处展示为 holding 自身币种的 unrealized 合计(不做汇率折算,与
    // A-od toCNY 折算不同,但 brief 指明 unrealized 从 holdings 算 ✅)。
    final currency = _groupCurrency(state.holdings);
    return ListView(
      padding: isMobile
          ? const EdgeInsets.fromLTRB(16, 14, 16, 24)
          : const EdgeInsets.fromLTRB(36, 24, 36, 24),
      children: [
        _pageHead(state, currency),
        const SizedBox(height: 18),
        _statRow(state, currency, perf),
        const SizedBox(height: 18),
        _curveCard(state, currency, perf),
        const SizedBox(height: 16),
        _splitCard(state, currency, perf),
        const SizedBox(height: 16),
        _annualCard(state, currency, perf),
        const SizedBox(height: 16),
        _contribHoldingCard(state, currency),
        const SizedBox(height: 16),
        _contribTypeCard(state, currency),
        const SizedBox(height: 14),
        _apiNote(),
      ],
    );
  }

  // ───────────────────────── ① 页头(page-head + 4-stat 行)─────────────────────────

  /// 页头(对齐 OD v2 .page-head):h1 衬线「收益统计」+ sub
  /// 「总市值 ¥X · 总盈亏 ±¥X (±X%) · 基准 沪深300」。
  /// 大数字下放 _statRow 4 卡;此处仅标题 + 概要 sub(对齐 OD .page-title)。
  Widget _pageHead(HoldingLoaded state, String currency) {
    final unrealized = _sumUnrealized(state.holdings);
    final up = unrealized >= 0;
    final totalCost = state.summary.totalCostCents;
    final totalMkt = state.summary.totalMarketValueCents;
    // 收益率 = unrealized / totalCost(成本为 0 → 0%)。
    final pnlPct = totalCost > 0 ? (unrealized / totalCost) * 100 : 0.0;
    final pnlColor = up ? context.yucai.positive : context.yucai.negative;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // h1 衬线「收益统计」(对齐 OD .page-title h1 font-display serif 26px)。
        Text(
          '收益统计',
          key: ValueKey('perfHeaderLabel'),
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            fontFamily: AppTypography.displayFamily,
            fontFamilyFallback: AppTypography.displayFallback,
            color: context.yucai.fg,
            height: 1.15,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        // sub:总市值 · 总盈亏 ±¥X (±X%) · 基准 沪深300(对齐 OD .page-title .sub;
        // b 元素加粗 fg,盈亏值/pct 染绿红)。Wrap 兼容窄屏折行。
        DefaultTextStyle(
          style: TextStyle(
              fontSize: 13, color: context.yucai.muted, height: 1.6),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              const Text('总市值 '),
              Text(
                _fmtRaw(totalMkt, currency),
                key: const ValueKey('perfHeaderMv'),
                style: TextStyle(
                    color: context.yucai.fg,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTypography.tabularFigures),
              ),
              const Text('   ·   总盈亏 '),
              Text(
                _fmtSigned(unrealized, currency),
                key: const ValueKey('perfTotalPnl'),
                style: TextStyle(
                    color: pnlColor,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTypography.tabularFigures),
              ),
              const Text(' ('),
              Text(
                '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
                key: const ValueKey('perfPnlPct'),
                style: TextStyle(
                    color: pnlColor,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTypography.tabularFigures),
              ),
              const Text(')   ·   基准 沪深300'),
            ],
          ),
        ),
      ],
    );
  }

  /// 4 统计卡(对齐 OD v2 .stat-row):总市值 / 总成本 / 总盈亏(色) / 年化(中性)。
  /// 盈亏色仅「总盈亏」值与 delta;年化计数中性(brief「年化计数中性」→ fg,不染盈亏色)。
  Widget _statRow(HoldingLoaded state, String currency, PerformanceState perf) {
    final unrealized = _sumUnrealized(state.holdings);
    final up = unrealized >= 0;
    final pnlColor = up ? context.yucai.positive : context.yucai.negative;
    final totalCost = state.summary.totalCostCents;
    final totalMkt = state.summary.totalMarketValueCents;
    final pnlPct = totalCost > 0 ? (unrealized / totalCost) * 100 : 0.0;
    final loaded = perf is PerformanceLoaded ? perf.performance : null;
    // Task 7:年化降级信号现为 null(非 0);旧 `!= 0` 把缺数据的 0 误判成有效。
    final hasAnnualized = loaded != null && loaded.annualizedPct != null;
    return LayoutBuilder(
      builder: (ctx, c) {
        final isMobile = c.maxWidth < 600;
        final tiles = <Widget>[
          _statTile(
            key: const ValueKey('perfStatMv'),
            label: '总市值',
            value: _fmtRaw(totalMkt, currency),
            delta: '持仓市值合计',
          ),
          _statTile(
            key: const ValueKey('perfStatCost'),
            label: '总成本',
            value: _fmtRaw(totalCost, currency),
            delta: '持仓投入合计',
          ),
          _statTile(
            key: const ValueKey('perfStatPnl'),
            label: '总盈亏',
            value: _fmtSigned(unrealized, currency),
            valueColor: pnlColor,
            delta: '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
            deltaColor: pnlColor,
          ),
          _statTile(
            key: const ValueKey('perfStatAnnual'),
            label: '年化收益',
            value: hasAnnualized
                ? '${loaded.annualizedPct! >= 0 ? '+' : ''}${loaded.annualizedPct!.toStringAsFixed(1)}%'
                : '⏳',
            // 年化计数中性(brief):不染盈亏色,用 fg(有数据)/ muted(⏳)。
            valueColor: hasAnnualized ? context.yucai.fg : context.yucai.muted,
            delta: hasAnnualized
                ? '累计 ${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(1)}%'
                : '⏳C 待后端',
          ),
        ];
        if (isMobile) {
          // 窄屏 2×2(对齐 OD 移动端 stat-row 折行)。
          return Column(
            children: [
              for (var i = 0; i < tiles.length; i += 2) ...[
                Row(
                  children: [
                    Expanded(child: tiles[i]),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: tiles[i + 1]),
                  ],
                ),
                if (i + 2 < tiles.length)
                  const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              Expanded(child: tiles[i]),
              if (i < tiles.length - 1) const SizedBox(width: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }

  /// 单统计卡(对齐 OD .stat:label 12px muted / value 22px mono tabular /
  /// delta 12px)。FittedBox 保证窄屏长金额不溢出。
  Widget _statTile({
    required Key key,
    required String label,
    required String value,
    required String delta,
    Color? valueColor,
    Color? deltaColor,
  }) {
    return DataCard(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: context.yucai.muted)),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: valueColor ?? context.yucai.fg,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            delta,
            style: TextStyle(
              fontSize: 12,
              color: deltaColor ?? context.yucai.muted,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── ② 总收益曲线 ─────────────────────────

  /// PerfCurveChart · 日/月/年 tab · foot 浮动/已实现/总收益。
  ///
  /// Task 13 接 server 真数据:①曲线 points + ⑤基准(PerformanceLoaded)。
  /// range tab 切换 → LoadPortfolioPerformanceRequested(range 大写串)重拉。
  /// unrealized 仍从 holdings 前端聚合(组合级 ✅);realized/total 用 server
  /// 数据(PerformanceLoaded 时填,Loading/Error 走空态避免误导)。
  Widget _curveCard(HoldingLoaded state, String currency, PerformanceState perf) {
    final unrealized = _sumUnrealized(state.holdings);
    final loaded = perf is PerformanceLoaded ? perf.performance : null;
    // range tab 切换:更新本地 + 派发 PerformanceBloc 重拉曲线(带已解析的 baseCurrency)。
    void onRange(PerfRange r) {
      setState(() => _curveRange = r);
      context.read<PerformanceBloc>().add(LoadPortfolioPerformanceRequested(
        range: rangeName(r),
        baseCurrency: _baseCurrency,
      ));
    }

    return DataCard(
      child: PerfCurveChart(
        // ① 组合曲线 points(server portfolioPoints;Loading/Error → 空 → 空态)。
        points: loaded?.portfolioPoints ?? const [],
        // ⑤ 基准曲线(server benchmarkPoints;>= 2 点才显第二线 + 图例)。
        benchmarkPoints: loaded?.benchmarkPoints ?? const [],
        benchmarkName: loaded != null && loaded.benchmarkName.isNotEmpty
            ? loaded.benchmarkName
            : '沪深300',
        range: _curveRange,
        onRangeChange: onRange,
        emptyHint: '⏳C 收益快照待后端',
        foot: PerfCurveFoot(
          unrealizedCents: unrealized,
          // realized/total server 数据(无 → null 不渲染 cell,避免 0 误导)。
          realizedCents: loaded?.realizedCents,
          totalCents: loaded?.totalCents,
          currency: currency,
        ),
      ),
    );
  }

  // ───────────────────────── ③ 收益分解 ─────────────────────────

  /// realized/unrealized 分解卡(对齐 A-od split-card)。
  /// unrealized ✅ 从 holdings 算;realized Task 13 接 server 真数据
  /// (PerformanceLoaded.realizedCents)。Loading/Error 时 realized 走空态。
  Widget _splitCard(HoldingLoaded state, String currency, PerformanceState perf) {
    final unrealized = _sumUnrealized(state.holdings);
    final unreaUp = unrealized >= 0;
    final loaded = perf is PerformanceLoaded ? perf.performance : null;
    final realized = loaded?.realizedCents;
    final realizedLoaded = realized != null;
    final realUp = realizedLoaded && realized >= 0;
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('收益分解',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppTypography.displayFamily,
                          fontFamilyFallback: AppTypography.displayFallback)),
                  SizedBox(height: 2),
                  Text('已实现 + 未实现',
                      style: TextStyle(
                          fontSize: 11.5, color: context.yucai.muted)),
                ],
              ),
              if (!realizedLoaded)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.yucai.accentSoft,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text('⏳ C',
                      key: ValueKey('splitBadge'),
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: context.yucai.accentDeep)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _splitBar(unrealized, unreaUp, realized, realizedLoaded, realUp),
          const SizedBox(height: 16),
          _splitLegend(unrealized, unreaUp, currency, realized, realizedLoaded,
              realUp),
          if (!realizedLoaded) ...[
            const SizedBox(height: 14),
            // realized 未加载说明(加载中/失败/暂无数据时显示,③ realized 已接 GetPortfolioPerformance.realizedCents)。
            Container(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
              decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(
                          color: context.yucai.surfaceAlt, style: BorderStyle.solid))),
              child: Row(
                children: [
                  Icon(LucideIcons.hourglass,
                      size: 13, color: context.yucai.accent),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '已实现收益加载中或暂无数据,请稍后重试',
                      key: ValueKey('splitRealizedHint'),
                      style: TextStyle(
                          fontSize: 11.5, color: context.yucai.muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 分解条(realized + unrealized,色随正负)。
  Widget _splitBar(
      int unrealized, bool unreaUp, int? realized, bool realizedLoaded, bool realUp) {
    // 比例:|realized| / (|realized| + |unrealized|),无 realized → 0%。
    final realAbs = (realizedLoaded ? realized!.abs() : 0);
    final unreaAbs = unrealized.abs();
    final total = realAbs + unreaAbs;
    final realFlex = total == 0 ? 0 : (realAbs / total * 100).round();
    return Container(
      height: 14,
      decoration: BoxDecoration(
        color: context.yucai.bg,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: context.yucai.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9999),
        child: Row(
          children: [
            if (realFlex > 0)
              Expanded(
                flex: realFlex,
                child: Container(
                  key: const ValueKey('splitBarRealized'),
                  color: context.yucai.accent,
                ),
              ),
            Expanded(
              flex: 100 - realFlex,
              child: Container(
                key: const ValueKey('splitBarUnrealized'),
                color: unreaUp ? context.yucai.positive : context.yucai.negative,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _splitLegend(int unrealized, bool unreaUp, String currency,
      int? realized, bool realizedLoaded, bool realUp) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: realizedLoaded
                            ? context.yucai.accent
                            : context.yucai.accent.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 6),
                  Text('已实现',
                      style:
                          TextStyle(fontSize: 11, color: context.yucai.muted)),
                ],
              ),
              const SizedBox(height: 4),
              realizedLoaded
                  ? Text(_fmtSigned(realized!, currency),
                      key: const ValueKey('splitRealizedVal'),
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: realUp
                              ? context.yucai.positive
                              : context.yucai.negative,
                          fontFeatures: AppTypography.tabularFigures))
                  : Text('⏳C 待后端',
                      key: ValueKey('splitRealizedVal'),
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: context.yucai.accentDeep,
                          fontFeatures: AppTypography.tabularFigures)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: unreaUp
                            ? context.yucai.positive
                            : context.yucai.negative,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 6),
                  Text('未实现',
                      style:
                          TextStyle(fontSize: 11, color: context.yucai.muted)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _fmtSigned(unrealized, currency),
                key: const ValueKey('splitUnrealizedVal'),
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: unreaUp ? context.yucai.positive : context.yucai.negative,
                    fontFeatures: AppTypography.tabularFigures),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────── ④ 年化收益率 ─────────────────────────

  /// 年化收益率卡(对齐 A-od annual-card)。
  /// ④ 年化:Task 13 接 server annualizedPct(PerformanceLoaded);Loading/Error → ⏳ 占位。
  /// ⑤ 基准:sub 标签显示 benchmarkName(有)/「⏳C mock」(无)。
  /// 累计 = unrealized / totalCost(✅ 前端,因 server totalPct 含 realized 口径不同)。
  Widget _annualCard(HoldingLoaded state, String currency, PerformanceState perf) {
    final unrealized = _sumUnrealized(state.holdings);
    final totalCost = state.summary.totalCostCents;
    final cumulative = totalCost > 0 ? (unrealized / totalCost) * 100 : 0.0;
    final loaded = perf is PerformanceLoaded ? perf.performance : null;
    // ④ 年化(XIRR 全期 资金加权):Task 7 降级信号改为 null(非 0)。null → 显「—」。
    final hasAnnualized = loaded != null && loaded.annualizedPct != null;
    final annualValue = hasAnnualized
        ? '${loaded.annualizedPct! >= 0 ? '+' : ''}${loaded.annualizedPct!.toStringAsFixed(1)}%'
        : '—';
    // Task 7 区间 XIRR 副标注(rangeAnnualizedPct 可独立于全期:全期可能因数据
    // 不足 null,但区间有值;反之亦然)。null → 不渲染副标注。
    final rangeSub = loaded?.rangeAnnualizedPct != null
        ? '区间 ${loaded!.rangeAnnualizedPct! >= 0 ? '+' : ''}${loaded.rangeAnnualizedPct!.toStringAsFixed(1)}%'
        : null;
    // Task 6 TWR(时间加权 全期):null → 显「—」(server 未算/数据不足)。
    final hasTwr = loaded != null && loaded.twrAnnualizedPct != null;
    final twrValue = hasTwr
        ? '${loaded.twrAnnualizedPct! >= 0 ? '+' : ''}${loaded.twrAnnualizedPct!.toStringAsFixed(1)}%'
        : '—';
    // range TWR(时间加权 区间)副标注:镜像 range XIRR 副标注(rangeSub)的区间维度,
    // 对齐现有格式(percentage,toStringAsFixed(1),带「区间」前缀)。null → 不渲染。
    final rangeTwrSub = loaded?.rangeTwrAnnualizedPct != null
        ? '区间 ${loaded!.rangeTwrAnnualizedPct! >= 0 ? '+' : ''}${loaded.rangeTwrAnnualizedPct!.toStringAsFixed(1)}%'
        : null;
    // Task 2 C CAGR(复合年化 全期):null → 显「—」(server 未算/数据不足)。
    // 与 XIRR(资金加权)+ TWR(时间加权)并列,提供三维度收益视角。
    final hasCagr = loaded != null && loaded.cagrAnnualizedPct != null;
    final cagrValue = hasCagr
        ? '${loaded.cagrAnnualizedPct! >= 0 ? '+' : ''}${loaded.cagrAnnualizedPct!.toStringAsFixed(1)}%'
        : '—';
    // range CAGR(复合年化 区间)副标注:镜像 range XIRR/range TWR 模式。
    // null → 不渲染区间副标注。
    final rangeCagrSub = loaded?.rangeCagrAnnualizedPct != null
        ? '区间 ${loaded!.rangeCagrAnnualizedPct! >= 0 ? '+' : ''}${loaded.rangeCagrAnnualizedPct!.toStringAsFixed(1)}%'
        : null;
    // ⑤ 基准名:server benchmarkName(有)/「⏳C mock」(无)。
    final hasBenchmark = loaded != null && loaded.benchmarkName.isNotEmpty;
    final benchLabel = hasBenchmark
        ? '基准 ${loaded.benchmarkName}'
        : '基准 沪深300 · ⏳C mock';
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('年化收益率',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppTypography.displayFamily,
                          fontFamilyFallback: AppTypography.displayFallback)),
                  const SizedBox(height: 2),
                  Text(benchLabel,
                      key: const ValueKey('annualBenchLabel'),
                      style: TextStyle(
                          fontSize: 11.5, color: context.yucai.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ④ 年化行(XIRR 全期 资金加权):server annualizedPct(无 → 「—」)+ 区间副标注。
          _annualRow(
            icon: LucideIcons.percent,
            label: '资金加权',
            value: annualValue,
            valueColor: hasAnnualized
                ? (loaded.annualizedPct! >= 0
                    ? context.yucai.positive
                    : context.yucai.negative)
                : context.yucai.muted,
            sub: rangeSub,
            key: const ValueKey('annualValue'),
          ),
          // Task 6 TWR(时间加权 全期):server twrAnnualizedPct(无 → 「—」)。
          // range TWR(区间)副标注:对齐资金加权行的区间 XIRR 副标注模式。
          _annualRow(
            icon: LucideIcons.timer,
            label: '时间加权',
            value: twrValue,
            valueColor: hasTwr
                ? (loaded.twrAnnualizedPct! >= 0
                    ? context.yucai.positive
                    : context.yucai.negative)
                : context.yucai.muted,
            sub: rangeTwrSub,
            subKey: const ValueKey('annualRangeTwrSub'),
            key: const ValueKey('annualTwrValue'),
          ),
          // Task 2 C CAGR(复合年化 全期):server cagrAnnualizedPct(无 → 「—」)。
          // range CAGR(区间)副标注:镜像资金加权/时间加权区间副标注模式。
          _annualRow(
            icon: LucideIcons.lineChart,
            label: '复合年化',
            value: cagrValue,
            valueColor: hasCagr
                ? (loaded.cagrAnnualizedPct! >= 0
                    ? context.yucai.positive
                    : context.yucai.negative)
                : context.yucai.muted,
            sub: rangeCagrSub,
            subKey: const ValueKey('annualRangeCagrSub'),
            key: const ValueKey('annualCagrValue'),
          ),
          // 累计行:✅ 从 holdings 算(unrealized/totalCost)。
          _annualRow(
            icon: LucideIcons.trendingUp,
            label: '累计',
            value: '${cumulative >= 0 ? '+' : ''}${cumulative.toStringAsFixed(2)}%',
            valueColor:
                cumulative >= 0 ? context.yucai.positive : context.yucai.negative,
            key: const ValueKey('annualCumulative'),
          ),
          // ⑤ bench-mini(loaded 有数据时渲染;无 benchmarkPoints 内部降级)。
          if (loaded != null && loaded.annualizedPct != null)
            _BenchmarkMiniBar(
              myAnnualized: loaded.annualizedPct!,
              benchmarkPoints: loaded.benchmarkPoints,
              benchmarkName: loaded.benchmarkName,
            ),
        ],
      ),
    );
  }

  /// 年化行(icon + label + value/可选 sub 副标注)。
  /// Task 7:`sub` 用于区间 XIRR 副标注(小字 muted,value 下方右对齐)。
  /// range TWR Task 4:第二个 sub(区间 TWR 副标注),需独立 `subKey` 区分
  /// (否则两 sub 共用 annualRangeSub key → duplicate key,find.byKey 模糊)。
  Widget _annualRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    String? sub,
    Key? subKey,
    Key? key,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: context.yucai.surfaceAlt, style: BorderStyle.solid))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: context.yucai.muted),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(fontSize: 13, color: context.yucai.fg)),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  key: key,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: valueColor,
                      fontFeatures: AppTypography.tabularFigures)),
              if (sub != null)
                Text(sub,
                    key: subKey ?? const ValueKey('annualRangeSub'),
                    style: TextStyle(
                        fontSize: 11,
                        color: context.yucai.muted,
                        fontFeatures: AppTypography.tabularFigures)),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────── ⑤ 持仓贡献 ─────────────────────────

  /// 按持仓贡献条(对齐 A-od contrib-card)。
  /// 每个 holding 的 unrealizedPnlCents(✅),正绿负红,中线对称条。
  Widget _contribHoldingCard(HoldingLoaded state, String currency) {
    final rows = state.holdings
        .map((h) => (
              symbol: h.securitySymbol,
              type: h.securityType ?? SecurityType.other,
              value: h.unrealizedPnlCents,
            ))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final scale = rows.isEmpty
        ? 1.0
        : rows.map((r) => r.value.abs()).reduce((a, b) => a > b ? a : b).clamp(1, 999999999999).toDouble();
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('持仓贡献',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppTypography.displayFamily,
                          fontFamilyFallback: AppTypography.displayFallback)),
                  SizedBox(height: 2),
                  Text('按未实现盈亏 · 正绿负红',
                      style: TextStyle(
                          fontSize: 11.5, color: context.yucai.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            _contribEmpty('暂无持仓')
          else
            Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  _contribRow(
                    symbol: rows[i].symbol,
                    type: rows[i].type,
                    value: rows[i].value,
                    scale: scale,
                    currency: currency,
                    key: ValueKey('contribHold-${rows[i].symbol}-$i'),
                  ),
                  if (i < rows.length - 1) const SizedBox(height: 6),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // ───────────────────────── ⑥ 类型贡献 ─────────────────────────

  /// 按类型贡献条(对齐 A-od contrib-card)。
  /// 按 SecurityType 聚合 unrealizedPnlCents(✅)。
  Widget _contribTypeCard(HoldingLoaded state, String currency) {
    final byType = <SecurityType, int>{};
    for (final h in state.holdings) {
      final t = h.securityType ?? SecurityType.other;
      byType[t] = (byType[t] ?? 0) + h.unrealizedPnlCents;
    }
    final rows = byType.entries
        .where((e) => e.value != 0)
        .map((e) => (type: e.key, value: e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final scale = rows.isEmpty
        ? 1.0
        : rows.map((r) => r.value.abs()).reduce((a, b) => a > b ? a : b).clamp(1, 999999999999).toDouble();
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('类型贡献',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppTypography.displayFamily,
                          fontFamilyFallback: AppTypography.displayFallback)),
                  SizedBox(height: 2),
                  Text('按 type 聚合 · 正绿负红',
                      style: TextStyle(
                          fontSize: 11.5, color: context.yucai.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            _contribEmpty('暂无盈亏')
          else
            Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  _contribRow(
                    symbol: kHoldingTypeLabels[rows[i].type] ??
                        rows[i].type.name,
                    type: rows[i].type,
                    value: rows[i].value,
                    scale: scale,
                    currency: currency,
                    isType: true,
                    key: ValueKey('contribType-${rows[i].type.name}-$i'),
                  ),
                  if (i < rows.length - 1) const SizedBox(height: 6),
                ],
              ],
            ),
        ],
      ),
    );
  }

  /// 单条贡献行:名称 + 中线对称条 + 数值。
  /// 条宽 = |value|/scale * 50%(对齐 A-od pct = abs/scale * 50)。
  Widget _contribRow({
    required String symbol,
    required SecurityType type,
    required int value,
    required double scale,
    required String currency,
    bool isType = false,
    Key? key,
  }) {
    final up = value >= 0;
    final typeColor = kHoldingTypeColors[type] ?? context.yucai.accent;
    final pct = scale > 0 ? (value.abs() / scale) * 50 : 0.0;
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: isType ? 84 : 96,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      color: typeColor, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(symbol,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: AppTypography.tabularFigures)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: context.yucai.bg,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: context.yucai.border),
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  // 中线对称:正→从中线向右,负→从中线向左。
                  final half = c.maxWidth / 2;
                  final fillWidth = (half * (pct / 50)).clamp(0.0, half);
                  return Stack(
                    children: [
                      // 中线。
                      Positioned(
                        left: half - 0.5,
                        top: -2,
                        bottom: -2,
                        child: Container(
                            width: 1, color: const Color(0xFFD8D3C7)),
                      ),
                      // 填充。
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: up ? half : half - fillWidth,
                        width: fillWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: up
                                ? context.yucai.positive
                                : context.yucai.negative,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              _fmtSigned(value, currency),
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: up ? context.yucai.positive : context.yucai.negative,
                  fontFeatures: AppTypography.tabularFigures),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contribEmpty(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.pieChart, size: 22, color: context.yucai.muted),
            const SizedBox(height: 6),
            Text(text,
                style: TextStyle(
                    fontSize: 12.5, color: context.yucai.muted)),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── API 标注 ─────────────────────────

  /// 页面底部 ⏳C 说明(对齐 A-od api-note)。
  Widget _apiNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: context.yucai.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info,
              size: 15, color: context.yucai.accent),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: context.yucai.accent,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text('⏳ C',
                key: ValueKey('apiNoteBadge'),
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: context.yucai.surface)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '收益 snapshot（日/月/年曲线 + 已实现聚合 + 基准）C 子项目实现；本页 unrealized / 贡献从 holdings 前端聚合。',
              key: ValueKey('apiNoteText'),
              style: TextStyle(
                  fontSize: 12, color: context.yucai.accentDeep),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 聚合 / 格式化 helpers ─────────────────────────

  /// 组合货币:首个 holding 的 currency,CNY 兜底。
  String _groupCurrency(List<Holding> holdings) {
    for (final h in holdings) {
      final c = h.currency;
      if (c != null && c.isNotEmpty) return c;
    }
    return 'CNY';
  }

  /// Σ unrealizedPnlCents(✅ proto 已给)。
  int _sumUnrealized(List<Holding> holdings) {
    var sum = 0;
    for (final h in holdings) {
      sum += h.unrealizedPnlCents;
    }
    return sum;
  }

  String _fmtRaw(int cents, String currency) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fen = (abs % 100).toString().padLeft(2, '0');
    return '$sign${currencySymbol(currency)}${_grouped(yuan)}.$fen';
  }

  String _fmtSigned(int cents, String currency) {
    final sign = cents < 0 ? '-' : '+';
    return '$sign${_fmtRaw(cents.abs(), currency)}';
  }

  String _grouped(int yuan) {
    final s = yuan.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

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
        color: context.yucai.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(LucideIcons.barChart3, size: 13, color: context.yucai.muted),
            const SizedBox(width: 5),
            Text('对比基准 $name · 近似',
                style: TextStyle(fontSize: 11, color: context.yucai.muted)),
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
        Text('超额', style: TextStyle(fontSize: 11, color: AppColors.muted)),
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
          style: TextStyle(fontSize: 11, color: AppColors.muted))),
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
