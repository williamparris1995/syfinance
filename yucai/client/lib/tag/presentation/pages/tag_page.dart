import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/presentation/bloc/tag_bloc.dart';
import 'package:yucai_client/tag/presentation/bloc/tag_event.dart';
import 'package:yucai_client/tag/presentation/bloc/tag_state.dart';
import 'package:yucai_client/tag/presentation/widgets/tag_card.dart';
import 'package:yucai_client/tag/presentation/widgets/tag_color_picker.dart';

/// 标签管理页(settings 子页 /settings/tags)。对齐 backup BackupPage:
/// topbar(返回 + 标题 + 新建)+ 三态 body(loading/空/错误/列表)+ BlocListener→SnackBar。
class TagPage extends StatefulWidget {
  const TagPage({super.key});
  @override
  State<TagPage> createState() => _TagPageState();
}

class _TagPageState extends State<TagPage> {
  @override
  void initState() {
    super.initState();
    context.read<TagBloc>().add(LoadTagsRequested());
  }

  void _showCreateDialog() {
    _showEditDialog(tag: null);
  }

  void _showEditDialog({Tag? tag}) {
    final isEdit = tag != null;
    final nameCtrl = TextEditingController(text: tag?.name ?? '');
    String color = tag?.color ?? '#b08d57';
    showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setSt) => AlertDialog(
          title: Text(isEdit ? '编辑标签' : '新建标签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('名称', style: TextStyle(color: context.yucai.muted, fontSize: 12)),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, hintText: '如:日常'),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('颜色', style: TextStyle(color: context.yucai.muted, fontSize: 12)),
              const SizedBox(height: AppSpacing.xs),
              TagColorPicker(selected: color, onChanged: (c) => setSt(() => color = c)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(dctx).showSnackBar(const SnackBar(content: Text('名称不能为空')));
                  return;
                }
                Navigator.pop(dctx);
                if (isEdit) {
                  context.read<TagBloc>().add(UpdateTagRequested(id: tag.id, name: name, color: color, version: tag.version));
                } else {
                  context.read<TagBloc>().add(CreateTagRequested(name, color));
                }
              },
              child: Text(isEdit ? '保存' : '创建'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirm(Tag tag) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('确定删除「${tag.name}」?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('取消')),
          TextButton(style: TextButton.styleFrom(foregroundColor: context.yucai.negative), onPressed: () => Navigator.pop(dctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<TagBloc>().add(DeleteTagRequested(tag.id));
    }
  }

  List<Tag> _listOf(TagState s) {
    if (s is TagsLoaded) return s.tags;
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yucai.bg,
      body: BlocListener<TagBloc, TagState>(
        listenWhen: (p, c) => c is TagActionSuccess,
        listener: (ctx, s) {
          if (s is TagActionSuccess) {
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(s.message)));
          }
        },
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
                child: Row(
                  children: [
                    IconButton(tooltip: '返回', icon: Icon(LucideIcons.chevronLeft, color: context.yucai.fg), onPressed: () => context.pop()),
                    Expanded(child: Text('标签管理', style: TextStyle(color: context.yucai.fg, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: AppTypography.displayFamily, fontFamilyFallback: AppTypography.displayFallback))),
                    FilledButton.icon(onPressed: _showCreateDialog, icon: const Icon(LucideIcons.plus, size: 18), label: const Text('新建标签')),
                  ],
                ),
              ),
              Divider(height: 1, color: context.yucai.border),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    return BlocBuilder<TagBloc, TagState>(
      builder: (ctx, state) {
        final list = _listOf(state);
        final submitting = state is TagSubmitting;
        if (state is TagLoading && list.isEmpty) {
          return Center(child: CircularProgressIndicator());
        } else if (state is TagError && list.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.alertCircle, color: context.yucai.negative, size: 36),
            SizedBox(height: AppSpacing.md),
            Text(state.message, style: TextStyle(color: context.yucai.muted, fontSize: 13)),
            SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: () => ctx.read<TagBloc>().add(LoadTagsRequested()), child: Text('重试')),
          ]));
        } else if (list.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.tag, color: context.yucai.accent, size: 28),
            SizedBox(height: AppSpacing.md),
            Text('暂无标签', style: TextStyle(color: context.yucai.fg, fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: AppSpacing.xs),
            Text('点击「新建标签」创建', style: TextStyle(color: context.yucai.muted, fontSize: 13)),
          ]));
        }
        return Stack(children: [
          ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) {
              final t = list[i];
              return TagCard(tag: t, onEdit: () => _showEditDialog(tag: t), onDelete: () => _showDeleteConfirm(t));
            },
          ),
          if (submitting) Positioned.fill(child: AbsorbPointer(child: Container(color: context.yucai.bg.withValues(alpha: 0.5), alignment: Alignment.center, child: const CircularProgressIndicator()))),
        ]);
      },
    );
  }
}
