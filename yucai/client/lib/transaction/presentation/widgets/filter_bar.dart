import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';

/// 交易筛选状态（snapshot）。由列表页持有，变化时通过 [onChanged] 回调。
class TxnFilterState {
  const TxnFilterState({
    this.type = TxnTypeFilter.all,
    this.accountId,
    this.category,
    this.month,
  });

  /// 类型分段：用 [TxnTypeFilter] 表示「全部/收入/支出/转账」四态（含「全部」）。
  /// 与 domain 的 TxnFlavour（单笔交易真实归类）分开，因为筛选器需要「全部」态。
  final TxnTypeFilter type;

  /// 限定账户 id；null = 全部账户。
  final String? accountId;

  /// 限定分类（账户 category，复用 AccountCategory）；null = 全部分类。
  final String? category;

  /// 限定月份（YYYY-MM）；null = 全部月份。
  final String? month;

  bool get isDefault =>
      type == TxnTypeFilter.all &&
      accountId == null &&
      category == null &&
      month == null;

  TxnFilterState copyWith({
    TxnTypeFilter? type,
    Object? accountId = _sentinel,
    Object? category = _sentinel,
    Object? month = _sentinel,
  }) {
    return TxnFilterState(
      type: type ?? this.type,
      accountId: identical(accountId, _sentinel) ? this.accountId : accountId as String?,
      category: identical(category, _sentinel) ? this.category : category as String?,
      month: identical(month, _sentinel) ? this.month : month as String?,
    );
  }

  static const _sentinel = Object();
}

/// 顶层「全部/收入/支出/转账」分段。与 domain 的 [TxnFlavour] 分开：
/// domain flavour 是单笔交易的真实归类，本枚举是筛选器 UI 的四态（含「全部」）。
enum TxnTypeFilter { all, income, expense, transfer }

extension TxnTypeFilterLabel on TxnTypeFilter {
  String get label {
    switch (this) {
      case TxnTypeFilter.all:
        return '全部';
      case TxnTypeFilter.income:
        return '收入';
      case TxnTypeFilter.expense:
        return '支出';
      case TxnTypeFilter.transfer:
        return '转账';
    }
  }
}

/// 交易列表筛选栏。
///
/// 组成：类型分段（全部/收入/支出/转账） + 账户下拉 + 分类下拉 + 月份选择 + 重置。
/// 回调形式：任何字段变化都通过 [onChanged] 整体回传新的 [TxnFilterState]。
/// 调用方负责把当前状态传回 [state]（受控组件）。
///
/// Mobile：垂直堆叠；Tablet/Desktop：一行铺开。
class TxnFilterBar extends StatelessWidget {
  const TxnFilterBar({
    super.key,
    required this.state,
    required this.onChanged,
    this.accountOptions = const [],
    this.categoryOptions = const [],
    this.monthOptions = const [],
  });

  final TxnFilterState state;
  final ValueChanged<TxnFilterState> onChanged;

  /// 可选账户：(id, 显示名) 列表。调用方从 account list 注入。
  final List<FilterOption> accountOptions;
  final List<FilterOption> categoryOptions;
  final List<FilterOption> monthOptions;

  void _setAccount(String? id) => onChanged(state.copyWith(accountId: id));
  void _setCategory(String? c) => onChanged(state.copyWith(category: c));
  void _setMonth(String? m) => onChanged(state.copyWith(month: m));
  void _reset() => onChanged(const TxnFilterState(type: TxnTypeFilter.all));

  @override
  Widget build(BuildContext context) {
    // 类型分段抽到独立 TxnTypeSeg(transactions_page 渲染),TxnFilterBar 只保留
    // 账户/分类/月份 下拉 + 重置。
    final accountPicker = _Picker(
      label: '账户',
      value: state.accountId,
      options: accountOptions,
      onChanged: _setAccount,
    );
    final categoryPicker = _Picker(
      label: '分类',
      value: state.category,
      options: categoryOptions,
      onChanged: _setCategory,
    );
    final monthPicker = _Picker(
      label: '月份',
      value: state.month,
      options: monthOptions,
      onChanged: _setMonth,
    );
    final resetBtn = _ResetButton(onTap: _reset, enabled: !state.isDefault);

    return ResponsiveLayout(
      mobile: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: _boxDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            accountPicker,
            const SizedBox(height: AppSpacing.xs),
            categoryPicker,
            const SizedBox(height: AppSpacing.xs),
            monthPicker,
            const SizedBox(height: AppSpacing.sm),
            Align(alignment: Alignment.centerRight, child: resetBtn),
          ],
        ),
      ),
      tablet: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: _boxDecoration,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            accountPicker,
            categoryPicker,
            monthPicker,
            resetBtn,
          ],
        ),
      ),
      desktop: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: _boxDecoration,
        child: Row(
          children: [
            // 三个下拉用 flex 而非固定宽度,避免在窄容器里溢出。
            Expanded(flex: 2, child: accountPicker),
            const SizedBox(width: AppSpacing.sm),
            Expanded(flex: 2, child: categoryPicker),
            const SizedBox(width: AppSpacing.sm),
            Expanded(flex: 2, child: monthPicker),
            const SizedBox(width: AppSpacing.sm),
            resetBtn,
          ],
        ),
      ),
    );
  }

  static final _boxDecoration = BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppRadius.smBorder,
    border: Border.all(color: AppColors.border),
  );
}

/// 下拉项（值 + 显示文案）。
class FilterOption {
  const FilterOption(this.value, this.label);
  final String value;
  final String label;
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<FilterOption> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    // null 在下拉里显示为「全部{label}」。
    final all = FilterOption('', '全部$label');
    final fullOptions = [all, ...options];
    final selectedValue = value ?? '';
    return DropdownButtonFormField<String>(
      initialValue: selectedValue.isEmpty ? '' : selectedValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: AppColors.border),
        ),
      ),
      items: [
        for (final o in fullOptions)
          DropdownMenuItem(value: o.value, child: Text(o.label)),
      ],
      onChanged: (v) => onChanged(v == '' ? null : v),
    );
  }
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onTap, required this.enabled});
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? AppColors.accent : AppColors.muted;
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: AppRadius.smBorder,
            border: Border.all(color: fg),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, size: 14, color: fg),
              const SizedBox(width: 4),
              Text('重置',
                  style: TextStyle(
                      color: fg, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
