import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/core/widgets/debt_list_widgets.dart';
import 'package:yucai_client/core/widgets/debt_view_semantics.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

/// F35 —— 贷款账户详情「还款计划」**只读**面板（照 debt_detail_widgets 惯例，
/// 落 core/widgets 共享位）。
///
/// 入参 [plans]：每笔借入债务一节——counterparty + 剩余本金 badge（可选
/// `DebtSubtypes.labels[subtype]` 徽标）+ 未来未还期次前 3 条（日期
/// yyyy-MM-dd / 本期合计 totalCents 千分位）+ 尾部「查看完整还款计划 →」。
///
/// 单一事实源约束：记账/改日/标记已还等交互归债务详情页（`/debts/{id}`），
/// 本面板只读，唯一出口是 [onOpenDebt] 跳转回调（由调用方接 go_router）。
/// 色值全部经 `context.yucai` 语义令牌，零裸 hex（F4-P2 口径）。
class AccountRepaymentPlanPanel extends StatelessWidget {
  const AccountRepaymentPlanPanel({
    super.key,
    required this.plans,
    required this.onOpenDebt,
    this.preferred = 'CNY',
  });

  /// 每笔债的只读预览数据：债务实体 + 未来未还期次（调用方已按
  /// paymentDate 升序切片；面板内再防御性取前 3 条）。
  final List<({Debt debt, List<PaymentEntry> upcoming})> plans;

  /// 「查看完整还款计划 →」回调（面板不感知路由）。
  final void Function(String debtId) onOpenDebt;

  /// 金额展示币种（对齐 debt 系组件的 preferred 口径）。
  final String preferred;

  @override
  Widget build(BuildContext context) {
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('还款计划', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < plans.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            _DebtPlanSection(
              plan: plans[i],
              preferred: preferred,
              onOpenDebt: onOpenDebt,
            ),
          ],
        ],
      ),
    );
  }
}

class _DebtPlanSection extends StatelessWidget {
  const _DebtPlanSection({
    required this.plan,
    required this.preferred,
    required this.onOpenDebt,
  });

  final ({Debt debt, List<PaymentEntry> upcoming}) plan;
  final String preferred;
  final void Function(String debtId) onOpenDebt;

  @override
  Widget build(BuildContext context) {
    final debt = plan.debt;
    final subtypeLabel = DebtSubtypes.labels[debt.subtype];
    final upcoming = plan.upcoming.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 债名行：counterparty + 子类型徽标（可选）+ 剩余本金 badge。
        Row(
          children: [
            Expanded(
              child: Text(
                debt.counterparty,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.yucai.fg,
                ),
              ),
            ),
            if (subtypeLabel != null) ...[
              const SizedBox(width: 6),
              _ghostBadge(context, subtypeLabel),
            ],
            const SizedBox(width: 6),
            _remainingBadge(context),
          ],
        ),
        const SizedBox(height: 6),
        // 未来未还期次（前 3 条）：日期 yyyy-MM-dd ｜ 本期合计 千分位。
        for (final e in upcoming)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Text(
                  sharedFmtDate(e.paymentDate),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.yucai.muted,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
                const Spacer(),
                Text(
                  '本期合计',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.yucai.muted,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  sharedFmtSymbol(e.totalCents, preferred),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.yucai.fg,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        // 尾部跳转入口（面板唯一交互：交由调用方路由到 /debts/{id}）。
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            key: ValueKey('openDebt-${debt.id}'),
            onTap: () => onOpenDebt(debt.id),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                '查看完整还款计划 →',
                style: TextStyle(
                  fontSize: 12,
                  color: context.yucai.accent,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 剩余本金 badge（accentSoft 底 + accent 字，对齐本页 hero-badge 配色语义）。
  Widget _remainingBadge(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: context.yucai.accentSoft,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          '剩余本金 ${sharedFmtSymbol(plan.debt.remainingPrincipalCents, preferred)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.yucai.accent,
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
      );

  /// 子类型徽标（ghost 形态：fg 7% 底 + border 描边 + muted 字，
  /// 与 account_detail_page._heroBadge ghost 档同语义）。
  Widget _ghostBadge(BuildContext context, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.yucai.border),
          color: context.yucai.fg.withValues(alpha: 0.07),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.yucai.muted,
          ),
        ),
      );
}
