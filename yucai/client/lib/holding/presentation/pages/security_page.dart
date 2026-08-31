// Security 主数据管理页(列表 / 搜索 / 创建 / 价格管理)。消费 Task 4 HoldingBloc。
//
// 对齐 A-od 设计源:
//  - security-mobile.html(主布局):顶栏 + 搜索框 + 行情源 provider bar +
//    证券列表卡(symbol/name/type/exchange/currency/现价)+ 行内「改价」+
//    FAB 创建 sheet(symbol/name/type/exchange/currency)。
//  - styles.css:御财金 #b08d57 / 米白底 / accentSoft 提示条。
//
// 照搬御财 debt 列表页模板(debts_page.dart):BlocBuilder<HoldingBloc,HoldingState>
// + 空/Loading/Error(isPendingBackend → ⏳ 待后端)处理 + DataCard + SectionHeader。
//
// 数据流:LoadSecuritiesRequested → HoldingLoaded.securities 列表;
//   SearchSecuritiesRequested(query)(300ms debounce)→ 后端搜索;
//   CreateSecurityRequested(SecurityParams)→ 创建后 bloc 自刷新 securities;
//   UpdatePriceRequested(id, priceCents)→ 改价后 bloc 自刷新;
//   RefreshPricesRequested → repo.syncPrices(server SinaProvider)→ 自刷新。
//
// provider bar:server B-sync 已实现(scheduler + SinaProvider + SyncPrices),
//   provider 链固定 → 行情源只读 chip「新浪财经」+ 上次同步时间 + 手动刷新。无 i18n(中文硬编码)。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_event.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_state.dart';
import 'package:yucai_client/holding/presentation/widgets/holding_module_tabs.dart';

