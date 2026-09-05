import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';
/// 交易筛选状态（snapshot）。由列表页持有，变化时通过 [onChanged] 回调。
class TxnFilterState {
  const TxnFilterState({
    this.type = TxnTypeFilter.all,
    this.accountId,
    this.category,
    this.month,
    this.tagId,
    this.searchText,
    this.sortKey = TxnSortKey.date,
    this.sortDir = TxnSortDir.desc,
  });

  /// 类型分段：用 [TxnTypeFilter] 表示「全部/收入/支出/转账」四态（含「全部」）。
  /// 与 domain 的 TxnFlavour（单笔交易真实归类）分开，因为筛选器需要「全部」态。
  final TxnTypeFilter type;

  /// 限定账户 id；null = 全部账户。
  final String? accountId;

  /// 限定分类（账户 category，复用 AccountCategory）；null = 全部分类。
  /// 值为 `AccountCategory.name` 串（下拉 value 口径），bloc 反查回枚举。
  final String? category;

  /// 限定月份（YYYY-MM）；null = 全部月份。
  final String? month;

  /// 限定标签 id（F8 FR-2,标签反查）;null = 全部标签。v1 单选(多标签组合
  /// 筛选 AND/OR 见 spec Scope boundary backlog)。
  final String? tagId;

  /// 描述模糊搜索词（F7 FR-2）；null = 不搜索。空串/空白由 DS 层容错为不过滤。
  final String? searchText;

  /// 排序键（F7 FR-3）：默认日期（= transactionDate）。
  final TxnSortKey sortKey;

  /// 排序方向（F7 FR-3）：默认降序（与既有默认序一致，NFR-1）。
  final TxnSortDir sortDir;

  bool get isDefault =>
      type == TxnTypeFilter.all &&
      accountId == null &&
      category == null &&
      month == null &&
      tagId == null &&
      (searchText == null || searchText!.isEmpty) &&
      sortKey == TxnSortKey.date &&
      sortDir == TxnSortDir.desc;

  TxnFilterState copyWith({
    TxnTypeFilter? type,
    Object? accountId = _sentinel,
    Object? category = _sentinel,
    Object? month = _sentinel,
    Object? tagId = _sentinel,
    Object? searchText = _sentinel,
    TxnSortKey? sortKey,
    TxnSortDir? sortDir,
  }) {
    return TxnFilterState(
      type: type ?? this.type,
      accountId: identical(accountId, _sentinel) ? this.accountId : accountId as String?,
      category: identical(category, _sentinel) ? this.category : category as String?,
      month: identical(month, _sentinel) ? this.month : month as String?,
      tagId: identical(tagId, _sentinel) ? this.tagId : tagId as String?,
      searchText: identical(searchText, _sentinel)
          ? this.searchText
          : searchText as String?,
      sortKey: sortKey ?? this.sortKey,
      sortDir: sortDir ?? this.sortDir,
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

/// 排序项文案(F7 FR-3):键(日期/金额)× 方向(降序/升序)四态。
String txnSortLabel(TxnSortKey key, TxnSortDir dir) =>
    '${key == TxnSortKey.date ? '日期' : '金额'}'
    '${dir == TxnSortDir.desc ? '降序' : '升序'}';

/// 搜索框(F7 FR-2):描述模糊搜索输入。
///
/// 两种提交形态(fix round 1):
/// - **提交制**([onCommit],列表筛选条用):onSubmitted(回车/完成键)与
///   suffix 清除钮才离散提交。逐键提交会导致每次输入触发整页
///   TransactionsLoading 替换、filter_bar 被卸载,输入焦点随之丢失 —— 故
///   改为提交制。
/// - **草稿制**([onChanged],mobile 筛选 sheet 用):逐键回调进草稿,sheet
///   本身不触发列表重载,无焦点问题。
///
/// 受控组件:[value] 为当前已提交的搜索词('' = 无)。[value] 被外部真正
/// 变更(如重置)时同步回输入框;无关重建(value 未变)不回写,避免清空
/// 未提交的输入缓冲。
class TxnSearchField extends StatefulWidget {
  const TxnSearchField({
    super.key,
    required this.value,
    this.onCommit,
    this.onChanged,
    this.hintText = '搜索描述…',
  });

  /// 当前提交值(空串 = 无搜索)。
  final String value;

  /// 提交回调:onSubmitted(回车/完成键)+ 清除钮。列表筛选条用。
  final ValueChanged<String>? onCommit;

  /// 逐键回调:草稿模式(mobile 筛选 sheet)用,不触发列表重载。
  final ValueChanged<String>? onChanged;

  final String hintText;

  @override
  State<TxnSearchField> createState() => _TxnSearchFieldState();
}

class _TxnSearchFieldState extends State<TxnSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant TxnSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 仅当外部真正变更提交值(如重置)时回写输入框;无关重建(value 未变,
    // 如其它筛选维度变化触发的父级刷新)不回写,保留未提交的输入缓冲。
    if (oldWidget.value != widget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear(); // clear() 不触发 onSubmitted/onChanged,需手动提交。
    widget.onCommit?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    return TextField(
      controller: _controller,
      // search 动作键(移动端「搜索」/桌面回车)→ onSubmitted 提交。
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon:
            Icon(LucideIcons.search, size: 16, color: context.yucai.muted),
        hintText: widget.hintText,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        suffixIcon: hasText
            ? IconButton(
                tooltip: '清除搜索',
                icon: Icon(LucideIcons.x, size: 15, color: context.yucai.muted),
                onPressed: _clear,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: context.yucai.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: context.yucai.border),
        ),
      ),
      // 提交制:回车/完成键离散提交(修复逐键提交的焦点丢失缺陷)。
      onSubmitted: widget.onCommit,
      // 草稿制:仅草稿模式(mobile sheet)接线,列表筛选条传 null。
      onChanged: widget.onChanged,
    );
  }
}

/// 排序控件(F7 FR-3):PopupMenu 四态(日期/金额 × 降序/升序),按钮显示当前态。
class TxnSortControl extends StatelessWidget {
  const TxnSortControl({
    super.key,
    required this.sortKey,
    required this.sortDir,
    required this.onChanged,
  });

