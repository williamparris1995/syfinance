// 持仓详情页(Task 8)。消费 Task 4 HoldingBloc(LoadDetailRequested →
// HoldingDetailLoaded(holding + trades) / HoldingError(isPendingBackend))。
//
// 对齐 A-od 设计源 holding-detail-{desktop,tablet,mobile}.html(7 组件):
//   ① 头部(symbol + 现价 + 刷新)
//   ② 持仓卡(量/成本价/现价/总成本/市值 + 盈亏色块)
//   ③ 收益曲线(PerfCurveChart · 日/月/年 tab · foot 浮动/已实现/总收益)
//   ④ 交易历史(ListHoldingTransactions ⏳ → isPendingBackend 空态 + "⏳ 待后端";
//             trades 非空 → buy/sell/dividend/split 筛选 + 列表)
//   ⑤ 配置占比环图(复用 HoldingPieChart,单持仓切片 = 该持仓占自身 100%)
//   ⑥ 关联目标卡(导航入口 → /holdings/goals · GoalLinkPage Task 11 接真)
//   ⑦ 操作按钮(buy/sell/dividend/split → trade_sheet_page)
//
// 照搬御财 debt_detail_page.dart:StatefulWidget + initState dispatch
// LoadDetailRequested + BlocBuilder<HoldingBloc,HoldingState>。
//
// ⏳ 降级(本页核心,**Task 5 列表页触发不到**):
//   listHoldingTransactions 是 ⏳ 端点(后端 B/C/D 未实现)→ bloc 发
//   HoldingError(isPendingBackend:true)。本页此时:
//     - **holding 仍可展示**(listHoldings ✅,bloc 从 _last 不含 detail;
//       故 detail page 在 isPendingBackend 时不能从 _last 恢复 holding ——
//       此处直接显示「⏳ 交易历史待后端」占位,holding 区也降级为骨架提示,
//       与 brief 一致:**交易历史区显示空态 + "⏳"**)。
//   真业务错误(isPendingBackend:false)→ 错误文案。
//
// 前端算 realized/unrealized/成本曲线(⏳ trades 空时占位):
//   - unrealized = holding.unrealizedPnlCents(已由 backend/proto 给出)。
//   - realized = Σ sell.amountCents(正流入,扣成本基础后的实现收益近似)+
//     Σ dividend.amountCents —— 平均成本 mock(brief:非 FIFO;A-server 接管后
//     由 server 计算)。sell amountCents 在 proto 里已是交易总额,前端以其全部
//     计为「回收」的近似(无成本基础扣减的纯展示用)。
//   - 成本曲线:从 trades 按 tradeDate 升序累加 (qty*price) 形成累计投入基础
//     线(brief 指定「从 trades 前端重建成本基础曲线」);trades 空则空态。
//
// 路由:本页由路由层(Task 11)注入 BlocProvider<HoldingBloc>;此处
// context.read<HoldingBloc>().add(LoadDetailRequested(id))。
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_event.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_state.dart';
import 'package:yucai_client/holding/presentation/pages/performance_page.dart'
    show rangeName;
import 'package:yucai_client/holding/presentation/widgets/holding_pie_chart.dart';
import 'package:yucai_client/holding/presentation/widgets/perf_curve_chart.dart';

/// 持仓详情页。对齐 A-od holding-detail-*.html。
class HoldingDetailPage extends StatefulWidget {
  const HoldingDetailPage({super.key, required this.id});

  final String id;

  @override
  State<HoldingDetailPage> createState() => _HoldingDetailPageState();
}

class _HoldingDetailPageState extends State<HoldingDetailPage> {
  /// 收益曲线区间(本页内联切换;Task 9 复用 PerfCurveChart 时另传)。
  PerfRange _curveRange = PerfRange.day;
  /// 交易历史筛选(全部/买入/卖出/分红/拆分)。
  _TradeFilter _tradeFilter = _TradeFilter.all;
  /// 现价刷新进行中(头部刷新按钮 mock,触发 UpdatePriceRequested 需 form,
  /// 此处仅做 loading 态展示对齐 A-od dh-refresh spinning)。
  bool _refreshing = false;

