import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/yucai_menu.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/core/widgets/debt_view_semantics.dart';
import 'package:yucai_client/core/widgets/gold_amount.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';

/// 共享的 debt / receivable **列表页** 组件(结构样式两侧完全一致,差异由
/// [DebtViewSemantics] 注入)。包含:
///  - [DebtListOverviewCard]  总览卡(ov-top + ov-grid 3-col + ov-foot)
///  - [DebtListStatStrip]     L2 4-card 统计条
///  - [DebtListCard]          横向 4-col / narrow / compact 三端卡
///  - [DebtListFilterSegmented] 全部/进行中/逾期/已结清 筛选
///  - [DebtCardFootCallout]   卡底「下次还款/收款 + CTA」callout
///  - 小件:[DebtTypeBadge] / [DebtTypeAvatar] / [DebtCardMetaItem] /
///    [DebtCardMetaKv] / [DebtCardProgressRow] / [DebtCardActionBtn]
///
/// 同一组件实例 + 不同 [DebtViewSemantics] = debt 与 receivable 列表页结构样式
/// 真正一致(镜像),仅文案/路由/颜色不同。
///
/// 辅助:badge 与 avatar 的「类型色推断」因两侧 subtype 集合不同(ReceivableSubtypes
/// / DebtSubtypes),由调用方通过 [BadgeFor] / [AvatarColorFor] 闭包注入。

/// 千分位 + 两位小数 + 货币符号前缀(两侧同语义,集中一处)。
String sharedFmtSymbol(int cents, String currencyCode) {
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

/// 千分位 + 两位小数(无货币符号)。
String sharedFmtAmtNoSymbol(int cents) {
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
  return '$sign$buf.$fen';
}

// ───────────────────────── 类型 badge ─────────────────────────

class DebtBadgeStyle {
  const DebtBadgeStyle({required this.label, required this.fg, required this.bg});
  final String label;
  final Color fg;
  final Color bg;
}

/// badge 推断闭包类型:Debt → [DebtBadgeStyle]。调用方按自身 subtype 集合实现。
typedef BadgeFor = DebtBadgeStyle Function(Debt debt);
/// avatar 类型色推断闭包类型。
typedef AvatarColorFor = Color Function(Debt debt);

class DebtTypeBadge extends StatelessWidget {
  const DebtTypeBadge({super.key, required this.label, required this.fg, required this.bg});
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    // OD `.badge`:11px w600 + `.dotb` 6px 圆点 + pill(radius 20) + padding 2/9。
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── avatar tile ─────────────────────────

class DebtTypeAvatar extends StatelessWidget {
  const DebtTypeAvatar({super.key, required this.initial, required this.color});
  final String initial;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: color,
          fontFamily: AppTypography.displayFamily,
          fontFamilyFallback: AppTypography.displayFallback,
        ),
      ),
    );
  }
}

// ───────────────────────── 卡内小件 ─────────────────────────

class DebtCardMetaItem extends StatelessWidget {
  const DebtCardMetaItem({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: context.yucai.muted),
        const SizedBox(width: 5),
        Text(text,
            style: TextStyle(
                fontSize: 12.5,
                color: context.yucai.muted,
                fontFeatures: AppTypography.tabularFigures)),
      ],
    );
  }
}

/// OD .rcv-meta2:label + value space-between(10.5px,label muted / value fg w600)。
class DebtCardMetaKv extends StatelessWidget {
  const DebtCardMetaKv(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 10.5, color: context.yucai.muted)),
        Text(value,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: context.yucai.fg,
                fontFeatures: AppTypography.tabularFigures)),
      ],
    );
  }
}

class DebtCardProgressRow extends StatelessWidget {
  const DebtCardProgressRow({
    super.key,
    required this.ratio,
    required this.label,
    this.thin = true,
  });
  final double ratio;
  final String label;
  final bool thin;

  @override
  Widget build(BuildContext context) {
    final pct = (ratio * 100).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontSize: 10.5, color: context.yucai.muted)),
            Text('$pct%',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: context.yucai.accentDeep,
                    fontFeatures: AppTypography.tabularFigures)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(9999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: thin ? 8 : 9,
            backgroundColor: context.yucai.surfaceAlt,
            valueColor:
                AlwaysStoppedAnimation<Color>(context.yucai.accent),
          ),
        ),
      ],
    );
  }
}

class DebtCardActionBtn extends StatelessWidget {
  const DebtCardActionBtn({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.expanded = true,
  });
  final IconData icon;
  final String label;
  final ValueChanged<BuildContext>? onTap;

  /// false 时不包 Expanded(MenuAnchor 的 builder 内不允许 ParentData)。

    /// false 时不包 Expanded(MenuAnchor 的 builder 内不允许 ParentData)。
    final bool expanded;

