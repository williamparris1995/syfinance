import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/yucai_menu.dart';
import 'package:yucai_client/transaction/presentation/bloc/category_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/category_event.dart';
import 'package:yucai_client/transaction/presentation/bloc/category_state.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';

/// 分类管理页 —— 对齐 OD 原型(yucai-category-management desktop/tablet/mobile)。
///
/// 分类 = 账户(account-as-category):支出/收入分类即 accountType 为
/// expense/income 的账户。
///
/// 布局(对齐 OD):
///   - desktop (≥1200):专属 topbar(crumb+h1+sub+导入模板+新建) + underline
///     tabs(count+hint) + 2-col workspace(LIST panel 55fr + EDITOR panel 45fr)
///   - tablet  (600–1200):topbar + underline tabs + LIST panel + 右侧 EDITOR 抽屉
///   - mobile  (≤600):紧凑 topbar + summary card + segmented tabs + 卡片列表 +
///     底部 EDITOR sheet
///
/// shell topbar 已在 app_shell 对 /categories 隐藏(见 _isCategoryManagement),
/// 本页渲染专属 OD topbar。CategoryBloc / account use-case 接口不变,仅改 UI。
class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  /// 测试钩子。
  static Key rowKey(String id) => ValueKey('category_row_$id');
  static const Key editPanelKey = ValueKey('category_edit_panel');
  static const Key editorDeleteKey = ValueKey('category_editor_delete');
  static const Key newCategoryKey = ValueKey('category_new');
  static const Key saveKey = ValueKey('category_save');

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  CategoryType _type = CategoryType.expense;
  /// null = 新建模式(空表单);非空 = 编辑该分类。desktop 右栏常驻。
  CategoryItem? _editing;

  @override
  void initState() {
    super.initState();
    context.read<CategoryBloc>().add(LoadCategoriesRequested(_type));
  }

  void _switchType(CategoryType t) {
    if (t == _type) return;
    setState(() {
      _type = t;
      _editing = null;
    });
    context.read<CategoryBloc>().add(LoadCategoriesRequested(t));
  }

  /// 选择行进入编辑(directly updates _editing; tablet/mobile opens surface)。
  void _selectRow(CategoryItem item) {
    setState(() => _editing = item);
    final bp = Breakpoints.of(context);
    if (bp == Breakpoint.mobile) {
      _showEditorSheet(item);
    } else if (bp == Breakpoint.tablet) {
      _scaffoldKey.currentState?.openEndDrawer();
    }
    // desktop: panel always visible; _editing drives content.
  }

  /// 新建分类:清空 _editing 进入新建模式 + 打开编辑面(tablet/mobile)。
  void _openNew() {
    setState(() => _editing = null);
    final bp = Breakpoints.of(context);
    if (bp == Breakpoint.mobile) {
      _showEditorSheet(null);
    } else if (bp == Breakpoint.tablet) {
      _scaffoldKey.currentState?.openEndDrawer();
    }
    _toast('已进入新建模式，请填写信息');
  }

  void _showEditorSheet(CategoryItem? item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.yucai.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => BlocProvider<CategoryBloc>.value(
        value: context.read<CategoryBloc>(),
        child: BlocBuilder<CategoryBloc, CategoryState>(
          buildWhen: (_, c) => c is! CategorySubmitting,
          builder: (ctx, st) {
            final all = _itemsOf(st);
            final idx = item == null
                ? -1
                : all.indexWhere((c) => c.id == item.id);
            return _EditorPanel(
              key: CategoryManagementPage.editPanelKey,
              type: _type,
              item: item,
              itemIndex: idx,
              candidates: _parentCandidates(st, item?.id),
              onSave: _dispatchSave,
              onDelete: _dispatchDelete,
              onClose: () => Navigator.of(ctx).maybePop(),
            );
          },
        ),
      ),
    );
  }

  void _dispatchSave(String name, String icon, String color, String parentId) {
    final e = _editing;
    context.read<CategoryBloc>().add(SaveCategoryRequested(
          type: _type,
          name: name,
          id: e?.id ?? '',
          version: e?.version ?? 0,
          icon: icon,
          color: color,
          parentId: parentId,
        ));
    Navigator.of(context).maybePop();
  }

  void _dispatchDelete() {
    final e = _editing;
    if (e == null) return;
    context.read<CategoryBloc>().add(DeleteCategoryRequested(e.id));
    setState(() => _editing = null);
    Navigator.of(context).maybePop();
  }

  void _exportHint() => _toast('导入模板 · 预置分类模板即将就绪');

  void _toast(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bp = Breakpoints.of(context);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.yucai.bg,
      endDrawer: bp == Breakpoint.tablet ? _EditorDrawer(state: this) : null,
      body: Column(
        children: [
          _PageTopBar(
            compact: bp == Breakpoint.mobile,
            onNew: _openNew,
            onExport: _exportHint,
          ),
          Expanded(
            child: ResponsiveLayout(
              mobile: _MobileBody(state: this),
              tablet: _TabletBody(state: this),
              desktop: _DesktopBody(state: this),
            ),
          ),
        ],
      ),
    );
  }

  List<CategoryItem> _itemsOf(CategoryState state) {
    final raw = state is CategoryLoaded
        ? state.categories
        : state is CategoryLoading
            ? state.categories
            : state is CategorySubmitting
                ? state.categories
                : state is CategoryError
                    ? state.categories
                    : const <CategoryItem>[];
    // 层级排序:父分类 + 其子分类紧跟(对齐 OD cat-row 顺序)
    if (raw.isEmpty) return raw;
    final tops = raw.where((c) => c.parentId.isEmpty).toList();
    final subs = raw.where((c) => c.parentId.isNotEmpty).toList();
    final result = <CategoryItem>[];
    for (final t in tops) {
      result.add(t);
      result.addAll(subs.where((s) => s.parentId == t.id));
    }
    // 孤儿子分类(父不在当前列表)追加末尾
    result.addAll(subs.where((s) => !tops.any((t) => t.id == s.parentId)));
    return result;
  }

  /// tabs count:从 CategoryLoaded 的全量计数取(非当前 type tab 也显正确数);
  /// loading/submitting/error 退化为当前 type 的 items.length(旧行为)。
  int _countOf(CategoryState s, CategoryType type) {
    if (s is CategoryLoaded) {
      return type == CategoryType.expense ? s.expenseCount : s.incomeCount;
    }
    final items = _itemsOf(s);
    return _type == type ? items.length : 0;
  }

  /// 父分类候选:同 type 顶级分类(无 parentId),排除当前编辑项。
  /// 系统预置(餐饮/交通 等)可作父级(OD:咖啡/外卖 归属餐饮)。深度限 2 级。
  List<CategoryItem> _parentCandidates(CategoryState state, String? selfId) {
    final items = _itemsOf(state);
    return items
        .where((c) => c.parentId.isEmpty && c.id != selfId)
        .toList();
  }
}

