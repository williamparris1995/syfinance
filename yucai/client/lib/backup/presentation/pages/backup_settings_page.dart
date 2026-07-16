import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/backup/domain/entities/backup_settings_entity.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_settings_bloc.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_settings_event.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_settings_state.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// 自动备份配置页（settings 子页 /settings/backup/auto，P1 Task 5）。
///
/// UI：
/// - AutoBackup 开关（Switch）
/// - 备份频率 dropdown：12h / 24h / 48h / 7 天（168h）
/// - 保存按钮 → SaveSettingsRequested
///
/// 模式对齐 BackupPage：topbar（返回 + 标题）+ 三态 body（loading / form /
/// error）+ BlocListener SnackBar 反馈。表单用御财 surface card（同
/// SettingsPage._SettingsCard）。
///
/// **注意**：本地备份文件依然存在（用户随时可「立即备份」）；本页只配置
/// **服务端定时**任务（开关 + 频率）。scheduler 由 server 端按 tenant 配置
/// 自行 fan-out（见 server P1 Task 3）。
class BackupSettingsPage extends StatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  /// 表单本地状态：进入时由 bloc Loaded 预填；用户交互立即 setSt 同步控件，
  /// 不直接 dispatch（dispatch 只在「保存」时）。
  bool _autoBackup = false;
  int _intervalHours = 24;
  bool _hydrated = false; // 防止 Loaded 重建时重置用户改动

  @override
  void initState() {
    super.initState();
    context.read<BackupSettingsBloc>().add(LoadSettingsRequested());
  }

  void _hydrate(BackupSettings s) {
    if (_hydrated) return;
    _autoBackup = s.autoBackup;
    _intervalHours = s.intervalHours == 0 ? 24 : s.intervalHours;
    _hydrated = true;
  }

  void _onSave() {
    context.read<BackupSettingsBloc>().add(SaveSettingsRequested(
          autoBackup: _autoBackup,
          intervalHours: _intervalHours,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: BlocListener<BackupSettingsBloc, BackupSettingsState>(
        // 仅保存成功 / 保存失败时弹 SnackBar：
        // - Saved：固定提示「已保存」。
        // - Error 且 prev 已有 settings（即 load 成功过、save 失败）：弹错误
        //   信息。首载 load 失败由 _errorState 全屏展示，无需 SnackBar 重复。
        listenWhen: (prev, curr) =>
            curr is BackupSettingsSaved ||
            (curr is BackupSettingsError && prev.settings != null),
        listener: (ctx, state) {
          final msg = state is BackupSettingsSaved
              ? state.message
              : (state is BackupSettingsError ? state.message : null);
          if (msg != null) {
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
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
              '自动备份',
              style: TextStyle(
                color: AppColors.fg,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    return BlocBuilder<BackupSettingsBloc, BackupSettingsState>(
      builder: (ctx, state) {
        // Loaded/Saving/Saved/Error 若携带 settings，且尚未 hydrate → 预填表单。
        final s = state.settings;
        if (s != null) _hydrate(s);

        if (state is BackupSettingsLoading && !_hydrated) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is BackupSettingsError && !_hydrated) {
          return _errorState(state.message);
        }
        final saving = state is BackupSettingsSaving;
        return Stack(
          children: [
            _form(saving),
            if (saving) _loadingOverlay(),
          ],
        );
      },
    );
  }

  Widget _form(bool saving) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('自动备份',
                  style: TextStyle(
                      color: AppColors.fg,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFamily: AppTypography.displayFamily,
                      fontFamilyFallback: AppTypography.displayFallback)),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                '开启后服务端将按设定频率自动生成本地备份',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.md),
              _SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SwitchRow(
                      label: '启用自动备份',
                      description: '关闭后仅保留手动备份',
                      value: _autoBackup,
                      onChanged: saving
                          ? null
                          : (v) => setState(() => _autoBackup = v),
                    ),
                    if (_autoBackup) ...[
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: AppSpacing.md),
                      _IntervalRow(
                        value: _intervalHours,
                        onChanged: saving
                            ? null
                            : (h) => setState(() => _intervalHours = h),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saving ? null : _onSave,
                  icon: const Icon(LucideIcons.save, size: 18),
                  label: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.alertCircle,
              color: AppColors.negative, size: 36),
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
            onPressed: () => context
                .read<BackupSettingsBloc>()
                .add(LoadSettingsRequested()),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

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

/// 御财 surface card（与 SettingsPage._SettingsCard 一致，复用样式）。
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(description,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.accent,
        ),
      ],
    );
  }
}

/// 备份频率选择行。options = 12 / 24 / 48 / 168 小时（12h / 24h / 48h / 7 天）。
/// 对齐 SettingsPage._IntervalDropdown 视觉（dropdown + chevron down icon）。
class _IntervalRow extends StatelessWidget {
  const _IntervalRow({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int>? onChanged;

  static const _options = <int>[12, 24, 48, 168];

  static String _label(int hours) {
    // 对齐 brief：12h / 24h / 48h / 7 天（168h）。仅 168h 转天显示，其余保
    // 留小时数（24/48 不转 "1 天" / "2 天"，与 brief 字面一致、易识别频率）。
    if (hours >= 168) return '7 天';
    return '${hours}h';
  }

  @override
  Widget build(BuildContext context) {
    final items = _options
        .map((h) => DropdownMenuItem<int>(
              value: h,
              child: Text(_label(h),
                  style: const TextStyle(fontSize: 14)),
            ))
        .toList();
    final v = _options.contains(value) ? value : 24;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('备份频率',
                  style: TextStyle(
                      color: AppColors.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              const Text('两次自动备份之间的间隔',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 120,
          child: DropdownButton<int>(
            value: v,
            items: items,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: AppColors.surface,
            icon: const Icon(LucideIcons.chevronDown,
                color: AppColors.accent, size: 20),
            onChanged: (h) {
              if (h != null) onChanged?.call(h);
            },
          ),
        ),
      ],
    );
  }
}