/// Security 主数据管理页。对齐 A-od security-mobile.html。
///
/// 路由:本页由路由层(Task 11)注入 BlocProvider<HoldingBloc>;此处
/// context.read<HoldingBloc>()。创建走 [CreateSecuritySheet](bottom sheet),
/// 改价走 [showDialog]<[_PriceEditDialog>]。
class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  // 类型筛选 chip(对齐 OD .chips 全部/股票/ETF/基金 + count)。前端过滤,
  // 不走 backend:保持 chip 计数稳定(全量始终可见),交互零延迟。
  SecurityType? _typeFilter;

  @override
  void initState() {
    super.initState();
    // 拉取全部证券主数据。搜索为后端 SearchSecurities(query),空 query 不触发。
    context.read<HoldingBloc>().add(const LoadSecuritiesRequested());
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 搜索 debounce 300ms:空 query → LoadSecuritiesRequested(全部);非空 →
  /// SearchSecuritiesRequested(query)(对齐 brief「SearchSecuritiesRequested(query)
  /// 或前端过滤」,此处用后端搜索事件)。
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = _searchCtrl.text.trim();
      final bloc = context.read<HoldingBloc>();
      if (q.isEmpty) {
        bloc.add(const LoadSecuritiesRequested());
      } else {
        bloc.add(SearchSecuritiesRequested(q));
      }
    });
  }

  /// 从 state 取 securities(优先 HoldingLoaded;Error/Submitting 从 last 恢复背景)。
  List<Security> _securitiesOf(HoldingState state) {
    HoldingState? probe = state;
    while (true) {
      if (probe is HoldingLoaded) return probe.securities;
      if (probe is HoldingError) {
        probe = probe.last;
      } else if (probe is HoldingSubmitting) {
        probe = probe.last;
      } else {
        return const [];
      }
      if (probe == null) return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yucai.bg,
      // 创建 Security FAB(对齐原型 .fab;所有断点 + 空状态都可创建)。
      // heroTag: null 禁 Hero —— indexedStack 保活多 branch 时避免与其它 branch
      // FAB 共用默认 Hero tag 冲突(参见 fab-hero-fix)。
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        key: const ValueKey('createFab'),
        onPressed: () => _openCreateSheet(context),
        backgroundColor: context.yucai.accent,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
      body: Column(
        children: [
          // 模块内 tab(Task 2 HoldingModuleTabs,Security 管理 active 金下划线)。
          // 固定于内容区顶部常驻,不随滚动消失(对齐 Task 3 holdings_page 模式)。
          const HoldingModuleTabs(),
          Expanded(
            child: BlocBuilder<HoldingBloc, HoldingState>(
              builder: (context, state) {
                final securities = _securitiesOf(state);
          final loading = state is HoldingLoading && securities.isEmpty;
          final isPendingBackend =
              state is HoldingError && state.isPendingBackend;

          if (loading) return const Center(child: CircularProgressIndicator());
          // ⏳B 端点 fail(若后端把 ListSecurities 标记为 ⏳):降级空态 + 待后端提示。
          if (state is HoldingError &&
              securities.isEmpty &&
              !isPendingBackend) {
            return _errorState(state.message);
          }
          if (securities.isEmpty) return _emptyState(pending: isPendingBackend);
          return _content(securities, state);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(List<Security> securities, HoldingState state) {
    // 类型 chip 前端过滤(对齐 OD .chips)。`securities`(全量)用于 chip 计数 +
    // 顶栏 N;`filtered` 用于列表/区头计数。
    final filtered = _typeFilter == null
        ? securities
        : securities.where((s) => s.securityType == _typeFilter).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PageHead(count: securities.length),
              const SizedBox(height: AppSpacing.md),
              _searchField(),
              const SizedBox(height: AppSpacing.md),
              const _ProviderBar(),
              const SizedBox(height: AppSpacing.md),
              // 类型筛选 chips(对齐 OD .chips:全部/股票/ETF/基金 + count)。
              // 前端过滤,计数来自全量 securities(稳定不随筛选消失)。
              _ChipsRow(
                securities: securities,
                active: _typeFilter,
                onSelect: (t) => setState(() => _typeFilter = t),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionHead(count: filtered.length),
              const SizedBox(height: AppSpacing.sm),
              // 筛选 / 搜索后空结果 → 友好空态(对齐原型 .search-empty)。
              if (filtered.isEmpty)
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      '未找到匹配的证券',
                      style: TextStyle(color: context.yucai.muted, fontSize: 12),
                    ),
                  ),
                )
              else
                _SecurityList(
                  securities: filtered,
                  submitting: state is HoldingSubmitting,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      key: const ValueKey('searchField'),
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: '搜索 symbol / 名称…',
        prefixIcon: Icon(LucideIcons.search, size: 18, color: context.yucai.muted),
        filled: true,
        fillColor: context.yucai.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: context.yucai.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: context.yucai.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: context.yucai.accent),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        isDense: true,
      ),
    );
  }

  void _openCreateSheet(BuildContext context) {
    // bottom sheet 在根 Navigator overlay 中创建,不继承页面 BlocProvider,
    // 需用 BlocProvider.value 注入同一 HoldingBloc(对齐 trade_sheet 推送 route 模式)。
    final bloc = context.read<HoldingBloc>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.yucai.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => BlocProvider<HoldingBloc>.value(
        value: bloc,
        child: const CreateSecuritySheet(),
      ),
    );
  }

  Widget _emptyState({bool pending = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.yucai.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              LucideIcons.layers,
              size: 30,
              color: context.yucai.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            pending ? '行情接口待后端' : '还没有证券',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            pending ? '⏳ 自动同步未启用 · B 子项目' : '点击右下角「+」创建第一个证券',
            style: TextStyle(color: context.yucai.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.alertCircle,
              size: 36,
              color: context.yucai.negative,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '加载失败',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.yucai.muted, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => context.read<HoldingBloc>().add(
                const LoadSecuritiesRequested(),
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── 页头(对齐 OD .page-head) ─────────────────────────

class _PageHead extends StatelessWidget {
  const _PageHead({required this.count});
  final int count;

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
              // h1 衬线「Security 管理」(对齐 OD .page-title h1 font-display serif)。
              Text(
                'Security 管理',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppTypography.displayFamily,
                  fontFamilyFallback: AppTypography.displayFallback,
                  color: context.yucai.fg,
                  height: 1.15,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 5),
              // sub:共 N 个证券 · 行情源 新浪财经(对齐 OD .page-title .sub;
              // 同步时间交由 _ProviderBar 单独展示避免冗余,provider 名金色强调)。
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    color: context.yucai.muted,
                    fontSize: 13,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                  children: [
                    TextSpan(text: '共 $count 个证券 · 行情源 '),
                    TextSpan(
                      text: '新浪财经',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: context.yucai.accentDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 刷新列表按钮(对齐 OD .icon-btn refresh-cw;⏳B 自动刷新未启用,手动重载)。
        IconButton(
          key: const ValueKey('refreshBtn'),
          tooltip: '刷新列表',
          onPressed: () =>
              context.read<HoldingBloc>().add(const LoadSecuritiesRequested()),
          icon: Icon(LucideIcons.refreshCw, color: context.yucai.muted),
        ),
      ],
    );
  }
}

// ───────────────────────── 类型筛选 chips(对齐 OD .chips) ─────────────────────────

/// 类型筛选 chip 行。复用 holdings_page._ChipsRow 模式(同模块视觉一致:
/// active = 御财金实底 + 白字;非 active = 白底 + 灰字)。前端过滤,计数来自
/// 全量 [securities](不随筛选消失),保证「全部 N」始终可见。
class _ChipsRow extends StatelessWidget {
  const _ChipsRow({
    required this.securities,
    required this.active,
    required this.onSelect,
  });

  final List<Security> securities;
  final SecurityType? active;
  final ValueChanged<SecurityType?> onSelect;

  @override
  Widget build(BuildContext context) {
    // 全部 + 出现过的 type(对齐 OD .chips 全部/股票/ETF/基金 + count)。
    final present = <SecurityType>{};
    for (final s in securities) {
      present.add(s.securityType);
    }
    final entries = <(SecurityType?, String, int)>[
      (null, '全部', securities.length),
      for (final t in SecurityType.values)
        if (present.contains(t))
          (
            t,
            _typeLabel(t),
            securities.where((s) => s.securityType == t).length,
          ),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (type, label, cnt) = entries[i];
          return _Chip(
            label: '$label $cnt',
            active: type == active,
            onTap: () => onSelect(type),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? context.yucai.accent : context.yucai.surface,
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(
              color: active ? context.yucai.accent : context.yucai.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? Colors.white : context.yucai.fg,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 行情源 + 同步状态条 ─────────────────────────

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
        color: context.yucai.accentSoft,
        border: Border.all(color: context.yucai.accentSoft),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(children: [
        Icon(LucideIcons.globe, size: 16, color: context.yucai.accentDeep),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: '自动同步 · 行情源 ',
                    style: TextStyle(fontSize: 11.5, color: context.yucai.muted)),
                TextSpan(text: _providerName,
                    style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w600,
                        color: context.yucai.accentDeep)),
              ])),
              Text(synced == null ? '尚未同步' : '上次同步 ${_fmtTime(synced)}',
                  style: TextStyle(fontSize: 10.5, color: context.yucai.muted)),
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
              : Icon(LucideIcons.refreshCw, size: 16, color: context.yucai.accentDeep),
        ),
      ]),
    );
  }

  String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
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
        const Text(
          '证券列表',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: AppTypography.displayFamily,
            fontFamilyFallback: AppTypography.displayFallback,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '共 $count 个',
          style: TextStyle(
            fontSize: 12.5,
            color: context.yucai.muted,
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── 证券列表(响应式) ─────────────────────────

class _SecurityList extends StatelessWidget {
  const _SecurityList({required this.securities, required this.submitting});
  final List<Security> securities;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    // mobile 单列 Column / tablet+ auto-fill GridView,对齐 debts_page._DebtList。
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 14.0;
        if (c.maxWidth <= Breakpoints.mobileUpper) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < securities.length; i++) ...[
                _SecurityCard(security: securities[i], submitting: submitting),
                if (i < securities.length - 1) const SizedBox(height: gap),
              ],
            ],
          );
        }
        int cols;
        if (c.maxWidth < Breakpoints.desktopLower) {
          cols = 2;
        } else {
          const colWidth = 320.0;
          cols = ((c.maxWidth + gap) / (colWidth + gap)).floor();
          if (cols < 1) cols = 1;
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            mainAxisExtent: 252,
          ),
          itemCount: securities.length,
          itemBuilder: (_, i) =>
              _SecurityCard(security: securities[i], submitting: submitting),
        );
      },
    );
  }
}

