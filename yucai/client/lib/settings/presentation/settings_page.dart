import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_event.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';

/// 设置页 —— 偏好货币 + 汇率同步频率。
///
/// 读 [CurrencyBloc] 的 currencies 列表 + 当前 preferred / interval，
/// onChange → [AuthRemoteDataSource.updatePreferences] → 成功 toast +
/// `LoadPreferencesRequested` 刷新。
///
/// 御财 token：surface card (`AppColors.surface` + `AppRadius.lgBorder` +
/// `AppSpacing.md`)；dropdown 选中色 `AppColors.accent`。
class SettingsPage extends StatelessWidget {
  /// 生产用默认 getIt 实例；测试可注入 mock。
  const SettingsPage({super.key, AuthRemoteDataSource? authRemote})
      : _authRemote = authRemote;

  final AuthRemoteDataSource? _authRemote;

  @override
  Widget build(BuildContext context) {
    // 延迟到 build 取 getIt，避免测试构造时未配置 DI 就崩溃；显式注入优先。
    final ds = _authRemote ?? getIt<AuthRemoteDataSource>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: const Text('设置'),
      ),
      body: BlocBuilder<CurrencyBloc, CurrencyState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('偏好设置',
                        style: TextStyle(
                            color: AppColors.fg,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            fontFamily: AppTypography.displayFamily,
                            fontFamilyFallback: AppTypography.displayFallback)),
                    const SizedBox(height: AppSpacing.md),
                    _SettingsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PreferenceRow(
                            label: '偏好货币',
                            description: '用于余额汇总与报表展示',
                            control: _CurrencyDropdown(
                              state: state,
                              onChanged: (code) => _onCurrencyChanged(
                                  context, ds, code, state.intervalHours),
                            ),
                          ),
                          const Divider(
                              height: 1, color: AppColors.border),
                          const SizedBox(height: AppSpacing.md),
                          _PreferenceRow(
                            label: '汇率同步频率',
                            description: '多久从汇率源拉取一次最新汇率',
                            control: _IntervalDropdown(
                              value: state.intervalHours,
                              onChanged: (hours) => _onIntervalChanged(
                                  context, ds, state.preferred, hours),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onCurrencyChanged(
    BuildContext context,
    AuthRemoteDataSource ds,
    String preferred,
    int interval,
  ) async {
    try {
      await ds.updatePreferences(preferred, interval);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('偏好货币已更新')),
      );
      context.read<CurrencyBloc>().add(const LoadPreferencesRequested());
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败：$e')),
      );
    }
  }

  Future<void> _onIntervalChanged(
    BuildContext context,
    AuthRemoteDataSource ds,
    String preferred,
    int interval,
  ) async {
    try {
      await ds.updatePreferences(preferred, interval);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('同步频率已更新')),
      );
      context.read<CurrencyBloc>().add(const LoadPreferencesRequested());
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败：$e')),
      );
    }
  }
}

/// 御财 surface card：`AppColors.surface` + `AppRadius.lgBorder` + 内边距
/// `AppSpacing.md`。
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

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.label,
    required this.description,
    required this.control,
  });

  final String label;
  final String description;
  final Widget control;

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
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        control,
      ],
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({required this.state, required this.onChanged});

  final CurrencyState state;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = state.currencies
        .map((c) => DropdownMenuItem<String>(
              value: c.code,
              child: Text('${c.code} · ${c.name}',
                  style: const TextStyle(fontSize: 14)),
            ))
        .toList();
    // preferred 可能不在 currencies 列表（服务端返回的 code 未在 currency 表），
    // 此时 DropdownButton.value 必须是 items 之一，否则断言；回退到首个。
    final value = state.currencies.any((c) => c.code == state.preferred)
        ? state.preferred
        : (state.currencies.isEmpty ? null : state.currencies.first.code);
    return SizedBox(
      width: 200,
      child: DropdownButton<String>(
        value: value,
        items: items,
        isExpanded: true,
        underline: const SizedBox(),
        // 御财金强调选中态：通过 dropdownColor + iconColor 表达。
        dropdownColor: AppColors.surface,
        icon: const Icon(Icons.expand_more,
            color: AppColors.accent, size: 20),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _IntervalDropdown extends StatelessWidget {
  const _IntervalDropdown({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _options = <int>[1, 8, 12, 24];

  @override
  Widget build(BuildContext context) {
    final items = _options
        .map((h) => DropdownMenuItem<int>(
              value: h,
              child: Text('${h}h',
                  style: const TextStyle(fontSize: 14)),
            ))
        .toList();
    final v = _options.contains(value) ? value : 24;
    return SizedBox(
      width: 120,
      child: DropdownButton<int>(
        value: v,
        items: items,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: AppColors.surface,
        icon: const Icon(Icons.expand_more,
            color: AppColors.accent, size: 20),
        onChanged: (h) {
          if (h != null) onChanged(h);
        },
      ),
    );
  }
}
