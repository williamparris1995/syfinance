// 持仓列表页(holding 模块入口)。消费 Task 4 HoldingBloc。
//
// 对齐 A-od 设计源:
//  - holdings-mobile.html(主布局):顶栏 + StatCard 2×2 + 资产配置饼图 + chips
//    横滚 + 持仓明细卡片行(每行 sparkline + 盈亏色块)+ 多币种汇总 + FAB。
//  - styles.css:御财金 #b08d57 / 盈绿 #2d8a6e / 亏红 #c4544d / 米白底。
//
// 照搬御财 debt 列表页模板(debts_page.dart):BlocBuilder<HoldingBloc,HoldingState>
// + 空/Loading/Error(isPendingBackend → "⏳ 待后端")处理 + DataCard + CurrencyBloc
// 多币种换算。无 i18n(中文硬编码,御财惯例)。
//
// 路由:本页由路由层(Task 11)注入 BlocProvider<HoldingBloc>;此处
// context.watch<HoldingBloc>()。点击持仓行 → context.push('/holdings/${id}')
// (路由 Task 11 接,这里先写导航调用)。
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_event.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_state.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/widgets/holding_pie_chart.dart';
import 'package:yucai_client/holding/presentation/widgets/holding_sparkline.dart';

/// 持仓列表页。对齐 A-od holdings-mobile.html。
///
/// 数据流:HoldingBloc.state(HoldingLoaded.summary + holdings) → StatCard / 饼图 /
/// 列表;CurrencyBloc.preferred + rates → 多币种换算(对齐 debt 页 toPreferredCents)。
class HoldingsPage extends StatefulWidget {
  const HoldingsPage({super.key});

  @override
  State<HoldingsPage> createState() => _HoldingsPageState();
}

class _HoldingsPageState extends State<HoldingsPage> {
  @override
  void initState() {
    super.initState();
    // 拉取全部持仓(typeFilter=null)。chips 筛选为前端二次过滤(对齐 brief:
    // proto ListHoldings 无 type 参数,bloc 前端过滤)。
    context.read<HoldingBloc>().add(const LoadHoldingsRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      // 创建入口移至全局 _TopBar(app_shell 路由感知创建按钮 /holdings/new)。
      body: BlocBuilder<HoldingBloc, HoldingState>(
        builder: (context, state) {
          // 优先从 last 恢复背景(Error/Submitting 携带上次成功)。
          final loaded = _loadedOf(state);
          if (state is HoldingLoading && loaded == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is HoldingError) {
            // isPendingBackend(⏳ 端点 fail)→ 空态 + 待后端提示,非真错误。
            if (state.isPendingBackend) {
              return _emptyState(pending: true);
            }
            // 真业务错误:有背景就降级渲染背景列表 + 顶部错误条;否则错误空态。
            if (loaded == null) return _errorState(state.message);
          }
          if (loaded == null || loaded.holdings.isEmpty) {
            return _emptyState();
          }
          return _content(loaded, state);
        },
      ),
    );
  }

  /// 从任意 state 取出 HoldingLoaded(从 HoldingError.last / HoldingSubmitting.last
  /// 恢复背景,对齐 debt 页 _debtsOf 模式)。
  HoldingLoaded? _loadedOf(HoldingState state) {
    if (state is HoldingLoaded) return state;
    HoldingState? probe = state;
    while (true) {
      if (probe is HoldingLoaded) return probe;
      if (probe is HoldingError) {
        probe = probe.last;
      } else if (probe is HoldingSubmitting) {
        probe = probe.last;
      } else {
        return null;
      }
      if (probe == null) return null;
    }
  }

  // ───────────────────────── 空态 / 错误态 ─────────────────────────