  final TxnSortKey sortKey;
  final TxnSortDir sortDir;

  /// 点选后回传完整四态(键+方向一起提交,避免中间态触发两次重载)。
  final void Function(TxnSortKey key, TxnSortDir dir) onChanged;

  @override
  Widget build(BuildContext context) {
    final current = (sortKey, sortDir);
    // 四态固定项:date/desc(默认)· date/asc · amount/desc · amount/asc。
    const options = <(TxnSortKey, TxnSortDir)>[
      (TxnSortKey.date, TxnSortDir.desc),
      (TxnSortKey.date, TxnSortDir.asc),
      (TxnSortKey.amount, TxnSortDir.desc),
      (TxnSortKey.amount, TxnSortDir.asc),
    ];
    return PopupMenuButton<(TxnSortKey, TxnSortDir)>(
      tooltip: '排序',
      position: PopupMenuPosition.under,
      initialValue: current,
      onSelected: (v) => onChanged(v.$1, v.$2),
      constraints: const BoxConstraints(minWidth: 128),
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem(
            value: o,
            child: Text(txnSortLabel(o.$1, o.$2),
                style: TextStyle(
                    color: o == current
                        ? context.yucai.accent
                        : context.yucai.fg,
                    fontSize: 13,
                    fontWeight:
                        o == current ? FontWeight.w600 : FontWeight.w400)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: AppRadius.smBorder,
          border: Border.all(color: context.yucai.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.arrowUpDown,
                size: 14, color: context.yucai.muted),
            const SizedBox(width: 6),
            // 当前态文案(日期降序/日期升序/金额降序/金额升序)。
            Text(txnSortLabel(sortKey, sortDir),
                style:
                    TextStyle(color: context.yucai.fg, fontSize: 13)),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronDown, size: 13, color: context.yucai.muted),
          ],
        ),
      ),
    );
  }
}

