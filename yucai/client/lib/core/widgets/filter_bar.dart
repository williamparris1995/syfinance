import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 筛选标签栏（列表页统一模式）：pill 按钮组 + 可选搜索框。
///
/// 对应设计规范 §3.1「筛选标签栏（pill 按钮组 + 搜索框）」。
class FilterBar<T> extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.tabs,
    required this.active,
    required this.onChanged,
    this.searchHint,
    this.onSearch,
  });

  /// (值, 展示文案) 有序列表。
  final List<FilterTab<T>> tabs;
  final T active;
  final ValueChanged<T> onChanged;
  final String? searchHint;
  final ValueChanged<String>? onSearch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final tab in tabs) _Pill<T>(
                tab: tab,
                selected: tab.value == active,
                onTap: () => onChanged(tab.value),
              ),
            ],
          ),
        ),
        if (onSearch != null)
          SizedBox(
            width: 220,
            child: TextField(
              onChanged: onSearch,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: searchHint ?? '搜索',
                isDense: true,
                prefixIcon: const Icon(LucideIcons.search,
                    size: 18, color: AppColors.muted),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
      ],
    );
  }
}

class FilterTab<T> {
  const FilterTab(this.value, this.label);
  final T value;
  final String label;
}

class _Pill<T> extends StatefulWidget {
  const _Pill({required this.tab, required this.selected, required this.onTap});
  final FilterTab<T> tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Pill<T>> createState() => _PillState<T>();
}

class _PillState<T> extends State<_Pill<T>> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final bg = selected
        ? AppColors.accent
        : (_hover ? AppColors.surfaceAlt : AppColors.surface);
    final fg = selected ? Colors.white : AppColors.muted;
    final border = selected ? AppColors.accent : AppColors.border;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            widget.tab.label,
            style: TextStyle(
                color: fg, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