  @override
  Widget build(BuildContext context) {
    final body = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap == null ? null : () => onTap!(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: context.yucai.muted),
                const SizedBox(height: 3),
                Text(label,
                    style: TextStyle(
                        color: context.yucai.muted, fontSize: 11)),
              ],
            ),
          ),
        ),
      );
    return expanded ? Expanded(child: body) : body;
  }
}

// ───────────────────────── 列表筛选 segmented ─────────────────────────

/// 列表筛选:全部 / 进行中 / 已结清 / 逾期(两侧共用,顺序一致 = 镜像)。
enum DebtListFilter { all, active, settled, overdue }

bool debtMatchesListFilter(Debt d, DebtListFilter f) {
  final settled = d.remainingPrincipalCents <= 0;
  switch (f) {
    case DebtListFilter.all:
      return true;
    case DebtListFilter.active:
      return !settled;
    case DebtListFilter.settled:
      return settled;
    case DebtListFilter.overdue:
      return !settled && d.dueDate.isBefore(DateTime.now());
  }
}

/// 列表排序:未结清在前(按到期升序),已结清沉底。
int debtCompareList(Debt a, Debt b) {
  final aSettled = a.remainingPrincipalCents <= 0;
  final bSettled = b.remainingPrincipalCents <= 0;
  if (aSettled != bSettled) return aSettled ? 1 : -1;
  return a.dueDate.compareTo(b.dueDate);
}