/// F8 交付物 4(T1 review 观察 1):标签筛选控件可用性判定。
///
/// **boundRemote(在线绑定)态隐藏**:标签↔交易 junction(transaction_tags
/// 联表)是本地私有数据,不在备份/同步契约内;远端 ListTransactions /
/// TransactionSummary proto 亦无标签维度 —— 绑定在线态管道走远端,tagId 会被
/// **静默忽略**,UI 上「选了没反应」是必然结果。与其展示一个无效控件,不如
/// 隐藏(对用户诚实)。guest / boundOffline 走本地 drift 管道,标签过滤
/// 完整生效,正常展示。
///
/// tracker 未注册(无 DI 图的测试挂载)视同可用:tracker 的乐观默认即
/// guest(本地),与无 DI 环境语义一致(照 sync_status_badge 的 guarded getIt
/// 惯例,测试挂载静默降级而非崩)。
bool tagFilterAvailable() {
  final it = GetIt.instance;
  if (!it.isRegistered<SessionModeTracker>()) return true;
  return it<SessionModeTracker>().resolveDataRoute() != DataRoute.boundRemote;
}

/// 标签选项拉取(F8 FR-2/ADR-3):[TxnTagPicker] 使用。
///
/// RepositoryProvider 优先(测试注入),getIt 回退(生产);未注册/失败一律
/// 空选项(下拉退化为仅「全部标签」,不阻塞页面)。与 transactions_page
/// `_loadAccounts` 同模式。
Future<List<Tag>> _loadTagOptions(BuildContext context) async {
  TagRepository? repo;
  try {
    repo = RepositoryProvider.of<TagRepository>(context);
  } catch (_) {
    repo = null;
  }
  try {
    repo ??= GetIt.instance<TagRepository>();
  } catch (_) {}
  if (repo == null) return const [];
  try {
    final result = await repo.list();
    return result.fold((_) => const [], (list) => list);
  } catch (_) {
    return const [];
  }
}

/// 标签筛选下拉(F8 FR-2/ADR-3):选项 = TagRepository.list 实时,「全部标签」
/// 为清空态(value '' → onChanged(null),与账户/分类 [_Picker] 口径一致)。
///
/// 取数时机选 **initState 预取**(简于「下拉打开时取」:Dropdown 的 itemBuilder
/// 是同步回调,打开时取需另做异步弹出层;标签量级几十条(design Risks
/// 「TagRepository.list 轻量」),预取开销可忽略)。
///
/// boundRemote 态自隐藏(交付物 4,论证见 [tagFilterAvailable]);本控件也被
/// 报表页头部复用(F8 FR-4/ADR-5「同 ADR-3 控件复用」)。
class TxnTagPicker extends StatefulWidget {
  const TxnTagPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// 当前选中标签 id;null = 全部标签。
  final String? value;

  /// 选择回调;null = 选了「全部标签」(清空)。
  final ValueChanged<String?> onChanged;

  @override
  State<TxnTagPicker> createState() => _TxnTagPickerState();
}

class _TxnTagPickerState extends State<TxnTagPicker> {
  List<FilterOption> _options = const [];

  @override
  void initState() {
    super.initState();
    _fetchOptions();
  }

  Future<void> _fetchOptions() async {
    final tags = await _loadTagOptions(context);
    if (!mounted) return;
    setState(() {
      _options = [for (final t in tags) FilterOption(t.id, t.name)];
    });
  }

  @override
  Widget build(BuildContext context) {
    // boundRemote 隐藏(F8 交付物 4):论证见 tagFilterAvailable()。
    if (!tagFilterAvailable()) return const SizedBox.shrink();
    // value 暂不在选项中(异步预取未完成/标签已被删)时先显示清空态 ——
    // DropdownButton 断言「value 必须在 items 中」,直接透传会崩。
    final v = widget.value;
    final resolvable = v == null || _options.any((o) => o.value == v);
    return _Picker(
      label: '标签',
      value: resolvable ? v : null,
      options: _options,
      onChanged: widget.onChanged,
    );
  }
}