// ───────────────────────── 证券卡 ─────────────────────────

/// 单张证券卡。对齐原型 .acc.sec-card:
///  - head:symbol + type 中文标签 / name / exchange·currency / 现价(大字 mono)
///  - foot:⏳B 自动同步 disabled + 「改价」行内编辑按钮
class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.security, required this.submitting});
  final Security security;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.of(context).size.width <= Breakpoints.mobileUpper;
    return DataCard(
      key: ValueKey('security-card-${security.id}'),
      child: isMobile ? _compact(context) : _full(context),
    );
  }

  Widget _full(BuildContext context) {
    final typeLabel = _typeLabel(security.securityType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // row1:symbol + type 标签
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              security.symbol,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
            _TypeTag(label: typeLabel),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          security.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13.5, color: context.yucai.fg),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            _MetaItem(
              icon: LucideIcons.landmark,
              text: security.exchange?.isNotEmpty == true
                  ? security.exchange!
                  : '—',
            ),
            _MetaItem(icon: LucideIcons.coins, text: security.currency),
          ],
        ),
        const SizedBox(height: 10),
        // 现价(大字 mono)+ ⏳B 自动同步 disabled + 改价
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '现价',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.5,
                      color: context.yucai.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fmtPrice(security.currentPriceCents, security.currency),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.15,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _cardFooter(context),
      ],
    );
  }

  Widget _compact(BuildContext context) {
    final typeLabel = _typeLabel(security.securityType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                      Text(
                        security.symbol,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFeatures: AppTypography.tabularFigures,
                        ),
                      ),
                      _TypeTag(label: typeLabel),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    security.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.yucai.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${security.exchange?.isNotEmpty == true ? security.exchange! : '—'} · ${security.currency}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.yucai.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '现价',
                  style: TextStyle(fontSize: 10, color: context.yucai.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  _fmtPrice(security.currentPriceCents, security.currency),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        _cardFooter(context),
      ],
    );
  }

  /// 卡片底栏:「改价」按钮(右对齐)。同步状态由页顶 _ProviderBar 统一展示。
  Widget _cardFooter(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 11),
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.yucai.border, width: 1.0)),
      ),
      child: Row(
        children: [
          const Spacer(),
          _EditPriceBtn(security: security, submitting: submitting),
        ],
      ),
    );
  }
}

