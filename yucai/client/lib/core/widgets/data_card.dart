import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 通用数据卡片（列表页卡片网格的每个单元）。
///
/// 白底、14px 圆角、极淡阴影、统一内边距。内容完全由 [child] 决定 ——
/// 卡片本身不含任何业务逻辑。对应设计规范 §4.2 `DataCard`。
class DataCard extends StatefulWidget {
  const DataCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;

  @override
  State<DataCard> createState() => _DataCardState();
}

class _DataCardState extends State<DataCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          transform: _hover
              ? Matrix4.translationValues(0.0, -1.0, 0.0)
              : Matrix4.identity(),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgBorder,
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: _hover
                    ? const Color(0x14000000)
                    : const Color(0x08000000),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 分组区头：左侧标题（serif）+ 右侧合计文案。
/// 对应原型账户页各分组「银行储蓄 ··· 合计 ¥ x」。
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(
          child: Divider(height: 1, color: AppColors.border),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          DefaultTextStyle(
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
            child: trailing!,
          ),
        ],
      ],
    );
  }
}
