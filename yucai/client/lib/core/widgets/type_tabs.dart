import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 类型选择标签项（值 + 展示文案 + 可选图标）。
class TypeOption<T> {
  const TypeOption(this.value, this.label, [this.icon]);
  final T value;
  final String label;
  final IconData? icon;
}

/// 类型选择分段标签（表单顶部「账户类型」选择）。
/// 选中项：御财金浅底 + 深色文字 + 金色边框；未选中：白底 + 灰字。
/// 对应设计规范 §3.3「TypeTabs」。
class TypeTabs<T> extends StatelessWidget {
  const TypeTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<TypeOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            _TypeChip(
              option: options[i],
              selected: options[i].value == selected,
              onTap: () => onChanged(options[i].value),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeChip<T> extends StatefulWidget {
  const _TypeChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final TypeOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TypeChip<T>> createState() => _TypeChipState<T>();
}

class _TypeChipState<T> extends State<_TypeChip<T>> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final bg = selected
        ? AppColors.accentSoft
        : (_hover ? AppColors.surfaceAlt : AppColors.surface);
    final fg = selected ? AppColors.accentHover : AppColors.muted;
    final border = selected ? AppColors.accent : AppColors.border;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: AppRadius.smBorder,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.option.icon != null) ...[
                Icon(widget.option.icon,
                    size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                widget.option.label,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
