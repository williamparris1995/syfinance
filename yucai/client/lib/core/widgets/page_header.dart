import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 页面标题行（列表页顶部）：serif 大标题 + 可选副标题 + 右侧操作区 slot。
///
/// 对应设计规范 §3.1「页面标题行（h1 标题 + ... | + 新建按钮）」。
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

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
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
        if (actions != null && actions!.isNotEmpty)
          Row(mainAxisSize: MainAxisSize.min, children: actions!),
      ],
    );
  }
}

/// 圆角主操作按钮（御财金）——「+ 新建账户」等。
class PrimaryActionButton extends StatefulWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<PrimaryActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: FilledButton.icon(
        onPressed: widget.onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _hover ? AppColors.accentHover : AppColors.accent,
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.smBorder),
        ),
        icon: Icon(widget.icon, size: 18),
        label: Text(widget.label),
      ),
    );
  }
}