  Widget _emptyState({bool pending = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(LucideIcons.pieChart,
                size: 30, color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(pending ? '⏳ 待后端' : '还没有持仓',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            pending
                ? '持仓接口尚未接入,稍后再试'
                : '点击右下角「+」添加第一笔持仓',
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.alertCircle, size: 40, color: AppColors.negative),
            const SizedBox(height: 12),
            const Text('加载失败',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 主内容 ─────────────────────────

  Widget _content(HoldingLoaded loaded, HoldingState state) {
    final cstate = context.watch<CurrencyBloc>().state;
    final preferred = cstate.preferred;
    final rates = cstate.rates;

    // 持仓原币 → preferred 换算(对齐 debt 页 toPreferredCents 模式)。
    int toPreferred(int cents, String fromCode) =>
        toPreferredCents(cents, fromCode, rates, preferred);

    // 多币种:按原 currency 分桶换算前市值,供多币种汇总 + summary。
    // summary 来自 bloc 聚合(原币求和),这里按 preferred 重算汇总(多币种一致)。
    int sumMvPreferred = 0;
    int sumCostPreferred = 0;
    int sumPnlPreferred = 0;
    final byCurrency = <String, int>{}; // currency → preferred 合计市值
    for (final h in loaded.holdings) {
      final code = h.currency ?? 'CNY';
      final costCents = (h.quantity * h.avgCostCents).round();
      final mvP = toPreferred(h.marketValueCents, code);
      final costP = toPreferred(costCents, code);
      final pnlP = toPreferred(h.unrealizedPnlCents, code);
      sumMvPreferred += mvP;
      sumCostPreferred += costP;
      sumPnlPreferred += pnlP;
      byCurrency[code] = (byCurrency[code] ?? 0) + mvP;
    }
    final pnlRatio = sumCostPreferred > 0
        ? sumPnlPreferred / sumCostPreferred
        : 0.0;
    final upTotal = sumPnlPreferred >= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(count: loaded.holdings.length, totalCents: sumMvPreferred, preferred: preferred),
              const SizedBox(height: AppSpacing.lg),
              // StatCard 2×2(对齐 .m-stats)。
              _StatGrid(
                totalMv: sumMvPreferred,
                totalCost: sumCostPreferred,
                totalPnl: sumPnlPreferred,
                pnlRatio: pnlRatio,
                up: upTotal,
                preferred: preferred,
              ),
              const SizedBox(height: AppSpacing.lg),
              // 资产配置饼图(对齐 .m-alloc)。
              _AllocCard(slices: _slicesByType(loaded.holdings, toPreferred)),
              const SizedBox(height: AppSpacing.lg),
              // chips 筛选(对齐 .m-chips)。
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
                holdings: _filtered(loaded),
                preferred: preferred,
                toPreferred: toPreferred,
              ),
              const SizedBox(height: AppSpacing.lg),
              // 多币种汇总(对齐 .m-currency)。
              _CurrencyBar(
                totalCents: sumMvPreferred,
                byCurrency: byCurrency,
                preferred: preferred,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 当前 typeFilter 下的列表(bloc 已做前端过滤;这里按 HoldingLoaded.typeFilter
  /// 再过滤一次,防御 double-source 不一致)。
  List<Holding> _filtered(HoldingLoaded loaded) {
    final f = loaded.typeFilter;
    if (f == null) return loaded.holdings;
    return loaded.holdings
        .where((h) => h.securityType == f)
        .toList();
  }

  /// 按 SecurityType 聚合市值切片(饼图用),市值按 preferred 换算。
  List<HoldingSlice> _slicesByType(
      List<Holding> holdings, int Function(int, String) toPreferred) {
    final byType = <SecurityType, int>{};
    for (final h in holdings) {
      final t = h.securityType ?? SecurityType.other;
      final code = h.currency ?? 'CNY';
      byType[t] = (byType[t] ?? 0) + toPreferred(h.marketValueCents, code);
    }
    return [
      for (final t in byType.keys)
        HoldingSlice(type: t, valueCents: byType[t]!),
    ];
  }
}

// ───────────────────────── 顶栏 ─────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.count, required this.totalCents, required this.preferred});
  final int count;
  final int totalCents;
  final String preferred;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('持仓',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                '$count 只 · ${_fmtSymbol(totalCents, preferred)}',
                style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    fontFeatures: AppTypography.tabularFigures),
              ),
            ],
          ),
        ),
        // 刷新价格按钮 + last-updated(对齐 OD 原型 topbar-actions 的 icon-btn
        // 刷新,lucide refresh-cw 线性库)。submitting 时禁用 + loading spinner。
        const _RefreshAction(),
      ],
    );
  }
}

