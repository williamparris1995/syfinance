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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.fg,
        elevation: 0,
        title: const Text('收益统计'),
      ),
      body: BlocBuilder<HoldingBloc, HoldingState>(
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
                    style: const TextStyle(color: AppColors.muted)),
              ),
            );
          }
          // HoldingInitial / HoldingSubmitting(无 last)→ 空占位。
          return const SizedBox.shrink();
        },
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
        _perfHeader(state, currency),
        const SizedBox(height: 16),
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

  // ───────────────────────── ① 概览头 ─────────────────────────

  /// 总收益(CNY)+ 收益率 pill + 成本/市值 sub(对齐 A-od perf-header)。
  Widget _perfHeader(HoldingLoaded state, String currency) {
    final unrealized = _sumUnrealized(state.holdings);
    final up = unrealized >= 0;
    final totalCost = state.summary.totalCostCents;
    final totalMkt = state.summary.totalMarketValueCents;
    // 收益率 = unrealized / totalCost(成本为 0 → 0%)。
    final pnlPct = totalCost > 0 ? (unrealized / totalCost) * 100 : 0.0;
    return DataCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.trendingUp,
                        size: 14, color: AppColors.muted),
                    const SizedBox(width: 5),
                    Text('总收益（$currency）',
                        key: const ValueKey('perfHeaderLabel'),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _fmtSigned(unrealized, currency),
                  key: const ValueKey('perfTotalPnl'),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    color: up ? AppColors.positive : AppColors.negative,
                    fontFeatures: AppTypography.tabularFigures,
                    fontFamily: AppTypography.displayFamily,
                    fontFamilyFallback: AppTypography.displayFallback,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '成本 ${_fmtRaw(totalCost, currency)} · 市值 ${_fmtRaw(totalMkt, currency)}',
                  key: const ValueKey('perfHeaderSub'),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (up ? AppColors.positive : AppColors.negative)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(up ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                    size: 14,
                    color: up ? AppColors.positive : AppColors.negative),
                const SizedBox(width: 4),
                Text(
                  '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
                  key: const ValueKey('perfPnlPct'),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: up ? AppColors.positive : AppColors.negative,
                      fontFeatures: AppTypography.tabularFigures),
                ),
              ],
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
              const Column(
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
                          fontSize: 11.5, color: AppColors.muted)),
                ],
              ),
              if (!realizedLoaded)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: const Text('⏳ C',
                      key: ValueKey('splitBadge'),
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentHover)),
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
              decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(
                          color: Color(0xFFEFECE5), style: BorderStyle.solid))),
              child: const Row(
                children: [
                  Icon(LucideIcons.hourglass,
                      size: 13, color: AppColors.accent),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '已实现收益加载中或暂无数据,请稍后重试',
                      key: ValueKey('splitRealizedHint'),
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.muted),
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
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: AppColors.border),
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
                  color: AppColors.accent,
                ),
              ),
            Expanded(
              flex: 100 - realFlex,
              child: Container(
                key: const ValueKey('splitBarUnrealized'),
                color: unreaUp ? AppColors.positive : AppColors.negative,
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
                            ? AppColors.accent
                            : AppColors.accent.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 6),
                  const Text('已实现',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.muted)),
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
                              ? AppColors.positive
                              : AppColors.negative,
                          fontFeatures: AppTypography.tabularFigures))
                  : const Text('⏳C 待后端',
                      key: ValueKey('splitRealizedVal'),
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentHover,
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
                            ? AppColors.positive
                            : AppColors.negative,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 6),
                  const Text('未实现',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _fmtSigned(unrealized, currency),
                key: const ValueKey('splitUnrealizedVal'),
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: unreaUp ? AppColors.positive : AppColors.negative,
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
    // ④ 年化:server annualizedPct(有数据 → 渲染;无 → ⏳ 占位)。
    final hasAnnualized = loaded != null && loaded.annualizedPct != 0;
    final annualValue = hasAnnualized
        ? '${loaded.annualizedPct >= 0 ? '+' : ''}${loaded.annualizedPct.toStringAsFixed(1)}%'
        : '⏳';
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
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ④ 年化行:server annualizedPct(无 → ⏳ 占位)。
          _annualRow(
            icon: LucideIcons.percent,
            label: '年化',
            value: annualValue,
            valueColor: hasAnnualized
                ? (loaded.annualizedPct >= 0
                    ? AppColors.positive
                    : AppColors.negative)
                : AppColors.muted,
            key: const ValueKey('annualValue'),
          ),
          // 累计行:✅ 从 holdings 算(unrealized/totalCost)。
          _annualRow(
            icon: LucideIcons.trendingUp,
            label: '累计',
            value: '${cumulative >= 0 ? '+' : ''}${cumulative.toStringAsFixed(2)}%',
            valueColor:
                cumulative >= 0 ? AppColors.positive : AppColors.negative,
            key: const ValueKey('annualCumulative'),
          ),
        ],
      ),
    );
  }

  Widget _annualRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    Key? key,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: Color(0xFFEFECE5), style: BorderStyle.solid))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Icon(icon, size: 14, color: AppColors.muted),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.fg)),
          const Spacer(),
          Text(value,
              key: key,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                  fontFeatures: AppTypography.tabularFigures)),
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
          const Row(
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
                          fontSize: 11.5, color: AppColors.muted)),
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
          const Row(
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
                          fontSize: 11.5, color: AppColors.muted)),
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
    final typeColor = kHoldingTypeColors[type] ?? AppColors.accent;
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
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: AppColors.border),
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
                                ? AppColors.positive
                                : AppColors.negative,
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
                  color: up ? AppColors.positive : AppColors.negative,
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
            const Icon(LucideIcons.pieChart, size: 22, color: AppColors.muted),
            const SizedBox(height: 6),
            Text(text,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.muted)),
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
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.info,
              size: 15, color: AppColors.accent),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: const Text('⏳ C',
                key: ValueKey('apiNoteBadge'),
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.surface)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '收益 snapshot（日/月/年曲线 + 已实现聚合 + 基准）C 子项目实现；本页 unrealized / 贡献从 holdings 前端聚合。',
              key: ValueKey('apiNoteText'),
              style: TextStyle(
                  fontSize: 12, color: AppColors.accentHover),
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