// ───────────────────────── topbar ─────────────────────────

/// OD topbar:crumb + h1(serif)+ sub + 导入模板(btn-ghost)+ 新建分类(btn-primary)。
/// mobile 紧凑:隐藏 sub 与导入模板。
class _PageTopBar extends StatelessWidget {
  const _PageTopBar({
    required this.compact,
    required this.onNew,
    required this.onExport,
  });

  final bool compact;
  final VoidCallback onNew;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? AppSpacing.md : AppSpacing.lg,
        AppSpacing.md,
        compact ? AppSpacing.md : AppSpacing.lg,
        AppSpacing.sm + 4,
      ),
      decoration: BoxDecoration(
        color: context.yucai.bg,
        border: Border(bottom: BorderSide(color: context.yucai.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // crumb:交易 › 分类管理(对齐 app sidebar 分组)。
          Row(children: [
            Text('交易',
                style: TextStyle(fontSize: 12, color: context.yucai.muted)),
            const SizedBox(width: 6),
            Icon(LucideIcons.chevronRight, size: 12, color: context.yucai.muted),
            const SizedBox(width: 6),
            Text('分类管理',
                style: TextStyle(fontSize: 12, color: context.yucai.fg)),
          ]),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('分类管理',
                        style: TextStyle(
                          fontSize: compact ? 20 : 26,
                          fontWeight: FontWeight.w700,
                          color: context.yucai.fg,
                          fontFamily: AppTypography.displayFamily,
                          fontFamilyFallback: AppTypography.displayFallback,
                        )),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        '管理收支分类账户 · 方案 A 分类即账户，每个分类对应一个累计余额的 Expense / Income 账户',
                        style: TextStyle(fontSize: 12.5, color: context.yucai.muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (!compact) ...[
                _GhostButton(
                  icon: LucideIcons.download,
                  label: '导入模板',
                  onTap: onExport,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              _PrimaryButton(
                key: CategoryManagementPage.newCategoryKey,
                icon: LucideIcons.plus,
                label: compact ? '新建' : '新建分类',
                onTap: onNew,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: context.yucai.accent,
            borderRadius: AppRadius.smBorder,
            boxShadow: const [
              BoxShadow(
                color: Color(0x33B08D57),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: context.yucai.surface,
            border: Border.all(color: context.yucai.border),
            borderRadius: AppRadius.smBorder,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: context.yucai.fg),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: context.yucai.fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── tabs ─────────────────────────

/// desktop/tablet underline tabs:支出分类 [n] / 收入分类 [n] + hint(右)。
class _UnderlineTabs extends StatelessWidget {
  const _UnderlineTabs({
    required this.type,
    required this.expenseCount,
    required this.incomeCount,
    required this.onChanged,
  });
  final CategoryType type;
  final int expenseCount;
  final int incomeCount;
  final ValueChanged<CategoryType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: Row(
        children: [
          _UnderlineTab(
            label: '支出分类',
            count: expenseCount,
            selected: type == CategoryType.expense,
            onTap: () => onChanged(CategoryType.expense),
          ),
          const SizedBox(width: AppSpacing.sm),
          _UnderlineTab(
            label: '收入分类',
            count: incomeCount,
            selected: type == CategoryType.income,
            onTap: () => onChanged(CategoryType.income),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('本月金额 = 该账户当月余额 · 拖动 ⠿ 可排序',
                  style: TextStyle(fontSize: 11.5, color: context.yucai.muted)),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnderlineTab extends StatelessWidget {
  const _UnderlineTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
              child: Row(children: [
                Text(label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? context.yucai.fg : context.yucai.muted,
                    )),
                const SizedBox(width: 6),
                Text('$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: AppTypography.displayFamily,
                      color: selected ? context.yucai.accent : context.yucai.muted,
                    )),
              ]),
            ),
            Container(
              height: 2,
              width: 36,
              decoration: BoxDecoration(
                color: selected ? context.yucai.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// mobile segmented tabs(OD mobile .seg)。
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.type,
    required this.expenseCount,
    required this.incomeCount,
    required this.onChanged,
  });
  final CategoryType type;
  final int expenseCount;
  final int incomeCount;
  final ValueChanged<CategoryType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.yucai.surfaceAlt,
        borderRadius: AppRadius.smBorder,
      ),
      child: Row(children: [
        _SegItem(
          label: '支出',
          count: expenseCount,
          selected: type == CategoryType.expense,
          onTap: () => onChanged(CategoryType.expense),
        ),
        _SegItem(
          label: '收入',
          count: incomeCount,
          selected: type == CategoryType.income,
          onTap: () => onChanged(CategoryType.income),
        ),
      ]),
    );
  }
}

class _SegItem extends StatelessWidget {
  const _SegItem({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? context.yucai.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: selected
                  ? const [BoxShadow(color: Color(0x14000000), blurRadius: 2)]
                  : null,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? context.yucai.fg : context.yucai.muted,
                  )),
              const SizedBox(width: 4),
              Text('$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: AppTypography.displayFamily,
                    color: selected ? context.yucai.accent : context.yucai.muted,
                  )),
            ]),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── desktop body ─────────────────────────

class _DesktopBody extends StatelessWidget {
  const _DesktopBody({required this.state});
  final _CategoryManagementPageState state;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoryBloc, CategoryState>(
      buildWhen: (p, c) => c is! CategorySubmitting,
      builder: (context, bState) {
        final items = state._itemsOf(bState);
        final loading = bState is CategoryLoading;
        return Column(
          children: [
            _UnderlineTabs(
              type: state._type,
              expenseCount: state._countOf(bState, CategoryType.expense),
              incomeCount: state._countOf(bState, CategoryType.income),
              onChanged: state._switchType,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      flex: 55,
                      child: _ListPanel(
                        state: state,
                        type: state._type,
                        items: items,
                        loading: loading,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 45,
                      child: BlocBuilder<CategoryBloc, CategoryState>(
                        buildWhen: (_, c) => c is! CategorySubmitting,
                        builder: (ctx, s) {
                          final all = state._itemsOf(s);
                          final idx = state._editing == null
                              ? -1
                              : all.indexWhere((c) => c.id == state._editing!.id);
                          return _EditorPanel(
                            key: CategoryManagementPage.editPanelKey,
                            type: state._type,
                            item: state._editing,
                            itemIndex: idx,
                            candidates: state._parentCandidates(s, state._editing?.id),
                            onSave: state._dispatchSave,
                            onDelete: state._dispatchDelete,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ───────────────────────── tablet body ─────────────────────────

class _TabletBody extends StatelessWidget {
  const _TabletBody({required this.state});
  final _CategoryManagementPageState state;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoryBloc, CategoryState>(
      buildWhen: (p, c) => c is! CategorySubmitting,
      builder: (context, bState) {
        final items = state._itemsOf(bState);
        final loading = bState is CategoryLoading;
        return Column(
          children: [
            _UnderlineTabs(
              type: state._type,
              expenseCount: state._countOf(bState, CategoryType.expense),
              incomeCount: state._countOf(bState, CategoryType.income),
              onChanged: state._switchType,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                child: _ListPanel(
                  state: state,
                  type: state._type,
                  items: items,
                  loading: loading,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ───────────────────────── mobile body ─────────────────────────

class _MobileBody extends StatelessWidget {
  const _MobileBody({required this.state});
  final _CategoryManagementPageState state;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoryBloc, CategoryState>(
      buildWhen: (p, c) => c is! CategorySubmitting,
      builder: (context, bState) {
        final items = state._itemsOf(bState);
        final total = items.fold<int>(0, (s, c) => s + c.monthlyAmountCents);
        return Column(
          children: [
            _SegmentedTabs(
              type: state._type,
              expenseCount: state._countOf(bState, CategoryType.expense),
              incomeCount: state._countOf(bState, CategoryType.income),
              onChanged: state._switchType,
            ),
            _MobileSummaryCard(
              type: state._type,
              total: total,
              count: items.length,
            ),
            Expanded(
              child: items.isEmpty && bState is! CategoryLoading
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text('暂无分类，点击右上角「新建」',
                            style: TextStyle(color: context.yucai.muted)),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.lg),
                      children: [
                        for (final it in items)
                          _CatCard(
                            key: CategoryManagementPage.rowKey(it.id),
                            item: it,
                            parentName: _parentNameOf(items, it),
                            onTap: () => state._selectRow(it),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// mobile summary card(OD mobile .summary):大金额 + 元信息。
class _MobileSummaryCard extends StatelessWidget {
  const _MobileSummaryCard({
    required this.type,
    required this.total,
    required this.count,
  });
  final CategoryType type;
  final int total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final isExpense = type == CategoryType.expense;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      padding: const EdgeInsets.all(AppSpacing.md - 4),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        border: Border.all(color: context.yucai.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本月${isExpense ? '支出' : '收入'}',
              style: TextStyle(fontSize: 12, color: context.yucai.muted)),
          const SizedBox(height: 3),
          Text(_fmtMoney(total),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                fontFamily: AppTypography.displayFamily,
                color: isExpense ? context.yucai.negative : context.yucai.positive,
              )),
          const SizedBox(height: 4),
          Text('分类即账户 · $count 个账户累计中',
              style: TextStyle(fontSize: 11, color: context.yucai.muted)),
        ],
      ),
    );
  }
}

// ───────────────────────── LIST panel ─────────────────────────

/// desktop/tablet LIST panel:panel-head(h2+sub+period)+ summary band + 列表。
class _ListPanel extends StatelessWidget {
  const _ListPanel({
    required this.state,
    required this.type,
    required this.items,
    required this.loading,
  });
  final _CategoryManagementPageState state;
  final CategoryType type;
  final List<CategoryItem> items;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isExpense = type == CategoryType.expense;
    final total = items.fold<int>(0, (s, c) => s + c.monthlyAmountCents);
    final now = DateTime.now();
    final period = '${now.year}·${now.month.toString().padLeft(2, '0')}';
    return Container(
      decoration: BoxDecoration(
        color: context.yucai.surface,
        border: Border.all(color: context.yucai.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Column(
        children: [
          // panel-head
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm + 2, AppSpacing.md, AppSpacing.sm + 2),
            child: Row(children: [
              Text(type == CategoryType.expense ? '支出分类' : '收入分类',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTypography.displayFamily,
                    color: context.yucai.fg,
                  )),
              const SizedBox(width: 8),
              Text('${items.length} 个分类账户',
                  style: TextStyle(fontSize: 12, color: context.yucai.muted)),
              const Spacer(),
              Text(period,
                  style: TextStyle(
                      fontSize: 12,
                      fontFamily: AppTypography.displayFamily,
                      color: context.yucai.muted)),
            ]),
          ),
          Divider(height: 1, color: context.yucai.border),
          // summary band(gold-soft)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            color: context.yucai.accentSoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('本月${isExpense ? '支出' : '收入'}合计',
                    style: TextStyle(fontSize: 12, color: context.yucai.muted)),
                const SizedBox(width: AppSpacing.sm),
                Text(_fmtMoney(total),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFamily: AppTypography.displayFamily,
                      color: isExpense ? context.yucai.negative : context.yucai.positive,
                    )),
                const Spacer(),
                Text('分类即账户 · 累计中',
                    style: TextStyle(fontSize: 11, color: context.yucai.muted)),
              ],
            ),
          ),
          Divider(height: 1, color: context.yucai.border),
          // list
          Expanded(
            child: loading && items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Text('暂无分类，点击「新建分类」',
                              style: TextStyle(color: context.yucai.muted)),
                        ),
                      )
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: items.length,
                        onReorderItem: (o, n) {
                          context.read<CategoryBloc>().add(
                              ReorderCategoriesRequested(
                                  oldIndex: o, newIndex: n));
                        },
                        itemBuilder: (ctx, i) => _CatRow(
                          key: CategoryManagementPage.rowKey(items[i].id),
                          item: items[i],
                          selected: state._editing?.id == items[i].id,
                          isSub: items[i].parentId.isNotEmpty,
                          parentName: _parentNameOf(items, items[i]),
                          onTap: () => state._selectRow(items[i]),
                          onEdit: () => state._selectRow(items[i]),
                          onDelete: () => _confirmDelete(ctx, items[i]),
                          dragHandleBuilder: (c) => ReorderableDragStartListener(
                            index: i,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 2),
                              child: Icon(LucideIcons.gripVertical,
                                  size: 16, color: context.yucai.muted),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, CategoryItem item) {
    if (item.isSystem) return;
    showDialog<void>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定删除「${item.name}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            onPressed: () {
              Navigator.pop(d);
              ctx.read<CategoryBloc>().add(DeleteCategoryRequested(item.id));
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// desktop/tablet cat-row:drag ⠿ + emoji circle(color bg)+ name + chip +
/// sub(父分类)+ amt(本月)+ ⋯ menu。sel 态:gold left border + cream bg。
class _CatRow extends StatelessWidget {
  const _CatRow({
    super.key,
    required this.item,
    required this.selected,
    required this.isSub,
    required this.parentName,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.dragHandleBuilder,
  });

  final CategoryItem item;
  final bool selected;
  final bool isSub;
  final String parentName;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final WidgetBuilder dragHandleBuilder;

  @override
  Widget build(BuildContext context) {
    final isExpense = item.type == CategoryType.expense;
    final amtColor = isExpense ? context.yucai.negative : context.yucai.positive;
    return Material(
      color: selected ? context.yucai.accentSoft : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? context.yucai.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: EdgeInsets.only(
            left: isSub ? AppSpacing.md : AppSpacing.sm,
            right: AppSpacing.md,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 10, horizontal: AppSpacing.xs),
            child: Row(
              children: [
                // drag handle(嵌套 ReorderableDragStartListener)
                dragHandleBuilder(context),
                const SizedBox(width: AppSpacing.xs),
                // sub 缩进 + left divider(对齐 OD .cat-row.sub dashed left)
                if (isSub)
                  Container(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: context.yucai.border),
                      ),
                    ),
                    child: _EmojiCircle(icon: item.icon, color: item.color, size: 32),
                  )
                else
                  _EmojiCircle(icon: item.icon, color: item.color, size: 38),
                const SizedBox(width: AppSpacing.sm),
                // meta: name + chip + sub
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(item.name,
                              style: TextStyle(
                                fontSize: isSub ? 13 : 14,
                                fontWeight: FontWeight.w600,
                                color: context.yucai.fg,
                              ),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        _SysChip(system: item.isSystem),
                      ]),
                      if (isSub && parentName.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text('归属 $parentName · 二级分类',
                            style: TextStyle(
                                fontSize: 11.5, color: context.yucai.muted)),
                      ],
                    ],
                  ),
                ),
                // amt
                Text(
                  item.monthlyAmountReady
                      ? _fmtMoney(item.monthlyAmountCents)
                      : '待统计',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppTypography.displayFamily,
                    color: item.monthlyAmountReady ? amtColor : context.yucai.muted,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                // ⋯ context menu
                // MenuAnchor 锚定按钮本体(拖拽排序行内 PopupMenuButton
                // 的全局坐标计算会偏,F5 起统一锚定菜单)。
                MenuAnchor(
                  style: yucaiMenuStyle(context),
                                    menuChildren: [
                    MenuItemButton(
                      leadingIcon: Icon(LucideIcons.pencil,
                          size: 15, color: context.yucai.muted),
                      child: const Text('编辑'),
                      onPressed: onEdit,
                    ),
                    MenuItemButton(
                      leadingIcon: Icon(LucideIcons.trash2,
                          size: 15,
                          color: item.isSystem
                              ? context.yucai.muted
                              : context.yucai.negative),
                      child: Text(item.isSystem ? '删除（系统禁用）' : '删除分类',
                          style: TextStyle(
                              color: item.isSystem
                                  ? context.yucai.muted
                                  : context.yucai.negative)),
                      onPressed: item.isSystem ? null : onDelete,
                    ),
                  ],
                  builder: (menuContext, controller, child) => IconButton(
                    tooltip: '操作',
                    icon: Icon(LucideIcons.moreHorizontal,
                        size: 18, color: context.yucai.muted),
                    onPressed: () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// mobile cat-card(OD mobile .card):emoji + name + chip + sub + amt + chev。
class _CatCard extends StatelessWidget {
  const _CatCard({
    super.key,
    required this.item,
    required this.parentName,
    required this.onTap,
  });
  final CategoryItem item;
  final String parentName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isExpense = item.type == CategoryType.expense;
    final amtColor = isExpense ? context.yucai.negative : context.yucai.positive;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: context.yucai.surface,
            border: Border.all(color: context.yucai.border),
            borderRadius: AppRadius.lgBorder,
          ),
          child: Row(
            children: [
              _EmojiCircle(icon: item.icon, color: item.color, size: 42),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(item.name,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.yucai.fg),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      _SysChip(system: item.isSystem),
                    ]),
                    if (item.parentId.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text('归属 $parentName',
                            style: TextStyle(
                                fontSize: 11.5, color: context.yucai.muted)),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.monthlyAmountReady
                        ? _fmtMoney(item.monthlyAmountCents)
                        : '待统计',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTypography.displayFamily,
                      color: item.monthlyAmountReady ? amtColor : context.yucai.muted,
                    ),
                  ),
                  Text('本月${isExpense ? '支出' : '收入'}',
                      style: TextStyle(fontSize: 10, color: context.yucai.muted)),
                ],
              ),
              const SizedBox(width: 2),
              Icon(LucideIcons.chevronRight, size: 18, color: context.yucai.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── shared bits ─────────────────────────

/// emoji circle:color bg(15%)+ inset border(22%)+ emoji(或兜底 tag 图标)。
class _EmojiCircle extends StatelessWidget {
  const _EmojiCircle({
    required this.icon,
    required this.color,
    required this.size,
  });
  final String icon;
  final String color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = _colorOf(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: c.withValues(alpha: 0.22), width: 1),
      ),
      alignment: Alignment.center,
      child: _iconContent(icon, color, size * 0.55),
    );
  }
}

class _SysChip extends StatelessWidget {
  const _SysChip({required this.system});
  final bool system;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: system ? context.yucai.accentSoft : context.yucai.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(system ? '系统' : '自建',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: system ? context.yucai.accentDeep : context.yucai.muted,
          )),
    );
  }
}

// ───────────────────────── EDITOR ─────────────────────────

/// tablet endDrawer 包装:drawer-head(close)+ _EditorPanel。
class _EditorDrawer extends StatelessWidget {
  const _EditorDrawer({required this.state});
  final _CategoryManagementPageState state;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 400,
      backgroundColor: context.yucai.surface,
      child: BlocBuilder<CategoryBloc, CategoryState>(
        buildWhen: (_, c) => c is! CategorySubmitting,
        builder: (ctx, s) {
          final all = state._itemsOf(s);
          final idx = state._editing == null
              ? -1
              : all.indexWhere((c) => c.id == state._editing!.id);
          return _EditorPanel(
            key: CategoryManagementPage.editPanelKey,
            type: state._type,
            item: state._editing,
            itemIndex: idx,
            candidates: state._parentCandidates(s, state._editing?.id),
            onSave: state._dispatchSave,
            onDelete: state._dispatchDelete,
            onClose: () => Navigator.of(ctx).maybePop(),
          );
        },
      ),
    );
  }
}

/// 编辑面板:panel-head(h2 编辑/新建 + sub)+ edit-body(preview + fields +
/// sys-note)+ edit-foot(删除/saved/保存)。preview 实时随 name/icon/color 变。
class _EditorPanel extends StatefulWidget {
  const _EditorPanel({
    super.key,
    required this.type,
    required this.item,
    required this.candidates,
    required this.onSave,
    required this.onDelete,
    this.onClose,
    this.itemIndex = -1,
  });

  final CategoryType type;
  final CategoryItem? item; // null = 新建
  final List<CategoryItem> candidates;
  final void Function(String name, String icon, String color, String parentId) onSave;
  final VoidCallback onDelete;
  final VoidCallback? onClose; // drawer/sheet 关闭
  /// 当前项在列表中的位序(0-based,-1 = 新建/未知),仅用于排序字段展示。
  final int itemIndex;

  @override
  State<_EditorPanel> createState() => _EditorPanelState();
}

/// OD desktop 40 个预设 emoji(餐饮/交通/购物/娱乐/居家/医疗/工资/理财...)。
const _presetIcons = <String>[
  '🥢', '🍔', '🍜', '🍱', '☕', '🍰', '🧋', '🚌',
  '🚗', '✈️', '🚕', '🚲', '🛍️', '👕', '💄', '👟',
  '🎮', '🎬', '🎵', '📷', '🏠', '🛋️', '💡', '🔧',
  '💊', '🏥', '🧴', '🦷', '💰', '💼', '📈', '🧧',
  '🎁', '🏦', '📱', '⚡', '📚', '🐾', '🎓', '🏷️',
];

/// OD 色板(御财金 + 常用色,hex 大写存 account.color)。
const _presetColors = <String>[
  '#D97548', '#4A7FC4', '#C4548A', '#8B5CF6',
  '#5B9279', '#3D8B9B', '#B08D57', '#2D8A6E',
  '#C4544D', '#D4A44A', '#6B7280', '#8A5A3B',
];

class _EditorPanelState extends State<_EditorPanel> {
  final _nameCtrl = TextEditingController();
  String _name = '';
  String _icon = _presetIcons.first;
  String _color = _presetColors.first;
  String _parentId = '';
  bool _saved = false;
  Timer? _savedTimer;

  @override
  void initState() {
    super.initState();
    _hydrate(widget.item);
  }

  void _hydrate(CategoryItem? item) {
    if (item != null) {
      _nameCtrl.text = item.name;
      _name = item.name;
      _icon = item.icon.isEmpty ? _presetIcons.first : item.icon;
      _color = item.color.isEmpty ? _presetColors.first : item.color;
      _parentId = item.parentId;
    } else {
      _nameCtrl.clear();
      _name = '';
      _icon = _presetIcons.first;
      _color = _presetColors.first;
      _parentId = '';
    }
  }

  @override
  void didUpdateWidget(covariant _EditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item?.id != widget.item?.id) {
      _hydrate(widget.item);
    }
  }

  @override
  void dispose() {
    _savedTimer?.cancel();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _flashSaved() {
    setState(() => _saved = true);
    _savedTimer?.cancel();
    _savedTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  void _onSave() {
    widget.onSave(
      _nameCtrl.text.trim().isEmpty ? '未命名' : _nameCtrl.text.trim(),
      _icon,
      _color,
      _parentId,
    );
    _flashSaved();
  }

  void _onDelete() {
    if (widget.item == null || widget.item!.isSystem) return;
    showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定删除「${widget.item!.name}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.yucai.negative),
            onPressed: () {
              Navigator.pop(d);
              widget.onDelete();
            },
            child: const Text('删除')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final isSystem = widget.item?.isSystem ?? false;
    final isExpense = widget.type == CategoryType.expense;
    return Container(
      color: context.yucai.surface,
      child: Column(
        children: [
          // panel-head
          Container(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm + 2, AppSpacing.sm, AppSpacing.sm + 2),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.yucai.border)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEdit ? '编辑分类' : '新建分类',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: AppTypography.displayFamily,
                          color: context.yucai.fg,
                        )),
                    const SizedBox(height: 1),
                    Text('${widget.type.label}账户',
                        style: TextStyle(
                            fontSize: 12, color: context.yucai.muted)),
                  ],
                ),
              ),
              if (widget.onClose != null)
                IconButton(
                  tooltip: '关闭',
                  icon: Icon(LucideIcons.x, size: 18, color: context.yucai.muted),
                  onPressed: widget.onClose,
                ),
            ]),
          ),
          // edit-body(SingleChildScrollView 全量构建子项,避免 ListView 懒加载
          // 导致 icon/color 选择器在测试与离屏时不在树中)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // preview(实时)
                _Preview(
                  name: _name.isEmpty ? '未命名' : _name,
                  icon: _icon,
                  color: _color,
                  typeLabel: widget.type.label,
                  isSystem: isSystem,
                ),
                const SizedBox(height: AppSpacing.md),
                // 分类名称
                _Field(
                  label: '分类名称',
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      hintText: '输入分类名称',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _name = v),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                // 类型(只读 seg)
                _Field(
                  label: '类型',
                  hint: '由顶部标签页决定',
                  child: _SegReadonly(
                    labels: const ['支出分类', '收入分类'],
                    activeIndex: isExpense ? 0 : 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                // 图标 grid
                _Field(
                  label: '图标',
                  child: _IconGrid(
                    value: _icon,
                    onChanged: (v) => setState(() => _icon = v),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                // 颜色
                _Field(
                  label: '颜色',
                  child: _ColorRow(
                    value: _color,
                    onChanged: (v) => setState(() => _color = v),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                // 父分类
                _Field(
                  label: '父分类',
                  hint: '支持两级层级，留空即顶级',
                  child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _parentId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('无（顶级分类）'),
                      ),
                      ...widget.candidates.map(
                        (c) => DropdownMenuItem<String>(
                          value: c.id,
                          child: Row(children: [
                            _EmojiCircle(icon: c.icon, color: c.color, size: 20),
                            const SizedBox(width: 8),
                            Text(c.name),
                          ]),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _parentId = v ?? ''),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                // 排序(展示当前位序;实际排序由拖拽持久化)
                _Field(
                  label: '排序',
                  hint: '拖拽列表项调整',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.yucai.surfaceAlt,
                      border: Border.all(color: context.yucai.border),
                      borderRadius: AppRadius.smBorder,
                    ),
                    child: Text(
                      widget.itemIndex < 0
                          ? '—'
                          : '第 ${widget.itemIndex + 1} 位',
                      style: TextStyle(
                          fontSize: 14, color: context.yucai.muted),
                    ),
                  ),
                ),
                if (isSystem) ...[
                  const SizedBox(height: AppSpacing.sm + 2),
                  const _SysNote(),
                ],
              ],
            ),
          ),
          ),
          // edit-foot
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: context.yucai.surfaceAlt,
              border: Border(top: BorderSide(color: context.yucai.border)),
            ),
            child: Row(children: [
              _DeleteButton(
                key: CategoryManagementPage.editorDeleteKey,
                disabled: !isEdit || isSystem,
                isSystem: isSystem,
                onTap: _onDelete,
              ),
              const Spacer(),
              if (_saved)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.check, size: 14, color: context.yucai.positive),
                  SizedBox(width: 4),
                  Text('已保存',
                      style: TextStyle(fontSize: 12, color: context.yucai.positive)),
                ]),
              const SizedBox(width: AppSpacing.sm),
              _PrimaryButton(
                key: CategoryManagementPage.saveKey,
                icon: LucideIcons.check,
                label: '保存',
                onTap: _onSave,
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

/// preview:big emoji circle + name(serif)+ type dot + 系统预置/自建。
/// 实时随 name/icon/color 变(setState 驱动 rebuild)。
class _Preview extends StatelessWidget {
  const _Preview({
    required this.name,
    required this.icon,
    required this.color,
    required this.typeLabel,
    required this.isSystem,
  });
  final String name;
  final String icon;
  final String color;
  final String typeLabel;
  final bool isSystem;

  @override
  Widget build(BuildContext context) {
    final c = _colorOf(color);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: context.yucai.bg,
        border: Border.all(color: context.yucai.border),
        borderRadius: AppRadius.smBorder,
      ),
      child: Row(children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.16),
            shape: BoxShape.circle,
            border: Border.all(color: c.withValues(alpha: 0.24), width: 1),
          ),
          alignment: Alignment.center,
          child: _iconContent(icon, color, 26),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTypography.displayFamily,
                    color: context.yucai.fg,
                  ),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text('$typeLabel · ${isSystem ? '系统预置' : '自建分类'}',
                    style: TextStyle(
                        fontSize: 11.5, color: context.yucai.muted)),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.hint});
  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: context.yucai.muted)),
          if (hint != null) ...[
            const SizedBox(width: 6),
            Text(hint!,
                style: TextStyle(fontSize: 12, color: context.yucai.muted)),
          ],
        ]),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// 类型只读分段(OD .seg-readonly):active 金色下划线。
class _SegReadonly extends StatelessWidget {
  const _SegReadonly({required this.labels, required this.activeIndex});
  final List<String> labels;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.yucai.border),
        borderRadius: AppRadius.smBorder,
        color: context.yucai.surfaceAlt,
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == activeIndex ? context.yucai.surface : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: i == activeIndex
                          ? context.yucai.accent
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(labels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: i == activeIndex ? FontWeight.w600 : FontWeight.w400,
                      color: i == activeIndex ? context.yucai.fg : context.yucai.muted,
                    )),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 图标网格(OD .icon-grid 8 列 → Flutter Wrap 自适应)。
class _IconGrid extends StatelessWidget {
  const _IconGrid({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in _presetIcons)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              key: ValueKey('icon_pick_$e'),
              onTap: () => onChanged(e),
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: e == value ? context.yucai.accentSoft : context.yucai.surface,
                  border: Border.all(
                    color: e == value ? context.yucai.accent : context.yucai.border,
                    width: e == value ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(e, style: const TextStyle(fontSize: 18)),
              ),
            ),
          ),
      ],
    );
  }
}