/// OD `.seg` 风格列表筛选 segmented(bg #EFEDE6 + border + radius 10 + padding 3)。
/// 4 段 全部/进行中/已结清/逾期,每段 label + count pill(active 用 gold-soft)。
class DebtListFilterSegmented extends StatelessWidget {
  const DebtListFilterSegmented({
    super.key,
    required this.filter,
    required this.activeCount,
    required this.settledCount,
    required this.overdueCount,
    required this.onChanged,
  });
  final DebtListFilter filter;
  final int activeCount;
  final int settledCount;
  final int overdueCount;
  final ValueChanged<DebtListFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const segments = [
      (DebtListFilter.all, '全部'),
      (DebtListFilter.active, '进行中'),
      (DebtListFilter.settled, '已结清'),
      (DebtListFilter.overdue, '逾期'),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.yucai.surfaceAlt,
        border: Border.all(color: context.yucai.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 2,
        runSpacing: 0,
        children: [
          for (final (f, label) in segments) _segment(f, label),
        ],
      ),
    );
  }

  Widget _segment(DebtListFilter f, String label) {
    final active = f == filter;
    final count = switch (f) {
      DebtListFilter.active => activeCount,
      DebtListFilter.settled => settledCount,
      DebtListFilter.overdue => overdueCount,
      DebtListFilter.all => activeCount + settledCount,
    };
    return InkWell(
      key: ValueKey('listFilter-$label'),
      onTap: () => onChanged(f),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? const [
                  BoxShadow(
                      color: Color(0x1A1C1E21),
                      blurRadius: 3,
                      offset: Offset(0, 1))
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? AppColors.fg : AppColors.muted,
                )),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.accentSoft
                    : const Color(0x0F000000),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.accentHover : AppColors.muted,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── L2 stat strip(4-card) ─────────────────────────

class DebtListStatCardData {
  const DebtListStatCardData({
    required this.label,
    required this.value,
    this.color,
    this.sub,
    this.icon,
  });
  final String label;
  final String value;
  final Color? color;
  final String? sub;
  final IconData? icon;
}

/// 4-card stat strip(对齐 OD .stats-row)。4 卡始终并排(Row + Expanded),
/// 等高(IntrinsicHeight + stretch)。调用方传入 4 个 [DebtListStatCardData]。
class DebtListStatStrip extends StatelessWidget {
  const DebtListStatStrip({super.key, required this.cards});
  final List<DebtListStatCardData> cards;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            Expanded(child: _StatCard(data: cards[i])),
            if (i < cards.length - 1) const SizedBox(width: 14),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatefulWidget {
  const _StatCard({required this.data});
  final DebtListStatCardData data;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: context.yucai.surface,
          border: Border.all(color: context.yucai.border),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: const Color(0x0A1C1E21),
              blurRadius: _hover ? 28 : 2,
              offset: _hover ? const Offset(0, 10) : const Offset(0, 1),
            ),
            if (_hover)
              BoxShadow(
                color: const Color(0x0D1C1E21),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (d.icon != null) ...[
                  Icon(d.icon, size: 14, color: context.yucai.muted),
                  const SizedBox(width: 7),
                ],
                Flexible(
                  child: Text(d.label,
                      style: TextStyle(
                          fontSize: 12,
                          color: context.yucai.muted,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              d.value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: d.color ?? context.yucai.fg,
                letterSpacing: -0.1,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
            if (d.sub != null) ...[
              const SizedBox(height: 3),
              Text(d.sub!,
                  style: TextStyle(
                      fontSize: 11.5, color: context.yucai.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── 总览卡 OverviewCard ─────────────────────────

/// 精确「下次收款/还款」数据(ov-foot)。null 字段由调用方决定是否渲染。
class OvNextPayment {
  const OvNextPayment({
    required this.date,
    required this.counterparty,
    required this.periodNo,
    required this.amountCents,
  });
  final DateTime date;
  final String counterparty;
  final int periodNo;
  final int amountCents;
}

/// 总览卡(对齐 OD .ov):ov-top + ov-grid 3-col + ov-foot。
/// desktop(≥600)三栏;mobile(<600)单列堆叠。两侧共用,文案由 [sem] 注入。
class DebtListOverviewCard extends StatelessWidget {
  const DebtListOverviewCard({
    super.key,
    required this.sem,
    required this.preferred,
    required this.totalPrincipal,
    required this.totalRemaining,
    required this.totalCollected,
    required this.count,
    required this.overallRatio,
    this.nextCollectDate,
    this.trendCents,
    this.newCountThisMonth = 0,
    this.pendingInterestCents,
    this.nextPayment,
    this.firstId,
  });

  final DebtViewSemantics sem;
  final String preferred;
  final int totalPrincipal;
  final int totalRemaining;
  final int totalCollected;
  final int count;
  final double overallRatio;
  // fallback 下次日期(min dueDate);无精确 nextPayment 时用。
  final DateTime? nextCollectDate;
  // 可选 trend(较上月增减)。null/0 → 不显 trend line。
  final int? trendCents;
  final int newCountThisMonth;
  // 可选 breakdown 待收/待还利息。null/≤0 → 不显 breakdown。
  final int? pendingInterestCents;
  // 精确下次收款/还款(来自 summary)。null → fallback foot。
  final OvNextPayment? nextPayment;
  // CTA「查看收款/还款计划」跳转目标 id。
  final String? firstId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) =>
          c.maxWidth < 600 ? _mobile(context) : _desktop(context),
    );
  }

  Widget _desktop(BuildContext context) {
    final pct = (overallRatio * 100).toStringAsFixed(1);
    final now = DateTime.now();
    return Container(
      decoration: BoxDecoration(
        color: context.yucai.surface,
        border: Border.all(color: context.yucai.border),
        borderRadius: AppRadius.lgBorder,
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A1C1E21), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ov-top
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(sem.overviewIcon, size: 16, color: context.yucai.accent),
                const SizedBox(width: 8),
                Text(sem.overviewTitle,
                    style: TextStyle(
                        fontSize: 16,
                        fontFamily: AppTypography.displayFamily,
                        fontFamilyFallback: AppTypography.displayFallback)),
                const Spacer(),
                Icon(LucideIcons.calendarDays, size: 13, color: context.yucai.muted),
                const SizedBox(width: 5),
                Text(
                  '截至 ${sharedFmtDate(now)} · $count 笔${sem.overviewHeading}',
                  style: TextStyle(
                      fontSize: 12, color: context.yucai.muted),
                ),
              ],
            ),
          ),
          // ov-grid 3-col
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sem.principalLabel,
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.7,
                              color: context.yucai.muted)),
                      const SizedBox(height: 4),
                      _bigAmt(totalPrincipal),
                      if (trendCents != null && trendCents != 0) ...[
                        const SizedBox(height: 6),
                        _trendLine(trendCents!, newCountThisMonth),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 28),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sem.remainingLabel,
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.7,
                              color: context.yucai.muted)),
                      const SizedBox(height: 4),
                      _bigAmt(totalRemaining),
                      if (pendingInterestCents != null &&
                          pendingInterestCents! > 0) ...[
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            style: TextStyle(
                                fontSize: 12, color: context.yucai.muted),
                            children: [
                              TextSpan(text: '${sem.breakdownInterestLabel} '),
                              TextSpan(
                                  text: sharedFmtSymbol(
                                      pendingInterestCents!, preferred),
                                  style: TextStyle(
                                      color: context.yucai.fg,
                                      fontWeight: FontWeight.w600,
                                      fontFeatures:
                                          AppTypography.tabularFigures)),
                              const TextSpan(text: ' · 合计 '),
                              TextSpan(
                                  text: sharedFmtSymbol(
                                      totalRemaining +
                                          pendingInterestCents!,
                                      preferred),
                                  style: TextStyle(
                                      color: context.yucai.fg,
                                      fontWeight: FontWeight.w600,
                                      fontFeatures:
                                          AppTypography.tabularFigures)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 28),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(sem.progressLabel,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12.5, color: context.yucai.muted)),
                          ),
                          Text('$pct%',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: context.yucai.accentDeep,
                                  fontFeatures: AppTypography.tabularFigures)),
                        ],
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9999),
                        child: LinearProgressIndicator(
                          value: overallRatio,
                          minHeight: 12,
                          backgroundColor: context.yucai.surfaceAlt,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              context.yucai.accent),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: _metaPair(sem.collectedMetaLabel,
                                sharedFmtSymbol(totalCollected, preferred)),
                          ),
                          Flexible(
                            child: _metaPair(sem.pendingMetaLabel,
                                sharedFmtSymbol(totalRemaining, preferred)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (nextPayment != null)
            _OvFoot(
              sem: sem,
              preferred: preferred,
              date: nextPayment!.date,
              counterparty: nextPayment!.counterparty,
              periodNo: nextPayment!.periodNo,
              amountCents: nextPayment!.amountCents,
              firstId: firstId,
            )
          else if (nextCollectDate != null)
            _OvFootFallback(
              sem: sem,
              date: nextCollectDate!,
              firstId: firstId,
            ),
        ],
      ),
    );
  }

  Widget _mobile(BuildContext context) {
    final pct = (overallRatio * 100).toStringAsFixed(1);
    final now = DateTime.now();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.yucai.surface,
        border: Border.all(color: context.yucai.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 7,
              runSpacing: 4,
              children: [
                Icon(sem.overviewIcon, size: 14, color: context.yucai.accent),
                Text(sem.overviewTitle,
                    style: TextStyle(
                        fontSize: 14,
                        fontFamily: AppTypography.displayFamily,
                        fontFamilyFallback: AppTypography.displayFallback)),
                const SizedBox(width: 8),
                Icon(LucideIcons.calendarDays, size: 12, color: context.yucai.muted),
                Text('截至 ${sharedFmtDate(now)} · $count 笔',
                    style: TextStyle(fontSize: 11, color: context.yucai.muted)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sem.principalLabel,
                    style: TextStyle(
                        fontSize: 10.5, color: context.yucai.muted)),
                const SizedBox(height: 3),
                _bigAmt(totalPrincipal),
                if (trendCents != null && trendCents != 0) ...[
                  const SizedBox(height: 5),
                  _trendLine(trendCents!, newCountThisMonth),
                ],
                const SizedBox(height: 14),
                Text(sem.remainingLabel,
                    style: TextStyle(fontSize: 10.5, color: context.yucai.muted)),
                const SizedBox(height: 3),
                _bigAmt(totalRemaining),
                if (pendingInterestCents != null &&
                    pendingInterestCents! > 0) ...[
                  const SizedBox(height: 5),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                          fontSize: 11.5, color: context.yucai.muted),
                      children: [
                        TextSpan(text: '${sem.breakdownInterestLabel} '),
                        TextSpan(
                            text: sharedFmtSymbol(
                                pendingInterestCents!, preferred),
                            style: TextStyle(
                                color: context.yucai.fg,
                                fontWeight: FontWeight.w600,
                                fontFeatures: AppTypography.tabularFigures)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(sem.progressLabel,
                        style: TextStyle(
                            fontSize: 12, color: context.yucai.muted)),
                    Text('$pct%',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.yucai.accentDeep,
                            fontFeatures: AppTypography.tabularFigures)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(9999),
                  child: LinearProgressIndicator(
                    value: overallRatio,
                    minHeight: 10,
                    backgroundColor: context.yucai.surfaceAlt,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(context.yucai.accent),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: _metaPair(sem.collectedMetaLabel,
                          sharedFmtSymbol(totalCollected, preferred)),
                    ),
                    Flexible(
                      child: _metaPair(sem.pendingMetaLabel,
                          sharedFmtSymbol(totalRemaining, preferred)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (nextPayment != null)
            _OvFoot(
              sem: sem,
              preferred: preferred,
              date: nextPayment!.date,
              counterparty: nextPayment!.counterparty,
              periodNo: nextPayment!.periodNo,
              amountCents: nextPayment!.amountCents,
              firstId: firstId,
              compact: true,
            )
          else if (nextCollectDate != null)
            _OvFootFallback(
              sem: sem,
              date: nextCollectDate!,
              firstId: firstId,
              compact: true,
            ),
        ],
      ),
    );
  }

  Widget _bigAmt(int cents) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(currencySymbol(preferred),
            style: TextStyle(
                fontSize: 20,
                color: AppColors.accent,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 2),
        Flexible(
          fit: FlexFit.loose,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              sharedFmtAmtNoSymbol(cents),
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: AppColors.fg,
                letterSpacing: -0.2,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// trend line:正绿「+¥X」/ 负红「-¥X」(对齐 OD)。两侧「剩余/本金增加 = 红」,
  /// 「减少 = 绿」语义不同,但 trendCents 这里是「本金较上月变化」:receivable
  /// 增加=借出变多=中性偏红;debt 增加=负债变多=红。统一:正=红、负=绿(欠/应
  /// 收减少是好事)。与 detail hero delta 同向(减少=绿)。
  Widget _trendLine(int cents, int newCount) {
    final isDown = cents < 0; // 减少 = 绿
    final color = isDown ? AppColors.positive : AppColors.negative;
    final sign = isDown ? '-' : '+';
    final abs = cents.abs();
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 12, color: AppColors.muted),
        children: [
          const TextSpan(text: '较上月 '),
          TextSpan(
              text: '$sign${sharedFmtSymbol(abs, preferred)}',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTypography.tabularFigures)),
          if (newCount > 0) TextSpan(text: ' · 新增 $newCount 笔'),
        ],
      ),
    );
  }

  Widget _metaPair(String lbl, String amt) {
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 11.5, color: AppColors.muted),
        children: [
          TextSpan(text: '$lbl '),
          TextSpan(
              text: amt,
              style: TextStyle(
                  color: AppColors.fg,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }
}

/// ov-foot(对齐 OD .ov-foot):flex-wrap row。左:📅 + 下次收款/还款 + 对方第N期
/// + ¥X + 待收/待还 pill;右:gold-soft CTA「查看收款/还款计划 →」。
class _OvFoot extends StatelessWidget {
  const _OvFoot({
    required this.sem,
    required this.preferred,
    required this.date,
    required this.counterparty,
    required this.periodNo,
    required this.amountCents,
    this.compact = false,
    this.firstId,
  });
  final DebtViewSemantics sem;
  final String preferred;
  final DateTime date;
  final String counterparty;
  final int periodNo;
  final int amountCents;
  final bool compact;
  final String? firstId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 18 : 24, vertical: compact ? 10 : 13),
      decoration: BoxDecoration(
        color: context.yucai.surfaceAlt,
        border: Border(top: BorderSide(color: context.yucai.border, width: 1)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(LucideIcons.calendarClock,
                  size: compact ? 14 : 15, color: context.yucai.accent),
              SizedBox(width: compact ? 7 : 9),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                      fontSize: compact ? 12 : 13, color: context.yucai.muted),
                  children: [
                    TextSpan(text: '${sem.nextPaymentWord} '),
                    TextSpan(
                        text: sharedFmtDate(date),
                        style: TextStyle(
                            color: context.yucai.fg,
                            fontWeight: FontWeight.w600,
                            fontFeatures: AppTypography.tabularFigures)),
                    TextSpan(
                        text:
                            ' · $counterparty 第$periodNo期 · '),
                    TextSpan(
                        text: sharedFmtSymbol(amountCents, preferred),
                        style: TextStyle(
                            color: context.yucai.fg,
                            fontWeight: FontWeight.w600,
                            fontFeatures: AppTypography.tabularFigures)),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.yucai.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(sem.pendingPillLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.yucai.muted)),
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              if (firstId != null) {
                context.push('${sem.listRoutePrefix}/$firstId');
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: context.yucai.accentDeep,
              backgroundColor: context.yucai.accentSoft,
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12, vertical: 6),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(sem.viewPlanLabel,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(LucideIcons.chevronRight, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ov-foot fallback:无精确 nextPayment,只显下次日期 + CTA。
class _OvFootFallback extends StatelessWidget {
  const _OvFootFallback({
    required this.sem,
    required this.date,
    this.compact = false,
    this.firstId,
  });
  final DebtViewSemantics sem;
  final DateTime date;
  final bool compact;
  final String? firstId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 18 : 24, vertical: compact ? 10 : 13),
      decoration: BoxDecoration(
        color: context.yucai.surfaceAlt,
        border: Border(top: BorderSide(color: context.yucai.border, width: 1)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.calendarClock,
                  size: compact ? 14 : 15, color: context.yucai.accent),
              SizedBox(width: compact ? 7 : 9),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                      fontSize: compact ? 12 : 13, color: context.yucai.muted),
                  children: [
                    TextSpan(text: '${sem.nextPaymentWord} '),
                    TextSpan(
                        text: sharedFmtDate(date),
                        style: TextStyle(
                            color: context.yucai.fg,
                            fontWeight: FontWeight.w600,
                            fontFeatures: AppTypography.tabularFigures)),
                  ],
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              if (firstId != null) {
                context.push('${sem.listRoutePrefix}/$firstId');
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: context.yucai.accentDeep,
              backgroundColor: context.yucai.accentSoft,
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12, vertical: 6),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(sem.viewPlanLabel,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(LucideIcons.chevronRight, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 卡底 foot callout ─────────────────────────

/// L3 foot callout(单卡):下次收款/还款 + 逾期天数 + 详情 + CTA(收款/立即记账)。
/// 两侧共用,文案/CTA 由 [sem] 注入。CTA 与「详情」均跳详情页(同 receivable 落点)。
class DebtCardFootCallout extends StatelessWidget {
  const DebtCardFootCallout({
    super.key,
    required this.sem,
    required this.preferred,
    required this.debt,
    required this.hasNext,
    required this.isOverdue,
  });
  final DebtViewSemantics sem;
  final String preferred;
  final Debt debt;
  final bool hasNext;
  final bool isOverdue;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final overdueDays = isOverdue ? now.difference(debt.dueDate).inDays : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: context.yucai.surfaceAlt,
        border: Border(
          top: BorderSide(color: context.yucai.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasNext
                ? LucideIcons.calendarClock
                : (isOverdue ? LucideIcons.alertTriangle : LucideIcons.clock),
            size: 15,
            color: isOverdue && !hasNext ? context.yucai.negative : context.yucai.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                    fontSize: 12.5,
                    color: context.yucai.fg,
                    fontFeatures: AppTypography.tabularFigures),
                children: [
                  if (hasNext) ...[
                    TextSpan(
                        text: '${sem.footNextWord} · ',
                        style: TextStyle(
                            color: context.yucai.muted,
                            fontWeight: FontWeight.w500)),
                    TextSpan(
                        text:
                            '第 ${debt.nextPaymentPeriodNo} 期 · ${sharedFmtDate(debt.nextPaymentDate!)}'),
                    TextSpan(
                        text:
                            ' · ${sharedFmtSymbol(debt.nextPaymentAmountCents, preferred)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: context.yucai.accentDeep)),
                    if (isOverdue)
                      TextSpan(
                          text: ' · 含逾期 $overdueDays 天',
                          style: TextStyle(
                              fontSize: 11, color: context.yucai.negative)),
                  ] else if (isOverdue)
                    TextSpan(
                        text: '逾期 $overdueDays 天',
                        style: TextStyle(
                            color: context.yucai.negative,
                            fontWeight: FontWeight.w600))
                  else ...[
                    TextSpan(
                        text: '状态 ', style: TextStyle(color: context.yucai.muted)),
                    TextSpan(
                        text: sem.footPendingStateLabel,
                        style: TextStyle(
                            color: context.yucai.fg, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () =>
                context.push('${sem.listRoutePrefix}/${debt.id}'),
            icon: const Icon(LucideIcons.info, size: 14),
            label: const Text('详情',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              foregroundColor: context.yucai.muted,
              backgroundColor: context.yucai.surface,
              side: BorderSide(color: context.yucai.border),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: () =>
                context.push('${sem.listRoutePrefix}/${debt.id}'),
            icon: Icon(sem.footCtaIcon, size: 14),
            label: Text(sem.footCtaLabel,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              foregroundColor: context.yucai.accentDeep,
              backgroundColor: context.yucai.accentSoft,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 列表卡 ListCard ─────────────────────────

/// 单张列表卡。三端布局:
///  - mobile(≤mobileUpper):compact 紧凑
///  - 宽卡(≥560):fullCard 横向 4-col row(avatar+name | 剩余 | 进度+已收 | meta2)
///  - 窄卡(<560):narrowFullCard 竖向
/// 已结清整卡 Opacity 0.6。两侧共用,badge/avatar 类型色由调用方闭包注入。
class DebtListCard extends StatelessWidget {
  const DebtListCard({
    super.key,
    required this.sem,
    required this.debt,
    required this.preferred,
    required this.badgeFor,
    required this.avatarColorFor,
  });
  final DebtViewSemantics sem;
  final Debt debt;
  final String preferred;
  final BadgeFor badgeFor;
  final AvatarColorFor avatarColorFor;

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.of(context).size.width <= Breakpoints.mobileUpper;
    final isSettled = debt.remainingPrincipalCents <= 0;
    final moreMenu = MenuController();
    final Widget card;
    if (isMobile) {
      card = _compactCard(context, moreMenu);
    } else {
      card = LayoutBuilder(
        builder: (ctx, c) =>
            c.maxWidth >= 560
                ? _fullCard(context, moreMenu)
                : _narrowFullCard(context, moreMenu),
      );
    }
    return isSettled ? Opacity(opacity: 0.6, child: card) : card;
  }

  bool get _hasNext =>
      debt.nextPaymentDate != null &&
      debt.remainingPrincipalCents > 0 &&
      debt.nextPaymentAmountCents > 0;

  Widget _fullCard(BuildContext context, MenuController moreMenu) {
    final badge = badgeFor(debt);
    final isOverdue = debt.dueDate.isBefore(DateTime.now());
    final isSettled = debt.remainingPrincipalCents <= 0;
    final hasNext = _hasNext;
    return DataCard(
      onTap: () => context.push('${sem.listRoutePrefix}/${debt.id}'),
      onLongPress: () => moreMenu.open(),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      DebtTypeAvatar(
                        initial: debt.counterparty.characters.isEmpty
                            ? '?'
                            : debt.counterparty.characters.first,
                        color: avatarColorFor(debt),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 7,
                              runSpacing: 4,
                              children: [
                                Text(debt.counterparty,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                DebtTypeBadge(
                                    label: badge.label,
                                    fg: badge.fg,
                                    bg: badge.bg),
                                if (isSettled)
                                  DebtTypeBadge(
                                      label: '已结清 ✓',
                                      fg: context.yucai.positive,
                                      bg: Color(0x1A2D8A6E))
                                else if (isOverdue)
                                  DebtTypeBadge(
                                      label: '逾期',
                                      fg: context.yucai.negative,
                                      bg: Color(0x1AC4544D)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${sem.cardMetaLentLabel} ${sharedFmtSymbol(debt.totalPrincipalCents, preferred)} · ${sharedFmtDate(debt.startDate)} · ${sharedAmortLabel(debt.amortization)}',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: context.yucai.muted,
                                  fontFeatures: AppTypography.tabularFigures),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 9,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sem.cardRemainingLabel,
                          style: TextStyle(
                              fontSize: 9.5,
                              letterSpacing: 0.5,
                              color: context.yucai.muted)),
                      const SizedBox(height: 4),
                      GoldAmount(
                        cents: debt.remainingPrincipalCents,
                        preferred: preferred,
                        curSize: 13,
                        numSize: 19,
                        numLetterSpacing: -0.1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 11,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DebtCardProgressRow(
                          ratio: debt.progressRatio,
                          label: sem.cardProgressLabel,
                          thin: true),
                      const SizedBox(height: 6),
                      DebtCardMetaKv(
                        sem.cardCollectedMetaLabel,
                        sharedFmtSymbol(
                            debt.totalPrincipalCents -
                                debt.remainingPrincipalCents,
                            preferred),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 9,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DebtCardMetaKv(
                          '年利率', '${debt.interestRate.toStringAsFixed(2)}%'),
                      const SizedBox(height: 5),
                      DebtCardMetaKv('到期日', sharedFmtDate(debt.dueDate)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          DebtCardFootCallout(
            sem: sem,
            preferred: preferred,
            debt: debt,
            hasNext: hasNext,
            isOverdue: isOverdue,
          ),
        ],
      ),
    );
  }

  Widget _narrowFullCard(BuildContext context, MenuController moreMenu) {
    final badge = badgeFor(debt);
    final isOverdue = debt.dueDate.isBefore(DateTime.now());
    final isSettled = debt.remainingPrincipalCents <= 0;
    final hasNext = _hasNext;
    return DataCard(
      onTap: () => context.push('${sem.listRoutePrefix}/${debt.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DebtTypeAvatar(
                initial: debt.counterparty.characters.isEmpty
                    ? '?'
                    : debt.counterparty.characters.first,
                color: avatarColorFor(debt),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(debt.counterparty,
                        style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            fontFamily: AppTypography.displayFamily,
                            fontFamilyFallback:
                                AppTypography.displayFallback)),
                    const SizedBox(height: 5),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        DebtTypeBadge(
                            label: badge.label, fg: badge.fg, bg: badge.bg),
                        if (isSettled)
                          DebtTypeBadge(
                              label: '已结清 ✓',
                              fg: context.yucai.positive,
                              bg: Color(0x1A2D8A6E))
                        else if (isOverdue)
                          DebtTypeBadge(
                              label: '逾期',
                              fg: context.yucai.negative,
                              bg: Color(0x1AC4544D)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(sem.cardRemainingLabel,
              style: TextStyle(
                  fontSize: 10.5, letterSpacing: 0.5, color: context.yucai.muted)),
          const SizedBox(height: 4),
          Text(
            sharedFmtSymbol(debt.remainingPrincipalCents, preferred),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.15,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
          const SizedBox(height: 9),
          DebtCardProgressRow(
              ratio: debt.progressRatio, label: sem.cardProgressLabel),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 5,
            children: [
              DebtCardMetaItem(
                  icon: LucideIcons.percent,
                  text: '${debt.interestRate.toStringAsFixed(2)}%'),
              DebtCardMetaItem(
                  icon: LucideIcons.calendar,
                  text: '到期 ${sharedFmtDate(debt.dueDate)}'),
              DebtCardMetaItem(
                  icon: LucideIcons.lineChart,
                  text: sharedAmortLabel(debt.amortization)),
            ],
          ),
          if (hasNext || isOverdue && !isSettled) ...[
            const SizedBox(height: 10),
            DebtCardFootCallout(
              sem: sem,
              preferred: preferred,
              debt: debt,
              hasNext: hasNext,
              isOverdue: isOverdue,
            ),
          ],
          const Spacer(),
          _actionBar(context, moreMenu),
        ],
      ),
    );
  }

  Widget _compactCard(BuildContext context, MenuController moreMenu) {
    final badge = badgeFor(debt);
    final isOverdue = debt.dueDate.isBefore(DateTime.now());
    final isSettled = debt.remainingPrincipalCents <= 0;
    final hasNext = _hasNext;
    return DataCard(
      onTap: () => context.push('${sem.listRoutePrefix}/${debt.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DebtTypeAvatar(
                initial: debt.counterparty.characters.isEmpty
                    ? '?'
                    : debt.counterparty.characters.first,
                color: avatarColorFor(debt),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(debt.counterparty,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                fontFamily: AppTypography.displayFamily,
                                fontFamilyFallback:
                                    AppTypography.displayFallback)),
                        DebtTypeBadge(
                            label: badge.label, fg: badge.fg, bg: badge.bg),
                        if (isSettled)
                          DebtTypeBadge(
                              label: '已结清 ✓',
                              fg: context.yucai.positive,
                              bg: Color(0x1A2D8A6E))
                        else if (isOverdue)
                          DebtTypeBadge(
                              label: '逾期',
                              fg: context.yucai.negative,
                              bg: Color(0x1AC4544D)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${sharedAmortLabel(debt.amortization)} · ${debt.interestRate.toStringAsFixed(2)}%',
                      style: TextStyle(
                          fontSize: 11.5, color: context.yucai.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(sem.cardRemainingLabel,
                      style:
                          TextStyle(fontSize: 10, color: context.yucai.muted)),
                  const SizedBox(height: 2),
                  Text(
                    sharedFmtSymbol(debt.remainingPrincipalCents, preferred),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          DebtCardProgressRow(
              ratio: debt.progressRatio, label: sem.cardProgressLabel, thin: false),
          const SizedBox(height: 8),
          Row(
            children: [
              DebtCardMetaItem(
                  icon: LucideIcons.calendar,
                  text: '到期 ${sharedFmtDate(debt.dueDate)}'),
            ],
          ),
          if (hasNext || isOverdue && !isSettled) ...[
            const SizedBox(height: 10),
            DebtCardFootCallout(
              sem: sem,
              preferred: preferred,
              debt: debt,
              hasNext: hasNext,
              isOverdue: isOverdue,
            ),
          ],
          const SizedBox(height: 10),
          _actionBar(context, moreMenu),
        ],
      ),
    );
  }

  /// 「更多」锚定菜单：MenuAnchor 锚定按钮本体,controller 由 build 创建,
  /// 卡片长按与按钮点击共用。
  Widget moreMenuAnchor(BuildContext context, MenuController controller) {
    return MenuAnchor(
      style: yucaiMenuStyle(context),
      // 根 Overlay:分支 Overlay 原点含侧栏/顶栏偏移,会让菜单飞位。
      useRootOverlay: true,
      menuChildren: [
        MenuItemButton(
          leadingIcon: Icon(LucideIcons.pencil,
              size: 16, color: context.yucai.muted),
          child: Text(sem.editMenuItem),
          onPressed: () => context.push('${sem.listRoutePrefix}/${debt.id}'),
        ),
        MenuItemButton(
          leadingIcon:
              Icon(LucideIcons.trash2, size: 16, color: context.yucai.negative),
          child: Text(sem.deleteMenuItem,
              style: TextStyle(color: context.yucai.negative)),
          onPressed: () =>
              context.read<DebtBloc>().add(DeleteDebtRequested(debt.id)),
        ),
      ],
      builder: (menuContext, ctrl, child) => DebtCardActionBtn(
        expanded: false,
        icon: LucideIcons.moreHorizontal,
        label: '更多',
        onTap: (_) => ctrl.isOpen ? ctrl.close() : ctrl.open(),
      ),
    );
  }

  Widget _actionBar(BuildContext context, MenuController moreMenu) {
    return Container(
      margin: const EdgeInsets.only(top: 11),
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.yucai.border, width: 1.0)),
      ),
      child: Row(
        children: [
          DebtCardActionBtn(
            icon: LucideIcons.info,
            label: '详情',
            onTap: (_) =>
                context.push('${sem.listRoutePrefix}/${debt.id}'),
          ),
          // 更多：MenuAnchor 锚定按钮本体（桌面端以锚定菜单取代底部抽屉 ——
          // 抽屉固定窗口底部,与触发按钮脱节,被感知为“菜单坐标不对”）。
          moreMenuAnchor(context, moreMenu),
        ],
      ),
    );
  }

  // （F5）原 showModalBottomSheet 底部抽屉已由 _actionBar 中的 MenuAnchor
  // 锚定菜单取代：桌面端菜单就近弹出,坐标与触发按钮一致。
}

