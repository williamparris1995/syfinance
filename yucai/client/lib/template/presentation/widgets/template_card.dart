import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/core/recurrence/recurrence_rule_text.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';

/// 单条周期模板 card:名称 + 金额 + 周期 + 下次日期 + 自动/暂停 chip +
/// trailing(record / pause-resume / edit / delete)。复用 DataCard。
///
/// 对齐 tag TagCard 结构(DataCard + Row 内容 + trailing IconButtons)。
class TemplateCard extends StatelessWidget {
  const TemplateCard({
    super.key,
    required this.template,
    required this.onRecord,
    required this.onTogglePause,
    required this.onEdit,
    required this.onDelete,
  });

  final Template template;
  final VoidCallback onRecord;
  final VoidCallback onTogglePause;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = template;
    final (dirLabel, dirColor) = _directionStyle(context, t.direction);
    return DataCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 名称行 + 方向 tag
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        t.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.yucai.fg,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (dirLabel.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.xs),
                      _TagPill(label: dirLabel, color: dirColor),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // 金额 + 周期
                Row(
                  children: [
                    Text(
                      templateAmountDisplay(t.amountCents),
                      style: TextStyle(
                        color: dirColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFeatures: AppTypography.tabularFigures,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        templateCycleDisplay(t),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.yucai.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
                // 下次日期
                if ((t.nextDate ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(LucideIcons.calendarClock,
                          size: 12, color: context.yucai.muted),
                      const SizedBox(width: 4),
                      Text(
                        '下次 ${t.nextDate}',
                        style: TextStyle(
                          color: context.yucai.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                // 状态 chips
                if (t.autoRecord || t.paused) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (t.autoRecord)
                        _StatusChip(
                          icon: LucideIcons.zap,
                          label: '自动',
                          color: context.yucai.accent,
                        ),
                      if (t.paused)
                        _StatusChip(
                          icon: LucideIcons.pause,
                          label: '已暂停',
                          color: context.yucai.muted,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // trailing actions
          _IconAction(
            tooltip: '立即记账',
            icon: LucideIcons.circlePlay,
            color: context.yucai.positive,
            onTap: t.paused ? null : onRecord,
          ),
          _IconAction(
            tooltip: t.paused ? '恢复' : '暂停',
            icon: t.paused ? LucideIcons.play : LucideIcons.pause,
            color: context.yucai.muted,
            onTap: onTogglePause,
          ),
          _IconAction(
            tooltip: '编辑',
            icon: LucideIcons.pencil,
            color: context.yucai.muted,
            onTap: onEdit,
          ),
          _IconAction(
            tooltip: '删除',
            icon: LucideIcons.trash2,
            color: context.yucai.negative,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }

  /// 方向语义色(F4-P2:context 化,暗色跟随主题)。
  (String, Color) _directionStyle(
      BuildContext context, TemplateDirection d) {
    switch (d) {
      case TemplateDirection.expense:
        return ('支出', context.yucai.negative);
      case TemplateDirection.income:
        return ('收入', context.yucai.positive);
      case TemplateDirection.transfer:
        return ('转账', context.yucai.accent);
      case TemplateDirection.unspecified:
        return ('', context.yucai.muted);
    }
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18, color: color),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// 分(cents)→「¥1,234.56」(千分位 + 两位小数)。对齐 transaction _fmtCents 风格。
String templateAmountDisplay(int cents) {
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final frac = (abs % 100).toString().padLeft(2, '0');
  final grouped = yuan.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return '¥$grouped.$frac';
}

/// 周期展示文案(规则感知,共享文案函数;未设置周期兜底)。
String templateCycleDisplay(Template t) {
  if (t.cycle == TemplateCycle.unspecified) return '未设置周期';
  return recurrenceRuleText(t.rule);
}
