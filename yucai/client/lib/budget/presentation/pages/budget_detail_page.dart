// 预算详情页(Task 9)。消费 Task 7 BudgetBloc(LoadDetailRequested by id →
// BudgetDetailLoaded(budget 含 items))/ Task 6 BudgetView + BudgetItemView。
//
// 设计源(OD 原型):design-output/budget/budget-detail-{desktop,tablet,mobile}.html
//  + styles.css + mock-data.js。**大 UI 对齐原型**(2026-07,照 goal 对齐范式):
//   ① 头部 hero 卡:大 ConicProgressRing(UsagePct clamp[0,1],超支红 / 正常金)+
//      Name + Month + status pill + TotalActual/TotalAmount + Remaining + UsagePct。
//   ② per-item 列表(表格风格):category 账户名 + Planned + Actual + mini 进度条 +
//      占比% + 剩余/超支 + 超支 tag。
//   ③ AppBar actions:编辑(lucide pencil)→ push '/budgets/:id/edit';
//      删除(lucide trash2)→ confirm dialog → dispatch + pop。
//
// account name lookup 简化(brief Step 2):BudgetItemView.accountName 由 ds 在
// mapper 时填(需 batch account repo lookup)—— defer;MVP 显
// item.accountName ?? '分类账户' 占位,真名 lookup 后续接入。
//
// 进度环:ConicProgressRing(复用 core/widgets,由 goal 对齐产出;不重写)。
//
// 路由:本页由路由层(Task 11)注入 BlocProvider<BudgetBloc>;此处
// context.read<BudgetBloc>().add(LoadDetailRequested(id))。
//
// 无 i18n(中文硬编码,御财惯例;与 goal/holding 列表页一致)。
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_bloc.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_event.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_state.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/conic_progress_ring.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';

/// 超支红(brief 指定 #c0392b,比 AppColors.negative 更暗,区分「超预算」)。
/// 与 budget_list_page 一致(同色)。
const Color _kOverBudgetRed = Color(0xFFC0392B);

/// 占位账户名(brief Step 2:accountName null 时显示,真名 lookup defer)。
const String _kAccountPlaceholder = '分类账户';

/// 预算详情页。对齐 goal_detail_page 范式 + OD 原型 hero + per-item 表格。
class BudgetDetailPage extends StatefulWidget {
  const BudgetDetailPage({super.key, required this.id});

  final String id;

  @override
  State<BudgetDetailPage> createState() => _BudgetDetailPageState();
}