// ───────────────────────── 改价按钮 + 编辑 Dialog ─────────────────────────

class _EditPriceBtn extends StatelessWidget {
  const _EditPriceBtn({required this.security, required this.submitting});
  final Security security;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: submitting ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        key: ValueKey('editPriceBtn-${security.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: submitting
            ? null
            : () => showDialog<void>(
                context: context,
                // dialog 在根 Navigator overlay 中,需注入同一 HoldingBloc。
                builder: (_) => BlocProvider<HoldingBloc>.value(
                  value: context.read<HoldingBloc>(),
                  child: _PriceEditDialog(security: security),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.pencil,
                size: 15,
                color: submitting ? context.yucai.muted : context.yucai.accent,
              ),
              const SizedBox(width: 4),
              Text(
                '改价',
                style: TextStyle(
                  color: submitting ? context.yucai.muted : context.yucai.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 改价 Dialog(对齐原型编辑现价 sheet)。提交 → UpdatePriceRequested(id, priceCents)。
/// 提交校验:正数(对齐原型「现价无效,需为正数」)。
class _PriceEditDialog extends StatefulWidget {
  const _PriceEditDialog({required this.security});
  final Security security;

  @override
  State<_PriceEditDialog> createState() => _PriceEditDialogState();
}

class _PriceEditDialogState extends State<_PriceEditDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    // 初始值:当前价(元,2 位小数回显)。
    final yuan = (widget.security.currentPriceCents / 100).toStringAsFixed(2);
    _ctrl = TextEditingController(text: yuan);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final v = double.tryParse(_ctrl.text.trim());
    if (v == null || !v.isFinite || v <= 0) {
      AppToast.show(context, '现价无效,需为正数', type: ToastType.warning);
      return;
    }
    final priceCents = (v * 100).round();
    context.read<HoldingBloc>().add(
      UpdatePriceRequested(id: widget.security.id, priceCents: priceCents),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final sym = currencySymbol(widget.security.currency);
    return AlertDialog(
      title: const Text('编辑现价'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.security.symbol} · ${widget.security.name}',
            style: TextStyle(fontSize: 12.5, color: context.yucai.muted),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('priceEditField'),
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '现价',
              prefixText: '$sym ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('priceEditCancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('priceEditSave'),
          onPressed: _save,
          style: FilledButton.styleFrom(backgroundColor: context.yucai.accent),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

// ───────────────────────── 创建 Security bottom sheet ─────────────────────────

/// 创建 Security 表单(对齐原型 createForm sheet)。
/// 字段:symbol / name / type(SecurityType 选择)/ exchange / currency。
/// 提交 → CreateSecurityRequested(SecurityParams(...))。
class CreateSecuritySheet extends StatefulWidget {
  const CreateSecuritySheet({super.key});

  @override
  State<CreateSecuritySheet> createState() => _CreateSecuritySheetState();
}

class _CreateSecuritySheetState extends State<CreateSecuritySheet> {
  final _symbolCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _exchangeCtrl = TextEditingController();
  SecurityType _type = SecurityType.stock;
  String _currency = 'CNY';
  bool _saving = false;

  @override
  void dispose() {
    _symbolCtrl.dispose();
    _nameCtrl.dispose();
    _exchangeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final symbol = _symbolCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (symbol.isEmpty) {
      AppToast.show(context, '请输入 Symbol', type: ToastType.warning);
      return;
    }
    if (name.isEmpty) {
      AppToast.show(context, '请输入名称', type: ToastType.warning);
      return;
    }
    setState(() => _saving = true);
    context.read<HoldingBloc>().add(
      CreateSecurityRequested(
        SecurityParams(
          symbol: symbol,
          name: name,
          type: _type,
          exchange: _exchangeCtrl.text.trim().isEmpty
              ? null
              : _exchangeCtrl.text.trim(),
          currency: _currency,
        ),
      ),
    );
    // 监听 bloc 状态变化由 BlocListener 处理(成功/失败关闭 sheet)。
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // 单 BlocListener:监听 Submitting → (Loaded 成功 / Error 失败)。
    return BlocListener<HoldingBloc, HoldingState>(
      listenWhen: (prev, curr) =>
          _saving &&
          prev is HoldingSubmitting &&
          (curr is HoldingLoaded || curr is HoldingError),
      listener: (context, state) {
        setState(() => _saving = false);
        if (state is HoldingError) {
          AppToast.show(
            context,
            '创建失败:${state.message}',
            type: ToastType.error,
          );
          return;
        }
        AppToast.show(
          context,
          '✓ 已创建:${_symbolCtrl.text.trim()}',
          type: ToastType.success,
        );
        Navigator.of(context).pop();
      },
      child: Padding(
        key: const ValueKey('createSheet'),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // grabber
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.yucai.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '新建 Security',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: AppTypography.displayFamily,
                            fontFamilyFallback: AppTypography.displayFallback,
                          ),
                        ),
                        Text(
                          'CreateSecurity · ✅ 已实现',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.yucai.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: Icon(LucideIcons.x, color: context.yucai.muted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey('symbolField'),
                controller: _symbolCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Symbol *',
                  hintText: 'AAPL',
                  helperText: '如 AAPL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('nameField'),
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '名称 *',
                  hintText: 'Apple Inc.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<SecurityType>(
                      key: const ValueKey('typeField'),
                      value: _type,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final t in SecurityType.values)
                          DropdownMenuItem(
                            value: t,
                            child: Text(_typeLabel(t)),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _type = v ?? _type),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('currencyField'),
                      value: _currency,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'CNY', child: Text('CNY')),
                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                        DropdownMenuItem(value: 'HKD', child: Text('HKD')),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _currency = v ?? _currency),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('exchangeField'),
                controller: _exchangeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Exchange / Market *',
                  hintText: 'NASDAQ / SH / HK',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AbsorbPointer(
                absorbing: _saving,
                child: FilledButton(
                  key: const ValueKey('createSubmitBtn'),
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.yucai.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('创建'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 卡内小组件 ─────────────────────────

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: context.yucai.accentSoft,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.yucai.accentDeep,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: context.yucai.muted),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            color: context.yucai.muted,
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── helpers ─────────────────────────

/// SecurityType → 中文标签(对齐原型 mock-data.js TYPE_META)。
String _typeLabel(SecurityType t) {
  switch (t) {
    case SecurityType.stock:
      return '股票';
    case SecurityType.fund:
      return '基金';
    case SecurityType.etf:
      return 'ETF';
    case SecurityType.bond:
      return '债券';
    case SecurityType.gold:
      return '黄金';
    case SecurityType.option:
      return '期权';
    case SecurityType.other:
      return '其他';
  }
}

/// 千分位 + 2 位小数 + 货币符号前缀。对齐 debts_page._fmtSymbol。
String _fmtPrice(int cents, String currencyCode) {
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
