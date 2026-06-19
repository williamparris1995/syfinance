import 'package:flutter/material.dart';

import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/widgets/account_category_style.dart';

/// 分类标签 chip。
///
/// 两种入参形态：
///   - [CategoryChip.fromCategory] —— 由 [AccountCategory] 派生颜色+图标（
///     复用 [categoryColor]/[categoryIcon]，与账户列表保持一致）；
///   - [CategoryChip.fromName] —— 直接给名字+颜色（适配未来 transaction 自有
///     category 树，或临时占位）。
///
/// 风格：圆角 pill，浅色底（颜色 12% 不透明度）+ 深色字（同色 100%）+ 小图标。
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.onTap,
    this.selected = false,
  });

  factory CategoryChip.fromCategory(
    AccountCategory category, {
    Key? key,
    String? labelOverride,
    VoidCallback? onTap,
    bool selected = false,
  }) {
    return CategoryChip(
      key: key,
      label: labelOverride ?? category.label,
      color: categoryColor(category),
      icon: categoryIcon(category),
      onTap: onTap,
      selected: selected,
    );
  }

  factory CategoryChip.fromName(
    String name,
    Color color, {
    Key? key,
    IconData? icon,
    VoidCallback? onTap,
    bool selected = false,
  }) {
    return CategoryChip(
      key: key,
      label: name,
      color: color,
      icon: icon,
      onTap: onTap,
      selected: selected,
    );
  }

  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? color : color.withValues(alpha: 0.12);
    final fg = selected ? Colors.white : color;
    final border = selected ? color : color.withValues(alpha: 0.35);

    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: fg),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
