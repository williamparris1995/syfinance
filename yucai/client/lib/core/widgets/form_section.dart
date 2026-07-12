import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 表单外层卡片（max-width 760 居中）。对应设计规范 §3.3「表单卡片」。
class FormCard extends StatelessWidget {
  const FormCard({
    super.key,
    required this.child,
    this.maxWidth = 760,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgBorder,
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 16,
                  offset: Offset(0, 4)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 表单分区：大写小字标题 + 底边框 + 字段列。对应规范 §3.3「FormSection」。
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    required this.children,
    this.fieldSpacing = AppSpacing.md,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final double fieldSpacing;
  final Widget? trailing; // 可选 title 右侧 widget(如 badge);默认 null 不破坏现有调用

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) SizedBox(height: fieldSpacing),
        ],
      ],
    );
  }
}

/// 字段行：1/2/3 列等分网格。对应规范 §3.3「FormRow」。
class FormRow extends StatelessWidget {
  const FormRow({
    super.key,
    required this.children,
    this.spacing = AppSpacing.md,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.length <= 1) return children.first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

/// 表单底部操作栏：[取消] ··· [确认创建]。对应规范 §3.3「操作栏」。
class FormActions extends StatelessWidget {
  const FormActions({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
    this.onCancel,
    this.submitting = false,
  });

  final String submitLabel;
  final VoidCallback onSubmit;
  final VoidCallback? onCancel;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (onCancel != null)
          TextButton(
            onPressed: submitting ? null : onCancel,
            child: const Text('取消'),
          ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: submitting ? null : onSubmit,
          child: submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(submitLabel),
        ),
      ],
    );
  }
}