class _BudgetDetailPageState extends State<BudgetDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<BudgetBloc>().add(LoadDetailRequested(widget.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.fg,
        elevation: 0,
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('预算详情'),
        actions: [
          // 编辑(lucide pencil)→ push '/budgets/:id/edit'。
          IconButton(
            key: const ValueKey('budgetEditAction'),
            tooltip: '编辑',
            icon: const Icon(LucideIcons.pencil, size: 18),
            onPressed: () => context.push('/budgets/${widget.id}/edit'),
          ),
          // 删除(lucide trash2)→ confirm dialog → dispatch + pop。
          IconButton(
            key: const ValueKey('budgetDeleteAction'),
            tooltip: '删除',
            icon: const Icon(LucideIcons.trash2, size: 18),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: BlocBuilder<BudgetBloc, BudgetState>(
        builder: (context, state) {
          if (state is BudgetLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is BudgetDetailLoaded) {
            return _body(state.budget);
          }
          if (state is BudgetError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(state.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted)),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // ───────────────────────── body(① hero + ② per-item) ─────────────────────────

  Widget _body(BudgetView b) {
    final isMobile = MediaQuery.of(context).size.width <= 720;
    return ListView(
      padding: isMobile
          ? const EdgeInsets.fromLTRB(16, 14, 16, 32)
          : const EdgeInsets.fromLTRB(36, 24, 36, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _headerCard(b),
                const SizedBox(height: AppSpacing.sm),
                _itemsCard(b),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────── ① 头部 hero 卡 ─────────────────────────

  /// 大 ConicProgressRing(UsagePct clamp[0,1],超支红 / 正常金)+ Name + Month +
  /// status pill + TotalActual/TotalAmount + Remaining。
  Widget _headerCard(BudgetView b) {
    final over = b.isOverBudget;
    final ringColor = over ? _kOverBudgetRed : AppColors.accent;
    // 总进度环 value 限定 [0,1];超支满环红色。
    final rawPct = b.totalAmountCents == 0
        ? 0.0
        : b.totalActualCents / b.totalAmountCents;
    final ringValue = rawPct.clamp(0.0, 1.0);
    final pctLabel = '${b.usagePct.toStringAsFixed(1)}%';
    final remaining = b.totalRemainingCents;
    final currency = b.currencyCode;
    final accentColor = over ? _kOverBudgetRed : AppColors.accent;

    return DataCard(
      key: const ValueKey('budgetDetailHero'),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左侧 status 色条(对齐原型 .detail-hero.behind/.completed border-left)。
            Container(
              width: 4,
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 大 ConicProgressRing(对齐原型 .ring-lg)。
                  ConicProgressRing(
                    key: const ValueKey('budgetDetailRing'),
                    progress: ringValue,
                    color: ringColor,
                    pctLabel: pctLabel,
                    subLabel: '使用率',
                    size: ConicRingSize.lg,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name + status pill。
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Text(b.name,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: AppTypography.displayFamily,
                                    fontFamilyFallback:
                                        AppTypography.displayFallback)),
                            _StatusPill(
                                label: over ? '超支' : '正常',
                                icon: over
                                    ? LucideIcons.alertTriangle
                                    : LucideIcons.checkCircle2,
                                color: over ? _kOverBudgetRed : AppColors.positive,
                                soft: true),
                            _StatusPill(
                                label: b.month,
                                icon: LucideIcons.calendar,
                                color: AppColors.accent,
                                soft: true),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        // 实际 / 总额(大数字 + 灰总额)。
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(
                                _fmtSymbol(b.totalActualCents, currency),
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: over
                                        ? _kOverBudgetRed
                                        : AppColors.fg,
                                    fontFeatures:
                                        AppTypography.tabularFigures),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('/',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.border,
                                    fontFeatures:
                                        AppTypography.tabularFigures)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _fmtSymbol(b.totalAmountCents, currency),
                                style: const TextStyle(
                                    fontSize: 16,
                                    color: AppColors.muted,
                                    fontFeatures:
                                        AppTypography.tabularFigures),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // 剩余/超支 pill + 总使用率。
                        Row(
                          children: [
                            Container(
                              key: const ValueKey('budgetDetailRemainPill'),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (over
                                        ? _kOverBudgetRed
                                        : AppColors.accent)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                      over
                                          ? LucideIcons.alertTriangle
                                          : LucideIcons.checkCircle2,
                                      size: 12,
                                      color: over
                                          ? _kOverBudgetRed
                                          : AppColors.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    over
                                        ? '超支 ${_fmtSymbol(remaining.abs(), currency)}'
                                        : '剩余 ${_fmtSymbol(remaining, currency)}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: over
                                            ? _kOverBudgetRed
                                            : AppColors.accent,
                                        fontFeatures:
                                            AppTypography.tabularFigures),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── ② per-item 列表 ─────────────────────────

  /// per-item 卡:每行 account 名 + Planned + Actual + mini 进度条 + 占比% + 剩余 +
  /// 超支 tag(对齐原型 .item-table + .it-bar + .over-tag)。
  Widget _itemsCard(BudgetView b) {
    final currency = b.currencyCode;
    final items = b.items;
    // 按实际支出降序(对齐原型 sorted by actual desc)。
    final sorted = List<BudgetItemView>.from(items)
      ..sort((a, c) => c.actualAmountCents.compareTo(a.actualAmountCents));
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.pieChart, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              const Text('分类明细',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTypography.displayFamily,
                      fontFamilyFallback: AppTypography.displayFallback)),
              const SizedBox(width: 8),
              Text('(${sorted.length} 项)',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('暂无明细条目',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ),
            )
          else
            for (var i = 0; i < sorted.length; i++) ...[
              _itemRow(sorted[i], currency, b.totalActualCents),
              if (i < sorted.length - 1) ...[
                const SizedBox(height: 10),
                Container(height: 1, color: AppColors.border),
                const SizedBox(height: 10),
              ],
            ],
        ],
      ),
    );
  }

  /// 单 item 行:account 名 + Planned/Actual + mini 进度条 + 占比% + 剩余 + 超支 tag。
  ///
  /// account name lookup 简化(brief Step 2):accountName null → '分类账户' 占位,
  /// 真名 lookup defer。
  Widget _itemRow(BudgetItemView item, String currency, int totalActual) {
    final over = item.isOverBudget;
    final progressColor = over ? _kOverBudgetRed : AppColors.accent;
    final rawPct = item.plannedAmountCents == 0
        ? 0.0
        : item.actualAmountCents / item.plannedAmountCents;
    final progressValue = rawPct.clamp(0.0, 1.0);
    final pctLabel = '${item.usagePct.toStringAsFixed(1)}%';
    final remaining = item.remainingCents;
    // 占比%(相对 totalActual)。
    final sharePct = totalActual == 0
        ? 0.0
        : item.actualAmountCents / totalActual * 100;
    // MVP:accountName null → 占位(真名 lookup defer,见 class doc)。
    final name = item.accountName ?? _kAccountPlaceholder;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部:account 名(左)+ 占比% pill(右)。
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // 账户图标方块(对齐原型 .it-ico)。
                        Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: progressColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(LucideIcons.wallet,
                              size: 15, color: progressColor),
                        ),
                        Expanded(
                          child: Text(name,
                              key: const ValueKey('budgetDetailItemName'),
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 14,
                      runSpacing: 3,
                      children: [
                        _MetaKV(
                          k: '计划',
                          v: _fmtSymbol(item.plannedAmountCents, currency),
                        ),
                        _MetaKV(
                          k: '实际',
                          v: _fmtSymbol(item.actualAmountCents, currency),
                          vColor: over ? _kOverBudgetRed : AppColors.fg,
                        ),
                        _MetaKV(
                          k: '占比',
                          v: '${sharePct.toStringAsFixed(1)}%',
                        ),
                        _MetaKV(
                          k: remaining >= 0 ? '剩余' : '超支',
                          v: _fmtSymbol(remaining.abs(), currency),
                          vColor:
                              over ? _kOverBudgetRed : AppColors.positive,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 占比% pill(超支红 / 正常金)。
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(pctLabel,
                    key: const ValueKey('budgetDetailItemPct'),
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: progressColor,
                        fontFeatures: AppTypography.tabularFigures)),
            ),
            ],
          ),
          const SizedBox(height: 8),
          // mini 进度条(actual/planned clamped [0,1],对齐原型 .it-bar)。
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              key: const ValueKey('budgetDetailItemBar'),
              value: progressValue,
              minHeight: 7,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          // 超支 tag(对齐原型 .over-tag)。
          if (over) ...[
            const SizedBox(height: 6),
            Container(
              key: const ValueKey('budgetDetailOverMarker'),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _kOverBudgetRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.alertTriangle,
                      size: 11, color: _kOverBudgetRed),
                  const SizedBox(width: 3),
                  Text('超 ${_fmtSymbol(remaining.abs(), currency)}',
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _kOverBudgetRed)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────────── 删除确认 ─────────────────────────

  /// 删除确认 dialog(对齐 goal_detail_page._confirmDelete):showDialog<bool> →
  /// 确认 → dispatch DeleteBudgetRequested + pop 回列表。
  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('删除预算'),
        content: const Text('确定删除此预算？此操作不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('删除')),
        ],
      ),
    ).then((ok) {
      if (ok == true && mounted) {
        context.read<BudgetBloc>().add(DeleteBudgetRequested(widget.id));
        context.pop();
      }
    });
  }
}

// ───────────────────────── 私有 widgets / helpers ─────────────────────────

/// 状态 / Month pill(对齐原型 .status-pill;soft = 浅底深字)。
class _StatusPill extends StatelessWidget {
  const _StatusPill(
      {required this.label,
      required this.icon,
      required this.color,
      this.soft = false});
  final String label;
  final IconData icon;
  final Color color;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: soft ? 0.12 : 1.0),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: soft ? color : Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: soft ? color : Colors.white,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }
}

/// 「key value」一行 meta 文字(vColor 非空时高亮加粗)。
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

/// 千分位 + 两位小数 + 货币符号前缀(复用 currency_convert.dart 的 currencySymbol;
/// 与 budget_list_page._fmtSymbol / holding_detail_page._fmtRaw 同形)。
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