/// 颜色色板(OD .color-row 圆形)。
class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        for (final hex in _presetColors)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              key: ValueKey('color_pick_$hex'),
              onTap: () => onChanged(hex),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _colorOf(hex),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isSelected(hex, value)
                        ? _colorOf(hex)
                        : context.yucai.border,
                    width: _isSelected(hex, value) ? 3 : 1,
                  ),
                  boxShadow: _isSelected(hex, value)
                      ? [
                          BoxShadow(
                            color: _colorOf(hex).withValues(alpha: 0.35),
                            blurRadius: 0,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: _isSelected(hex, value)
                    ? const Icon(LucideIcons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  bool _isSelected(String hex, String value) =>
      hex.toUpperCase() == value.toUpperCase();
}

/// 系统预置提示(OD .sys-note):可改图标与颜色，但不可删除。
class _SysNote extends StatelessWidget {
  const _SysNote();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.yucai.accentSoft,
        border: Border.all(color: context.yucai.accentSoft),
        borderRadius: AppRadius.smBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.lock, size: 14, color: context.yucai.accent),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 11.5, color: context.yucai.muted),
                children: [
                  TextSpan(
                      text: '系统预置分类',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: ' · 可修改图标与颜色，但不可删除。删除按钮已禁用。'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 删除按钮(OD .btn-danger):系统禁用/新建无对象禁用。
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({
    super.key,
    required this.disabled,
    required this.isSystem,
    required this.onTap,
  });
  final bool disabled;
  final bool isSystem;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = isSystem ? '删除分类（系统禁用）' : '删除分类';
    return MouseRegion(
      cursor: disabled ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: context.yucai.surface,
            border: Border.all(
              color: disabled ? context.yucai.border : context.yucai.negative.withValues(alpha: 0.25),
            ),
            borderRadius: AppRadius.smBorder,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.trash2,
                size: 15,
                color: disabled ? context.yucai.muted : context.yucai.negative),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: disabled ? context.yucai.muted : context.yucai.negative)),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── helpers ─────────────────────────

String _parentNameOf(List<CategoryItem> items, CategoryItem c) {
  if (c.parentId.isEmpty) return '';
  final p = items.where((x) => x.id == c.parentId).firstOrNull;
  return p?.name ?? '';
}

String _fmtMoney(int cents) {
  final v = (cents / 100).abs();
  final sign = cents < 0 ? '-' : '';
  return '$sign¥${v.toStringAsFixed(2)}';
}

/// Renders the leading icon: emoji text when [icon] is an emoji, else the
/// default label glyph tinted by [color].
Widget _iconContent(String icon, String color, double size) {
  final isEmoji = icon.isNotEmpty && icon.runes.first > 0x2000;
  return isEmoji
      ? Text(icon, style: TextStyle(fontSize: size * 0.95))
      : Icon(LucideIcons.tag, size: size, color: _colorOf(color));
}

Color _colorOf(String hex) {
  if (hex.isEmpty || !hex.startsWith('#')) return AppColors.accent;
  final v = int.tryParse(hex.substring(1), radix: 16);
  return v == null ? AppColors.accent : Color(0xFF000000 | v);
}
