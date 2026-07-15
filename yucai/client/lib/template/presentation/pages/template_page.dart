import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/utils/date_format.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/template/presentation/bloc/template_bloc.dart';
import 'package:yucai_client/template/presentation/bloc/template_event.dart';
import 'package:yucai_client/template/presentation/bloc/template_state.dart';
import 'package:yucai_client/template/presentation/widgets/template_card.dart';
import 'package:yucai_client/template/presentation/widgets/template_form.dart';

/// 周期模板页(列表 CRUD + record + pause/resume)。对齐 tag TagPage:
/// topbar(返回 + 标题「周期模板」+ 新建)+ 三态 body(loading/空/错误/列表)
/// + BlocListener→SnackBar + Stack 提交遮罩。
class TemplatePage extends StatefulWidget {
  const TemplatePage({super.key});
  @override
  State<TemplatePage> createState() => _TemplatePageState();
}

class _TemplatePageState extends State<TemplatePage> {
  @override
  void initState() {
    super.initState();
    context.read<TemplateBloc>().add(LoadTemplatesRequested());
  }

  void _showCreateDialog() {
    showDialog<void>(
      context: context,
      builder: (dctx) => TemplateForm(
        onSubmit: (r) {
          Navigator.pop(dctx);
          context.read<TemplateBloc>().add(_createEvent(r));
        },
      ),
    );
  }

  void _showEditDialog(Template t) {
    showDialog<void>(
      context: context,
      builder: (dctx) => TemplateForm(
        existing: t,
        onSubmit: (r) {
          Navigator.pop(dctx);
          context.read<TemplateBloc>().add(_updateEvent(t, r));
        },
      ),
    );
  }

  CreateTemplateRequested _createEvent(TemplateFormResult r) =>
      CreateTemplateRequested(
        name: r.name,
        description: r.description,
        amountCents: r.amountCents,
        direction: r.direction,
        sourceAccountId: r.sourceAccountId,
        destinationAccountId: r.destinationAccountId,
        cycle: r.cycle,
        cycleDays: r.cycleDays,
        billingDay: r.billingDay,
        startDate: r.startDate == null ? null : formatDate(r.startDate),
        endDate: r.endDate == null ? null : formatDate(r.endDate),
        autoRecord: r.autoRecord,
        category: r.category,
      );

  UpdateTemplateRequested _updateEvent(Template t, TemplateFormResult r) =>
      UpdateTemplateRequested(
        id: t.id,
        version: t.version,
        name: r.name,
        description: r.description,
        amountCents: r.amountCents,
        cycle: r.cycle,
        cycleDays: r.cycleDays,
        endDate: r.endDate == null ? null : formatDate(r.endDate),
        autoRecord: r.autoRecord,
      );

  Future<void> _showDeleteConfirm(Template t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('删除模板'),
        content: Text('确定删除「${t.name}」?此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('取消')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<TemplateBloc>().add(DeleteTemplateRequested(t.id));
    }
  }

  List<Template> _listOf(TemplateState s) {
    if (s is TemplatesLoaded) return s.templates;
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: BlocListener<TemplateBloc, TemplateState>(
        listenWhen: (p, c) => c is TemplateActionSuccess,
        listener: (ctx, s) {
          if (s is TemplateActionSuccess) {
            ScaffoldMessenger.of(ctx)
                .showSnackBar(SnackBar(content: Text(s.message)));
          }
        },
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
                child: Row(
                  children: [
                    IconButton(
                        tooltip: '返回',
                        icon: const Icon(LucideIcons.chevronLeft,
                            color: AppColors.fg),
                        onPressed: () => context.pop()),
                    const Expanded(
                      child: Text('周期模板',
                          style: TextStyle(
                              color: AppColors.fg,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppTypography.displayFamily,
                              fontFamilyFallback: AppTypography.displayFallback)),
                    ),
                    FilledButton.icon(
                        onPressed: _showCreateDialog,
                        icon: const Icon(LucideIcons.plus, size: 18),
                        label: const Text('新建模板')),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    return BlocBuilder<TemplateBloc, TemplateState>(
      builder: (ctx, state) {
        final list = _listOf(state);
        final submitting = state is TemplateSubmitting;
        if (state is TemplateLoading && list.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is TemplateError && list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.alertCircle,
                    color: AppColors.negative, size: 36),
                const SizedBox(height: AppSpacing.md),
                Text(state.message,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                    onPressed: () => ctx
                        .read<TemplateBloc>()
                        .add(LoadTemplatesRequested()),
                    child: const Text('重试')),
              ],
            ),
          );
        } else if (list.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.repeat,
                    color: AppColors.accent, size: 28),
                SizedBox(height: AppSpacing.md),
                Text('暂无周期模板',
                    style: TextStyle(
                        color: AppColors.fg,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: AppSpacing.xs),
                Text('点击「新建模板」创建房租 / 工资等周期交易',
                    style:
                        TextStyle(color: AppColors.muted, fontSize: 13)),
              ],
            ),
          );
        }
        return Stack(
          children: [
            ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final t = list[i];
                return TemplateCard(
                  template: t,
                  onRecord: () => ctx
                      .read<TemplateBloc>()
                      .add(RecordTemplateRequested(t.id)),
                  onTogglePause: () => ctx.read<TemplateBloc>().add(
                      t.paused
                          ? ResumeTemplateRequested(t.id)
                          : PauseTemplateRequested(t.id)),
                  onEdit: () => _showEditDialog(t),
                  onDelete: () => _showDeleteConfirm(t),
                );
              },
            ),
            if (submitting)
              Positioned.fill(
                child: AbsorbPointer(
                  child: Container(
                    color: AppColors.bg.withValues(alpha: 0.5),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