/// 交易列表筛选栏。
///
/// 组成：搜索框 + 类型分段（全部/收入/支出/转账，分段本体在 transactions_page
/// 渲染）+ 账户下拉 + 分类下拉 + 月份选择 + 标签下拉（F8 FR-2，boundRemote
/// 态隐藏）+ 排序控件 + 重置。
/// 回调形式：任何字段变化都通过 [onChanged] 整体回传新的 [TxnFilterState]。
/// 调用方负责把当前状态传回 [state]（受控组件）。
///
/// Mobile：垂直堆叠；Tablet：Wrap 换行铺开；Desktop：一行铺开。
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
  // F8 FR-2:标签反查(null = 全部标签,清空态)。
  void _setTag(String? id) => onChanged(state.copyWith(tagId: id));
  // 空串归 null:空输入不视为过滤(isDefault/copyWith 口径统一)。
  void _setSearch(String v) =>
      onChanged(state.copyWith(searchText: v.isEmpty ? null : v));
  void _setSort(TxnSortKey key, TxnSortDir dir) =>
      onChanged(state.copyWith(sortKey: key, sortDir: dir));
  void _reset() => onChanged(const TxnFilterState(type: TxnTypeFilter.all));

  @override
  Widget build(BuildContext context) {
    // 类型分段抽到独立 TxnTypeSeg(transactions_page 渲染),TxnFilterBar 只保留
    // 搜索/账户/分类/月份/标签 下拉 + 排序 + 重置。
    // 提交制(回车/清除才提交):逐键提交会触发整页 Loading 替换卸载本条,
    // 输入焦点丢失(fix round 1)。
    // 标签段(F8 FR-2)条件渲染:boundRemote 隐藏时连同间距一起省去,避免
    // 残留空白占位(可用性判定见 tagFilterAvailable,控件自身也兜底自隐藏)。
    final showTag = tagFilterAvailable();
    final searchField = TxnSearchField(
      value: state.searchText ?? '',
      onCommit: _setSearch,
    );
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
    final tagPicker = TxnTagPicker(
      value: state.tagId,
      onChanged: _setTag,
    );
    final sortControl = TxnSortControl(
      sortKey: state.sortKey,
      sortDir: state.sortDir,
      onChanged: _setSort,
    );
    final resetBtn = _ResetButton(onTap: _reset, enabled: !state.isDefault);

    return ResponsiveLayout(
      mobile: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: _boxDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            searchField,
            const SizedBox(height: AppSpacing.xs),
            accountPicker,
            const SizedBox(height: AppSpacing.xs),
            categoryPicker,
            const SizedBox(height: AppSpacing.xs),
            monthPicker,
            if (showTag) ...[
              const SizedBox(height: AppSpacing.xs),
              tagPicker,
            ],
            const SizedBox(height: AppSpacing.xs),
            sortControl,
            const SizedBox(height: AppSpacing.sm),
            Align(alignment: Alignment.centerRight, child: resetBtn),
          ],
        ),
      ),
      tablet: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: _boxDecoration(context),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(width: 220, child: searchField),
            accountPicker,
            categoryPicker,
            monthPicker,
            if (showTag) tagPicker,
            sortControl,
            resetBtn,
          ],
        ),
      ),
      desktop: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: _boxDecoration(context),
        child: Row(
          children: [
            // 搜索/下拉用 flex 而非固定宽度,避免在窄容器里溢出。
            Expanded(flex: 3, child: searchField),
            const SizedBox(width: AppSpacing.sm),
            Expanded(flex: 2, child: accountPicker),
            const SizedBox(width: AppSpacing.sm),
            Expanded(flex: 2, child: categoryPicker),
            const SizedBox(width: AppSpacing.sm),
            Expanded(flex: 2, child: monthPicker),
            if (showTag) ...[
              const SizedBox(width: AppSpacing.sm),
              Expanded(flex: 2, child: tagPicker),
            ],
            const SizedBox(width: AppSpacing.sm),
            sortControl,
            const SizedBox(width: AppSpacing.sm),
            resetBtn,
          ],
        ),
      ),
    );
  }

  /// 容器描边色随主题(R8 语义令牌)。
  BoxDecoration _boxDecoration(BuildContext context) => BoxDecoration(
        color: context.yucai.surface,
        borderRadius: AppRadius.smBorder,
        border: Border.all(color: context.yucai.border),
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
        border: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: context.yucai.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: context.yucai.border),
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
    final fg = enabled ? context.yucai.accent : context.yucai.muted;
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
              Icon(LucideIcons.refreshCw, size: 14, color: fg),
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