/// 顶栏刷新价格动作:触发 RefreshPricesRequested(Task 10 bloc 手动刷新),
/// syncing 时显示 loading + 禁用;last-updated 显示 lastPriceSyncedAt(HH:mm,
/// client 本地时间戳,无 intl 依赖故手格式化)。
class _RefreshAction extends StatelessWidget {
  const _RefreshAction();

  String _fmtHm(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HoldingBloc, HoldingState>(
      builder: (context, state) {
        final syncing = state is HoldingSubmitting;
        final last = state is HoldingLoaded ? state.lastPriceSyncedAt : null;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (last != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '上次更新 ${_fmtHm(last)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.muted,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ),
            IconButton(
              tooltip: '刷新价格',
              icon: syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.refreshCw, size: 18),
              onPressed: syncing
                  ? null
                  : () => context
                      .read<HoldingBloc>()
                      .add(const RefreshPricesRequested()),
            ),
          ],
        );
      },
    );
  }
}

// ───────────────────────── StatCard 2×2 ─────────────────────────

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.totalMv,
    required this.totalCost,
    required this.totalPnl,
    required this.pnlRatio,
    required this.up,
    required this.preferred,
  });
  final int totalMv;
  final int totalCost;
  final int totalPnl;
  final double pnlRatio;
  final bool up;
  final String preferred;

  @override
  Widget build(BuildContext context) {
    final pnlColor = up ? AppColors.positive : AppColors.negative;
    final pnlSign = up ? '+' : '-';
    final pnlText = '$pnlSign${_fmtSymbol(totalPnl.abs(), preferred)}';
    final pctText = '${pnlRatio >= 0 ? '+' : ''}${(pnlRatio * 100).toStringAsFixed(2)}%';
    return LayoutBuilder(
      builder: (ctx, c) {
        final isMobile = c.maxWidth < 600;
        final cards = <Widget>[
          _StatCard(
            label: '总市值',
            icon: LucideIcons.wallet,
            value: _fmtSymbol(totalMv, preferred),
          ),
          _StatCard(
            label: '总成本',
            icon: LucideIcons.banknote,
            value: _fmtSymbol(totalCost, preferred),
          ),
          _StatCard(
            label: '总盈亏',
            icon: up ? LucideIcons.trendingUp : LucideIcons.trendingDown,
            value: pnlText,
            valueColor: pnlColor,
          ),
          _StatCard(
            label: '收益率',
            icon: LucideIcons.percent,
            value: pctText,
            valueColor: pnlColor,
          ),
        ];
        if (isMobile) {
          // 2×2 网格(对齐 .m-stats 移动端)。childAspectRatio 较矮 + 卡内
          // FittedBox 保证窄屏不溢出。
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 2.4,
            children: cards,
          );
        }
        // desktop/tablet:四卡横排。
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1) const SizedBox(width: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.icon,
    required this.value,
    this.valueColor,
  });
  final String label;
  final IconData icon;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return DataCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: AppColors.muted),
              const SizedBox(width: 5),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.muted)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // FittedBox + 紧凑 padding:窄屏(2 列 mobile,卡高 ~37px)下数值
          // 按 scaleDown 缩放,避免 Column 垂直溢出。
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: valueColor ?? AppColors.fg,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 资产配置 ─────────────────────────

class _AllocCard extends StatelessWidget {
  const _AllocCard({required this.slices});
  final List<HoldingSlice> slices;

  @override
  Widget build(BuildContext context) {
    return DataCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('资产配置',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTypography.displayFamily,
                      fontFamilyFallback: AppTypography.displayFallback)),
            ],
          ),
          const SizedBox(height: 14),
          HoldingPieChart(slices: slices),
        ],
      ),
    );
  }
}

// ───────────────────────── chips 筛选 ─────────────────────────

class _ChipsRow extends StatelessWidget {
  const _ChipsRow({
    required this.holdings,
    required this.active,
    required this.onSelect,
  });
  final List<Holding> holdings;
  final SecurityType? active;
  final ValueChanged<SecurityType?> onSelect;