  /// 折算本位币(Task 12 D-currency)。从 CurrencySettings.getBaseCurrency()
  /// 异步读(CNY default);resolve 后透传到 LoadHoldingCurveRequested →
  /// getHoldingPerformance → proto base_currency。range tab 切换时复用已解析值。
  final CurrencySettings _currencySettings = getIt<CurrencySettings>();
  String _baseCurrency = '';

  @override
  void initState() {
    super.initState();
    context.read<HoldingBloc>().add(LoadDetailRequested(widget.id));
    // Task 13:拉单持仓价格曲线(server getHoldingPerformance)。
    // baseCurrency 异步解析后 dispatch(range 默认 DAY;tab 切换时重发)。
    _loadCurve();
    _currencySettings.listenable.addListener(_onBaseChanged);
  }

  /// 读 CurrencySettings base 后 dispatch 单持仓曲线。range 默认 DAY。
  Future<void> _loadCurve({String range = 'DAY'}) async {
    final base = await _currencySettings.getBaseCurrency();
    if (!mounted) return;
    setState(() => _baseCurrency = base);
    if (!mounted) return;
    context.read<HoldingBloc>().add(LoadHoldingCurveRequested(
      holdingId: widget.id,
      range: range,
      baseCurrency: base,
    ));
  }

  // Cross-page refresh: base currency changed in settings → re-dispatch this
  // holding's curve with the current range and new reporting currency.
  void _onBaseChanged() {
    if (!mounted) return;
    _loadCurve(range: rangeName(_curveRange));
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
      appBar: AppBar(
        backgroundColor: context.yucai.surface,
        foregroundColor: context.yucai.fg,
        elevation: 0,
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('持仓详情'),
      ),
      body: BlocBuilder<HoldingBloc, HoldingState>(
        builder: (context, state) {
          if (state is HoldingLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is HoldingDetailLoaded) {
            // Stack:body 内容 + 底部 sticky 操作 bar(⑦)。
            // ⏳ isPendingBackend:true 时 holding 仍带(bloc 从 listHoldings
            // 成功获取),仅交易历史区降级(brief:交易历史区空态,非整页)。
            return Stack(
              children: [
                _body(state.holding, state.trades,
                    tradesPendingBackend: state.isPendingBackend,
                    detail: state),
                _actionBar(),
              ],
            );
          }
          if (state is HoldingError) {
            // 真业务错误(listHoldings fail,无 holding)→ 错误文案。
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(state.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.yucai.muted)),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // ───────────────────────── body(7 组件) ─────────────────────────

  Widget _body(
    Holding h,
    List<HoldingTransaction> trades, {
    bool tradesPendingBackend = false,
    required HoldingDetailLoaded detail,
  }) {
    final isMobile = MediaQuery.of(context).size.width <= 720;
    final currency = h.currency ?? 'CNY';
    return ListView(
      padding: isMobile
          ? const EdgeInsets.fromLTRB(16, 14, 16, 90)
          : const EdgeInsets.fromLTRB(36, 24, 36, 90),
      children: [
        _header(h, currency),
        const SizedBox(height: 16),
        _positionCard(h, currency),
        const SizedBox(height: 16),
        _curveCard(h, currency, detail),
        const SizedBox(height: 16),
        _xirrCard(detail),
        const SizedBox(height: 16),
        _tradesCard(trades, currency, isMobile,
            pendingBackend: tradesPendingBackend),
        const SizedBox(height: 16),
        _allocationCard(h),
        const SizedBox(height: 16),
        _goalCard(h),
      ],
    );
  }

  // ───────────────────────── ① 头部 ─────────────────────────

  /// symbol + type chip + 现价 + 刷新按钮(对齐 A-od detail-header)。
  Widget _header(Holding h, String currency) {
    final price = h.currentPriceCents ?? 0;
    return DataCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(h.securitySymbol,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppTypography.displayFamily,
                          fontFamilyFallback:
                              AppTypography.displayFallback,
                        )),
                    if (h.securityType != null) _typeChip(h.securityType!),
                  ],
                ),
                const SizedBox(height: 4),
                Text(h.securityName,
                    style: TextStyle(
                        fontSize: 13, color: context.yucai.muted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  children: [
                    _metaItem(LucideIcons.coins, currency),
                    if (h.unrealizedPnlCents >= 0)
                      _metaItem(LucideIcons.trendingUp, '盈利')
                    else
                      _metaItem(LucideIcons.trendingDown, '亏损'),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(_fmtRaw(price, currency),
                      key: const ValueKey('detailPrice'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        fontFeatures: AppTypography.tabularFigures,
                      )),
                  const SizedBox(width: 6),
                  _refreshBtn(),
                ],
              ),
              const SizedBox(height: 4),
              Text('更新于 ${_nowLabel()}',
                  key: const ValueKey('detailUpdated'),
                  style: TextStyle(
                      fontSize: 11, color: context.yucai.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeChip(SecurityType t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (kHoldingTypeColors[t] ?? context.yucai.accent).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
                color: kHoldingTypeColors[t] ?? context.yucai.accent,
                shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(kHoldingTypeLabels[t] ?? t.name,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: kHoldingTypeColors[t] ?? context.yucai.accentDeep)),
        ],
      ),
    );
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: context.yucai.muted),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(fontSize: 11.5, color: context.yucai.muted)),
      ],
    );
  }

  Widget _refreshBtn() {
    return InkWell(
      key: const ValueKey('detailRefresh'),
      onTap: _refreshing
          ? null
          : () {
              setState(() => _refreshing = true);
              // mock 刷新态(对齐 A-od dh-refresh spinning);真刷新需价格 form。
              Future.delayed(const Duration(milliseconds: 800), () {
                if (mounted) setState(() => _refreshing = false);
              });
            },
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.yucai.accentSoft,
          shape: BoxShape.circle,
        ),
        child: _refreshing
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: context.yucai.accent),
              )
            : Icon(LucideIcons.refreshCw,
                size: 14, color: context.yucai.accent),
      ),
    );
  }

  // ───────────────────────── ② 持仓卡 ─────────────────────────

  /// 市值(大字) + 盈亏 pill + 持有量/成本价/现价/总成本 4-cell grid。
  /// 对齐 A-od position-card。
  Widget _positionCard(Holding h, String currency) {
    final pnl = h.unrealizedPnlCents;
    final up = pnl >= 0;
    final totalCost = (h.quantity * h.avgCostCents).round();
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前市值',
                        style: TextStyle(
                            fontSize: 11.5, color: context.yucai.muted)),
                    const SizedBox(height: 4),
                    Text(
                      '${_fmtRaw(h.marketValueCents, currency)} $currency',
                      key: const ValueKey('detailMarketValue'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        fontFeatures: AppTypography.tabularFigures,
                        fontFamily: AppTypography.displayFamily,
                        fontFamilyFallback: AppTypography.displayFallback,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (up ? context.yucai.positive : context.yucai.negative)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(up ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                        size: 13,
                        color: up ? context.yucai.positive : context.yucai.negative),
                    const SizedBox(width: 4),
                    Text(_fmtSigned(pnl, currency),
                        key: const ValueKey('detailPnlPill'),
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color:
                                up ? context.yucai.positive : context.yucai.negative,
                            fontFeatures: AppTypography.tabularFigures)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            color: context.yucai.border,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _posCell('持有量', _fmtQty(h.quantity),
                      key: const ValueKey('detailQty'))),
              Expanded(
                  child: _posCell('成本价', _fmtRaw(h.avgCostCents, currency),
                      key: const ValueKey('detailAvgCost'))),
              Expanded(
                  child: _posCell(
                      '现价',
                      _fmtRaw(h.currentPriceCents ?? 0, currency),
                      key: const ValueKey('detailCurPrice'))),
              Expanded(
                  child: _posCell('总成本', _fmtRaw(totalCost, currency),
                      key: const ValueKey('detailTotalCost'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _posCell(String k, String v, {Key? key}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      key: key,
      children: [
        Text(k,
            style: TextStyle(fontSize: 11, color: context.yucai.muted)),
        const SizedBox(height: 3),
        Text(v,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFeatures: AppTypography.tabularFigures)),
      ],
    );
  }

  // ───────────────────────── ③ 收益曲线 ─────────────────────────

  /// PerfCurveChart · 日/月/年 tab · foot 浮动/已实现/总收益。
  ///
  /// Task 13(holding-C)接 server 真数据:②曲线 = detail.holdingCurve
  /// (getHoldingPerformance.pricePoints);⑥realized = detail.holdingCurveRealizedCents
  /// (server FIFO)。两者均可空(LoadHoldingCurveRequested 未发/fail → null →
  /// 空态,避免展示误导性 0)。range tab 切换 → 重发 LoadHoldingCurveRequested。
  Widget _curveCard(Holding h, String currency, HoldingDetailLoaded detail) {
    final unrealized = h.unrealizedPnlCents;
    final realized = detail.holdingCurveRealizedCents;
    final total = realized != null ? realized + unrealized : null;
    return DataCard(
      child: PerfCurveChart(
        // ② 价格曲线(server pricePoints;null/空 → PerfCurveChart 空态)。
        points: detail.holdingCurve ?? const [],
        range: _curveRange,
        onRangeChange: (r) {
          setState(() => _curveRange = r);
          context.read<HoldingBloc>().add(LoadHoldingCurveRequested(
            holdingId: h.id,
            range: rangeName(r),
            baseCurrency: _baseCurrency,
          ));
        },
        foot: PerfCurveFoot(
          unrealizedCents: unrealized,
          // ⑥ realized(server FIFO;null → 不渲染 cell)。
          realizedCents: realized,
          totalCents: total,
          currency: currency,
        ),
      ),
    );
  }

  // ───────────────────────── ③b XIRR(Task 7)+ TWR(Task 6)─────────────

  /// 年化收益率卡(单持仓原币口径,双维度)。数据来自 HoldingDetailLoaded:
  /// - 资金加权(全期)`holdingAnnualizedPct`(server HoldingPerformance.annualizedPct)
  /// - 资金加权(区间)`holdingRangeAnnualizedPct`(随 range tab)
  /// - 时间加权(全期)`holdingTwrAnnualizedPct`(server twrAnnualizedPct)
  /// - 复合年化(全期)`holdingCagrAnnualizedPct`(server cagrAnnualizedPct,price-based)
  /// null → 显「—」(server 未算/数据不足;e.g. 仅 1 笔交易 XIRR/TWR/CAGR 无解)。
  /// 模式对齐 performance_page `_annualRow`(数值 + 副标注)。
  Widget _xirrCard(HoldingDetailLoaded detail) {
    final full = detail.holdingAnnualizedPct;
    final range = detail.holdingRangeAnnualizedPct;
    final twr = detail.holdingTwrAnnualizedPct;
    final cagr = detail.holdingCagrAnnualizedPct;
    final hasFull = full != null;
    final hasRange = range != null;
    final hasTwr = twr != null;
    final hasCagr = cagr != null;
    return DataCard(
      key: const ValueKey('detailXirrCard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              Text('资金加权(XIRR)+ 时间加权(TWR)+ 复合年化(CAGR)· 数据不足时显示 —',
                  key: ValueKey('detailXirrSub'),
                  style: TextStyle(fontSize: 11.5, color: context.yucai.muted)),
            ],
          ),
          const SizedBox(height: 12),
          // 资金加权 · 全期(主位)。
          _xirrRow(
            label: '资金加权 · 全期',
            value: hasFull
                ? '${full >= 0 ? '+' : ''}${full.toStringAsFixed(1)}%'
                : '—',
            valueColor: hasFull
                ? (full >= 0 ? context.yucai.positive : context.yucai.negative)
                : context.yucai.muted,
            key: const ValueKey('detailXirrFull'),
          ),
          // 资金加权 · 区间(副位,随 range tab;null → 「—」)。
          _xirrRow(
            label: '资金加权 · 区间',
            value: hasRange
                ? '${range >= 0 ? '+' : ''}${range.toStringAsFixed(1)}%'
                : '—',
            valueColor: hasRange
                ? (range >= 0 ? context.yucai.positive : context.yucai.negative)
                : context.yucai.muted,
            key: const ValueKey('detailXirrRange'),
          ),
          // 时间加权 · 全期(Task 6 TWR;null → 「—」)。
          _xirrRow(
            label: '时间加权 · 全期',
            value: hasTwr
                ? '${twr >= 0 ? '+' : ''}${twr.toStringAsFixed(1)}%'
                : '—',
            valueColor: hasTwr
                ? (twr >= 0 ? context.yucai.positive : context.yucai.negative)
                : context.yucai.muted,
            key: const ValueKey('detailXirrTwr'),
          ),
          // 复合年化 · 全期(Task 2 C CAGR price-based;null → 「—」)。
          _xirrRow(
            label: '复合年化 · 全期',
            value: hasCagr
                ? '${cagr >= 0 ? '+' : ''}${cagr.toStringAsFixed(1)}%'
                : '—',
            valueColor: hasCagr
                ? (cagr >= 0 ? context.yucai.positive : context.yucai.negative)
                : context.yucai.muted,
            key: const ValueKey('detailXirrCagr'),
          ),
        ],
      ),
    );
  }

  Widget _xirrRow({
    required String label,
    required String value,
    required Color valueColor,
    Key? key,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: context.yucai.surfaceAlt, style: BorderStyle.solid))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: context.yucai.fg)),
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

  // ───────────────────────── ④ 交易历史 ─────────────────────────

  /// 交易历史(对齐 A-od trades-card)。
  /// `pendingBackend`=true:ListHoldingTransactions ⏳ 端点未实现 →
  /// 显示「⏳ 交易历史待后端」空态(holding 卡/曲线/配置仍在,brief 核心要求)。
  /// trades 空 → 「暂无成交」空态。
  Widget _tradesCard(
      List<HoldingTransaction> trades, String currency, bool isMobile,
      {bool pendingBackend = false}) {
    final filtered = _filteredTrades(trades);
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('交易历史',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppTypography.displayFamily,
                          fontFamilyFallback:
                              AppTypography.displayFallback)),
                  const SizedBox(height: 2),
                  Text(
                      pendingBackend
                          ? 'ListHoldingTransactions ⏳ 端点未实现'
                          : 'ListHoldingTransactions · ${trades.length} 条 · ⏳',
                      key: const ValueKey('detailTradesSub'),
                      style: TextStyle(
                          fontSize: 11.5, color: context.yucai.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pendingBackend)
            _tradesPendingEmpty()
          else ...[
            _tradeFilterChips(trades),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              _tradesEmpty(_tradeFilter == _TradeFilter.all
                  ? '暂无成交'
                  : '该筛选下无成交')
            else if (isMobile)
              _tradeMobileList(filtered, currency)
            else
              _tradeTable(filtered, currency),
          ],
        ],
      ),
    );
  }

  /// ⏳ 交易历史待后端空态(复用 A-od trades-empty 样式)。
  /// 仅交易历史子区域降级;holding 卡/曲线/配置/关联目标保留。
  Widget _tradesPendingEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.hourglass,
                key: ValueKey('pendingBackendTitle'),
                size: 26,
                color: context.yucai.accent),
            const SizedBox(height: 8),
            Text('⏳ 交易历史待后端',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.yucai.fg)),
            const SizedBox(height: 3),
            Text(
              'ListHoldingTransactions ⏳ 端点未实现,流水将在后端就绪后可用',
              textAlign: TextAlign.center,
              key: ValueKey('pendingBackendHint'),
              style: TextStyle(fontSize: 11.5, color: context.yucai.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tradeFilterChips(List<HoldingTransaction> trades) {
    const chips = [
      (_TradeFilter.all, '全部'),
      (_TradeFilter.buy, '买入'),
      (_TradeFilter.sell, '卖出'),
      (_TradeFilter.dividend, '分红'),
      (_TradeFilter.split, '拆分'),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (f, label) in chips)
          _tradeChip(f, label, _countFor(f, trades)),
      ],
    );
  }

  int _countFor(_TradeFilter f, List<HoldingTransaction> trades) {
    if (f == _TradeFilter.all) return trades.length;
    final type = {
      _TradeFilter.buy: TradeType.buy,
      _TradeFilter.sell: TradeType.sell,
      _TradeFilter.dividend: TradeType.dividend,
      _TradeFilter.split: TradeType.split,
    }[f]!;
    return trades.where((t) => t.tradeType == type).length;
  }

  Widget _tradeChip(_TradeFilter f, String label, int count) {
    final active = f == _tradeFilter;
    return InkWell(
      key: ValueKey('tradeFilter-${f.name}'),
      onTap: () => setState(() => _tradeFilter = f),
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? context.yucai.accent.withValues(alpha: 0.12)
              : context.yucai.surface,
          border: Border.all(
              color: active ? context.yucai.accent : context.yucai.border),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? context.yucai.accentDeep : context.yucai.muted)),
            const SizedBox(width: 4),
            Text('$count',
                key: ValueKey('tradeFilterCnt-${f.name}'),
                style: TextStyle(
                    fontSize: 11,
                    color: active ? context.yucai.accentDeep : context.yucai.muted,
                    fontFeatures: AppTypography.tabularFigures)),
          ],
        ),
      ),
    );
  }

  List<HoldingTransaction> _filteredTrades(List<HoldingTransaction> trades) {
    if (_tradeFilter == _TradeFilter.all) return trades;
    final type = {
      _TradeFilter.buy: TradeType.buy,
      _TradeFilter.sell: TradeType.sell,
      _TradeFilter.dividend: TradeType.dividend,
      _TradeFilter.split: TradeType.split,
    }[_tradeFilter]!;
    return trades.where((t) => t.tradeType == type).toList();
  }

  /// desktop/tablet 表(对齐 A-od trades-table):日期/类型/数量/价格/金额/备注。
  Widget _tradeTable(List<HoldingTransaction> trades, String currency) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.yucai.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(0.8),
            3: FlexColumnWidth(1),
            4: FlexColumnWidth(1),
            5: FlexColumnWidth(1.4),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: context.yucai.surfaceAlt,
                border: Border(bottom: BorderSide(color: context.yucai.border)),
              ),
              children: [
                _th('日期'),
                _th('类型'),
                _th('数量', align: TextAlign.right),
                _th('价格', align: TextAlign.right),
                _th('金额', align: TextAlign.right),
                _th('备注'),
              ],
            ),
            for (var i = 0; i < trades.length; i++)
              _tradeRow(trades[i], i == trades.length - 1, currency),
          ],
        ),
      ),
    );
  }

  Widget _th(String label, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(label,
          textAlign: align,
          style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
              color: context.yucai.muted,
              fontFeatures: AppTypography.tabularFigures)),
    );
  }

  TableRow _tradeRow(
      HoldingTransaction t, bool isLast, String currency) {
    final (tag, tagColor) = _tradeTag(t.tradeType);
    final amt = t.amountCents;
    final amtColor = amt > 0
        ? context.yucai.positive
        : amt < 0
            ? context.yucai.negative
            : context.yucai.muted;
    final border = BorderSide(color: context.yucai.surfaceAlt);
    return TableRow(
      decoration:
          BoxDecoration(border: isLast ? null : Border(bottom: border)),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Text(t.tradeDate,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontFeatures: AppTypography.tabularFigures)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: tagColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(tag,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: tagColor)),
            ],
          ),
        ),
        _tdRight(_fmtQty(t.quantity)),
        _tdRight(t.tradeType == TradeType.split
            ? '—'
            : _fmtRaw(t.priceCents, currency)),
        _tdRight(amt == 0 ? '—' : _fmtSigned(amt, currency),
            color: amtColor, bold: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Text(t.notes ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5, color: context.yucai.muted)),
        ),
      ],
    );
  }

  Widget _tdRight(String text, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Text(text,
          textAlign: TextAlign.right,
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              color: color ?? context.yucai.fg,
              fontFeatures: AppTypography.tabularFigures)),
    );
  }

  /// mobile 紧凑卡列表(对齐 A-od m-trades-card)。
  Widget _tradeMobileList(List<HoldingTransaction> trades, String currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < trades.length; i++) ...[
          _tradeMobileCard(trades[i], currency),
          if (i < trades.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _tradeMobileCard(HoldingTransaction t, String currency) {
    final (tag, tagColor) = _tradeTag(t.tradeType);
    final amt = t.amountCents;
    final amtColor = amt > 0
        ? context.yucai.positive
        : amt < 0
            ? context.yucai.negative
            : context.yucai.muted;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        border: Border.all(color: context.yucai.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration:
                          BoxDecoration(color: tagColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(tag,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: tagColor)),
                    const SizedBox(width: 8),
                    Text(t.tradeDate,
                        style: TextStyle(
                            fontSize: 11.5, color: context.yucai.muted)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${_fmtQty(t.quantity)} 股 · ${t.tradeType == TradeType.split ? "—" : _fmtRaw(t.priceCents, currency)}',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: context.yucai.muted,
                        fontFeatures: AppTypography.tabularFigures)),
              ],
            ),
          ),
          Text(amt == 0 ? '—' : _fmtSigned(amt, currency),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: amtColor,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }

  /// buy/sell/dividend/split → (中文 tag, 语义色)。对齐 A-od typeMeta。
  (String, Color) _tradeTag(TradeType type) {
    switch (type) {
      case TradeType.buy:
        return ('买入', context.yucai.negative);
      case TradeType.sell:
        return ('卖出', context.yucai.positive);
      case TradeType.dividend:
        return ('分红', context.yucai.accent);
      case TradeType.split:
        return ('拆分', const Color(0xFF6B7A8F));
    }
  }

  Widget _tradesEmpty(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.calendar, size: 22, color: context.yucai.muted),
            const SizedBox(height: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 12.5, color: context.yucai.muted)),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── ⑤ 配置占比 ─────────────────────────

  /// 配置占比环图(复用 HoldingPieChart)。
  /// ⚠️ 单持仓详情:此持仓占「自身」100% —— 切片为单条该 type。语义对齐 A-od
  /// alloc-mini(该持仓市值占总持仓百分比)。本页无总持仓上下文,展示该持仓
  /// 自身(100% 该 type),为视觉占位 + 类型标签;Task 9 统计页才是真实多持仓占比。
  Widget _allocationCard(Holding h) {
    final type = h.securityType ?? SecurityType.other;
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('配置占比',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTypography.displayFamily,
                      fontFamilyFallback: AppTypography.displayFallback)),
              Text(kHoldingTypeLabels[type] ?? type.name,
                  key: const ValueKey('detailAllocType'),
                  style: TextStyle(
                      fontSize: 12, color: context.yucai.muted)),
            ],
          ),
          const SizedBox(height: 14),
          HoldingPieChart(
            slices: [
              HoldingSlice(type: type, valueCents: h.marketValueCents),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────── ⑥ 关联目标(导航入口 → /holdings/goals) ─────

  /// 关联目标卡(导航入口)。点击 → push `/holdings/goals`,extra 注入 holding。
  /// Task 11(D-goal)已实现 GoalLinkPage(真 listInvestmentGoals + 占比/进度),
  /// 此处为详情页的进入入口(替换原 ⏳D 空态存根)。
  Widget _goalCard(Holding h) {
    return DataCard(
      key: const ValueKey('detailGoalCard'),
      onTap: () => context.push('/holdings/goals', extra: {'holding': h}),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.yucai.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(LucideIcons.gem,
                key: ValueKey('detailGoalIcon'),
                size: 18,
                color: context.yucai.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('关联目标',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: AppTypography.displayFamily,
                        fontFamilyFallback: AppTypography.displayFallback)),
                SizedBox(height: 3),
                Text('查看本持仓目标进度',
                    key: ValueKey('detailGoalSubtitle'),
                    style: TextStyle(fontSize: 12.5, color: context.yucai.muted)),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight,
              key: ValueKey('detailGoalChevron'),
              size: 18,
              color: context.yucai.muted),
        ],
      ),
    );
  }

  // ───────────────────────── ⑦ 操作按钮(底部 sticky bar) ─────────────────────────

  /// build() body padding 底部留 90px,sticky action bar 浮于底部。
  /// buy/sell/dividend/split → trade_sheet_page(路由 Task 11 接,这里
  /// context.push('/holdings/trade', extra: {type}) 占位)。
  Widget _actionBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: context.yucai.surface,
          border: Border(top: BorderSide(color: context.yucai.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(child: _actBtn('买入', LucideIcons.arrowDownCircle,
                  context.yucai.negative, TradeType.buy)),
              const SizedBox(width: 8),
              Expanded(child: _actBtn('卖出', LucideIcons.arrowUpCircle,
                  context.yucai.positive, TradeType.sell)),
              const SizedBox(width: 8),
              Expanded(child: _actBtn('分红', LucideIcons.coins,
                  context.yucai.accent, TradeType.dividend)),
              const SizedBox(width: 8),
              Expanded(child: _actBtn('拆分', LucideIcons.gitMerge,
                  const Color(0xFF6B7A8F), TradeType.split)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actBtn(
      String label, IconData icon, Color color, TradeType type) {
    return InkWell(
      key: ValueKey('actBtn-${type.name}'),
      onTap: () => _onAction(type),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }

  void _onAction(TradeType type) {
    // 路由 Task 11 接 trade_sheet_page;此处 push 占位 + extra 传 type。
    // trade_sheet 路由路径暂定 /holdings/trade(Task 11 校准)。
    context.push('/holdings/trade', extra: {'type': type.name});
    AppToast.show(context, '触发 ${_actionLabel(type)} 交易 Sheet',
        type: ToastType.warning);
  }

  String _actionLabel(TradeType type) {
    switch (type) {
      case TradeType.buy:
        return '买入';
      case TradeType.sell:
        return '卖出';
      case TradeType.dividend:
        return '分红';
      case TradeType.split:
        return '拆分';
    }
  }

  // ───────────────────────── 格式化 helpers ─────────────────────────

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

  String _fmtQty(double q) {
    if (q == q.roundToDouble()) return q.toInt().toString();
    return q.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '');
  }

  String _nowLabel() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    final h = n.hour.toString().padLeft(2, '0');
    final min = n.minute.toString().padLeft(2, '0');
    return '$m-$d $h:$min';
  }
}

// ───────────────────────── 私有辅助 ─────────────────────────

/// 交易历史筛选枚举(全部/买入/卖出/分红/拆分)。
enum _TradeFilter { all, buy, sell, dividend, split }
