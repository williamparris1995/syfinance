import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/backup/domain/entities/backup_entity.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_bloc.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_event.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_state.dart';
import 'package:yucai_client/backup/presentation/widgets/backup_card.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// 本地备份页：topbar(返回 + 标题 + 立即备份)+ 三态 body(loading/空/错误/列表)
/// + 三个 dialog(创建 encrypted / 恢复 confirm+password / 删除 confirm)。
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  @override
  void initState() {
    super.initState();
    // 进入即拉列表（路由层已 provide BackupBloc）。
    context.read<BackupBloc>().add(LoadBackupsRequested());
  }

  /// 创建备份：encrypted 三选 dialog（取消 / 不加密 / 加密）。
  /// 加密时第二步收 password（TextField obscureText，空则 SnackBar 提示）。
  /// CreateBackupRequest{encrypted, password}：非加密传空串。
  /// 加密分支的 TextEditingController 用 try/finally dispose（对齐
  /// _showRestoreDialog,避免 leak;memory 记曾因同步 dispose crash → 若
  /// teardown race 复现改 WidgetsBinding.addPostFrameCallback deferred dispose)。
  Future<void> _showCreateDialog() async {
    final encrypted = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('创建备份'),
        content: const Text('是否加密备份文件？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('不加密'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('加密'),
          ),
        ],
      ),
    );
    if (encrypted == null || !mounted) return;

    String password = '';
    if (encrypted) {
      final ctrl = TextEditingController();
      try {
        final ok = await showDialog<bool>(
          context: context,
          builder: (dctx) => AlertDialog(
            title: const Text('加密备份'),
            content: TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: '密码',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dctx, true),
                child: const Text('确认'),
              ),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        password = ctrl.text;
      } finally {
        // Defer dispose to a post-frame callback: 同步 dispose 在 dialog
        // teardown 帧中触发 "TextEditingController used after being disposed"
        // race(TextField 的 _AnimatedState 仍在帧间 attach listener)。
        // post-frame 让 dialog widget 先完整 detach 再 dispose,对齐 restore
        // dialog 无 crash 的行为(memory 记此为已知 race)。
        WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
      }
      if (password.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('密码不能为空')));
        return;
      }
    }
    if (!mounted) return;
    context.read<BackupBloc>().add(CreateBackupRequested(encrypted, password));
  }

  /// 恢复备份：覆盖当前数据 → confirm 警告；加密备份需 password。
  /// RestoreBackupRequest{backupId, password}：非加密传空串。
  Future<void> _showRestoreDialog(Backup backup) async {
    final passwordController = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('恢复备份'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⚠️ 恢复将覆盖当前所有数据，此操作不可逆，确定？',
                style: TextStyle(color: AppColors.negative),
              ),
              if (backup.encrypted) ...[
                const SizedBox(height: AppSpacing.md),
                const Text(
                  '恢复加密备份，请输入密码：',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '密码',
                    isDense: true,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('确认恢复'),
            ),
          ],
        ),
      );
      if (ok == true && mounted) {
        final pwd = backup.encrypted ? passwordController.text : '';
        context.read<BackupBloc>().add(
              RestoreBackupRequested(id: backup.id, password: pwd),
            );
      }
    } finally {
      passwordController.dispose();
    }
  }

  /// 删除备份：confirm（对齐 budget_detail_page._confirmDelete 模式）。
  Future<void> _showDeleteDialog(Backup backup) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('删除备份'),
        content: Text('确定删除「${backup.filename}」？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<BackupBloc>().add(DeleteBackupRequested(backup.id));
    }
  }

  /// 当前要显示的列表：Loaded 直取；Loading/Submitting/Error/ActionSuccess
  /// 取 last（避免刷新/操作时列表闪烁）；Initial 取空。
  List<Backup> _listOf(BackupState state) {
    switch (state) {
      case BackupsLoaded(:final backups):
        return backups;
      case BackupLoading(:final last):
        return last;
      case BackupSubmitting(:final last):
        return last;
      case BackupActionSuccess(:final last):
        return last;
      case BackupError(:final last):
        return last;
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: BlocListener<BackupBloc, BackupState>(
        listenWhen: (prev, curr) =>
            curr is BackupActionSuccess ||
            (curr is BackupError && curr.last.isNotEmpty),
        listener: (ctx, state) {
          String? msg;
          if (state is BackupActionSuccess) {
            msg = state.message;
          } else if (state is BackupError) {
            msg = state.message;
          }
          if (msg != null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(msg)),
            );
          }
        },
        child: SafeArea(
          child: Column(
            children: [
              _topbar(),
              const Divider(height: 1, color: AppColors.border),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            icon: const Icon(LucideIcons.chevronLeft, color: AppColors.fg),
            onPressed: () => context.pop(),
          ),
          const Expanded(
            child: Text(
              '本地备份',
              style: TextStyle(
                color: AppColors.fg,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () { _showCreateDialog(); },
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('立即备份'),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    return BlocBuilder<BackupBloc, BackupState>(
      builder: (ctx, state) {
        final list = _listOf(state);
        final submitting = state is BackupSubmitting;
        final isFirstLoad = state is BackupLoading && list.isEmpty;
        return Stack(
          children: [
            if (isFirstLoad)
              const Center(child: CircularProgressIndicator())
            else if (state is BackupError && list.isEmpty)
              _errorState(state.message)
            else if (list.isEmpty)
              _emptyState()
            else
              _listView(list),
            if (submitting) _loadingOverlay(),
          ],
        );
      },
    );
  }

  Widget _listView(List<Backup> backups) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: backups.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (ctx, i) {
        final b = backups[i];
        return BackupCard(
          backup: b,
          onRestore: () => _showRestoreDialog(b),
          onDelete: () => _showDeleteDialog(b),
        );
      },
    );
  }

  Widget _emptyState() {
    // LucideIcons.databaseBackup 若包版本缺失 → 降级 LucideIcons.database。
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: AppRadius.lgBorder,
            ),
            child: const Icon(LucideIcons.databaseBackup,
                color: AppColors.accent, size: 28),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            '暂无备份',
            style: TextStyle(
              color: AppColors.fg,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            '点击「立即备份」创建第一个备份',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.alertCircle, color: AppColors.negative, size: 36),
          const SizedBox(height: AppSpacing.md),
          const Text(
            '加载失败',
            style: TextStyle(
              color: AppColors.fg,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () =>
                context.read<BackupBloc>().add(LoadBackupsRequested()),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 提交中遮罩：AbsorbPointer 拦截点击 + 半透明背景 + spinner。
  Widget _loadingOverlay() {
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: AppColors.bg.withValues(alpha: 0.5),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