  @override
  Widget build(BuildContext context) {
    // 全部 + 出现过的 type(对齐 A-od chips 横滚 + count)。
    final present = <SecurityType>{};
    for (final h in holdings) {
      final t = h.securityType;
      if (t != null) present.add(t);
    }
    final entries = <(SecurityType?, String, int)>[
      (null, '全部', holdings.length),
      for (final t in SecurityType.values)
        if (present.contains(t))
          (t, kHoldingTypeLabels[t] ?? t.name,
              holdings.where((h) => h.securityType == t).length),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (type, label, count) = entries[i];
          final isActive = type == active;
          return _Chip(
            label: '$label $count',
            active: isActive,
            onTap: () => onSelect(type),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.accent : AppColors.surface,
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(
                color: active ? AppColors.accent : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? Colors.white : AppColors.fg,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 区头 ─────────────────────────

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('持仓明细',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback)),
        const SizedBox(width: 6),
        const Expanded(
          child: Divider(height: 1, color: AppColors.border),
        ),
        const SizedBox(width: 8),
        Text('$count 笔 · 按市值',
            style: const TextStyle(
                fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}

// ───────────────────────── 持仓列表(每行 + sparkline) ─────────────────────────

class _HoldingList extends StatelessWidget {
  const _HoldingList({
    required this.holdings,
    required this.preferred,
    required this.toPreferred,
  });
  final List<Holding> holdings;
  final String preferred;
  final int Function(int cents, String fromCode) toPreferred;

  @override
  Widget build(BuildContext context) {
    // 按市值(preferred 口径)降序(对齐原型 sort by mktValCNY)。
    final sorted = [...holdings]..sort((a, b) {
        final av = toPreferred(a.marketValueCents, a.currency ?? 'CNY');
        final bv = toPreferred(b.marketValueCents, b.currency ?? 'CNY');
        return bv - av;
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sorted.length; i++) ...[
          _HoldingCard(
            holding: sorted[i],
            preferred: preferred,
            toPreferred: toPreferred,
          ),
          if (i < sorted.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// 单持仓卡(对齐 A-od .acc):顶部 symbol + 名称 + 市值/现价;中部 sparkline +
/// 盈亏 pill;底部持有量/成本价/盈亏 meta。点击 → 详情页(路由 Task 11)。
class _HoldingCard extends StatelessWidget {
  const _HoldingCard({
    required this.holding,
    required this.preferred,
    required this.toPreferred,
  });
  final Holding holding;
  final String preferred;
  final int Function(int cents, String fromCode) toPreferred;

  @override
  Widget build(BuildContext context) {
    final code = holding.currency ?? 'CNY';
    final costCents = (holding.quantity * holding.avgCostCents).round();
    final mvP = toPreferred(holding.marketValueCents, code);
    final costP = toPreferred(costCents, code);
    final pnlP = toPreferred(holding.unrealizedPnlCents, code);
    final up = holding.unrealizedPnlCents >= 0;
    final pnlColor = up ? AppColors.positive : AppColors.negative;
    final pnlPct = costP != 0 ? (pnlP / costP) * 100 : (holding.pnlPct ?? 0.0);
    final typeLabel = holding.securityType != null
        ? (kHoldingTypeLabels[holding.securityType!] ?? '')
        : '';

    return DataCard(
      onTap: () => context.push('/holdings/${holding.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部:symbol + 名称 + 市值/现价。
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(holding.securitySymbol,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                fontFamily: AppTypography.displayFamily,
                                fontFamilyFallback:
                                    AppTypography.displayFallback)),
                        if (typeLabel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentSoft,
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Text(typeLabel,
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.accentHover,
                                    fontWeight: FontWeight.w500)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(holding.securityName,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_fmtSymbol(mvP, preferred),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFeatures: AppTypography.tabularFigures)),
                  if (holding.currentPriceCents != null)
                    Text(
                      '现价 ${_fmtRaw(holding.currentPriceCents!, code)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 中部:sparkline + 盈亏 pill。
          Row(
            children: [
              // sparkline:无历史价时用 [avgCost, currentPrice] 两点近似走势。
              HoldingSparkline(
                points: _sparkPoints(),
                up: up,
                width: 96,
                height: 30,
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pnlColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        up ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                        size: 13,
                        color: pnlColor),
                    const SizedBox(width: 3),
                    Text(
                      '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: pnlColor,
                          fontFeatures: AppTypography.tabularFigures),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // meta:持有量 / 成本价 / 盈亏。
          Wrap(
            spacing: 14,
            runSpacing: 5,
            children: [
              _MetaKV(
                  k: '持有量',
                  v: _fmtQuantity(holding.quantity)),
              _MetaKV(
                  k: '成本价',
                  v: _fmtRaw(holding.avgCostCents, code)),
              _MetaKV(
                k: '盈亏',
                v: '${pnlP >= 0 ? '+' : '-'}${_fmtSymbol(pnlP.abs(), preferred)}',
                vColor: pnlColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// sparkline 采样:无历史时用 [avgCost, currentPrice] 两点近似
  /// (currentPrice > avgCost → 上升);currentPrice 缺失 → 平线。
  List<double> _sparkPoints() {
    final cur = holding.currentPriceCents;
    if (cur != null) {
      return [holding.avgCostCents.toDouble(), cur.toDouble()];
    }
    return [
      holding.avgCostCents.toDouble(),
      holding.avgCostCents.toDouble()
    ];
  }
}

class _MetaKV extends StatelessWidget {
  const _MetaKV({required this.k, required this.v, this.vColor});
  final String k;
  final String v;
  final Color? vColor;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
        children: [
          TextSpan(text: '$k '),
          TextSpan(
            text: v,
            style: TextStyle(
                color: vColor ?? AppColors.fg,
                fontWeight: vColor != null ? FontWeight.w600 : FontWeight.w400,
                fontFeatures: AppTypography.tabularFigures),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 多币种汇总 ─────────────────────────

class _CurrencyBar extends StatelessWidget {
  const _CurrencyBar({
    required this.totalCents,
    required this.byCurrency,
    required this.preferred,
  });
  final int totalCents;
  final Map<String, int> byCurrency; // currency → preferred 合计市值
  final String preferred;

  @override
  Widget build(BuildContext context) {
    return DataCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('本币合计',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              Text('汇率基准 · $preferred',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 6),
          Text(_fmtSymbol(totalCents, preferred),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  fontFeatures: AppTypography.tabularFigures)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              for (final entry in byCurrency.entries)
                _CurrencyItem(
                    code: entry.key,
                    cents: entry.value,
                    preferred: preferred),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurrencyItem extends StatelessWidget {
  const _CurrencyItem({
    required this.code,
    required this.cents,
    required this.preferred,
  });
  final String code;
  final int cents; // 已是 preferred 口径
  final String preferred;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$code ',
            style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.muted,
                fontFeatures: AppTypography.tabularFigures)),
        Text(_fmtSymbol(cents, preferred),
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                fontFeatures: AppTypography.tabularFigures)),
      ],
    );
  }
}

// ───────────────────────── helpers ─────────────────────────

/// 千分位 + 两位小数 + 货币符号前缀(对齐 debt 页 _fmtSymbol)。
String _fmtSymbol(int cents, String currencyCode) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final fen = (abs % 100).toString().padLeft(2, '0');
  final s = yuan.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '$sign${currencySymbol(currencyCode)}$buf.$fen';
}

/// 单位价/原值格式化(cents → 2 位小数 + 货币符号,对齐原型 fmtRaw)。
String _fmtRaw(int cents, String currencyCode) {
  final v = (cents / 100).toStringAsFixed(2);
  return '${currencySymbol(currencyCode)}$v';
}

/// 持有量格式化(份额,2 位小数,trim 尾零)。
String _fmtQuantity(double q) {
  final s = q.toStringAsFixed(4);
  // 去尾零 + 可能的点。
  var out = s;
  if (out.contains('.')) {
    out = out.replaceFirst(RegExp(r'0+$'), '');
    out = out.replaceFirst(RegExp(r'\.$'), '');
  }
  return out;
}
