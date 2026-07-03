import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/transaction/presentation/bloc/category_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/category_event.dart';
import 'package:yucai_client/transaction/presentation/bloc/category_state.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';

/// 分类管理页（三尺寸响应式）。
///
/// 分类 = 账户（account-as-account）：支出/收入分类即 accountType 为
/// expense/income 的账户。
///
/// 布局：
///   - desktop (≥1200)：左列表 + 右编辑面板常驻
///   - tablet  (600–1200)：列表 + 右侧编辑抽屉（新建/编辑时打开）
///   - mobile  (≤600)：列表 + 底部编辑 sheet（新建/编辑时打开）
///
/// 列表项：图标 + 名称 + 本月金额（占位「待统计」）+ 系统标记。
/// 编辑面板：名称 / 图标 / 颜色 / 父分类下拉 / 删除（系统分类禁用）。
class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  /// 测试钩子：行 key。
  static Key rowKey(String id) => ValueKey('category_row_$id');
  static Key deleteKey(String id) => ValueKey('category_delete_$id');
  static const Key editPanelKey = ValueKey('category_edit_panel');

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  CategoryType _type = CategoryType.expense;
  CategoryItem? _editing; // null = 新建模式（面板首次打开时）

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

  void _openEditor(CategoryItem? item) {
    setState(() => _editing = item);
    final bp = Breakpoints.of(context);
    if (bp == Breakpoint.mobile) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        // The modal lives on a separate Navigator route without the ambient
        // CategoryBloc; re-provide it from the page context.
        builder: (_) => BlocProvider<CategoryBloc>.value(
          value: context.read<CategoryBloc>(),
          child: BlocBuilder<CategoryBloc, CategoryState>(
            buildWhen: (_, c) => c is! CategorySubmitting,
            builder: (ctx, state) => _EditPanel(
              key: CategoryManagementPage.editPanelKey,
              type: _type,
              item: item,
              candidates: _parentCandidates(state, item?.id),
              onSave: _dispatchSave,
              onDelete: _dispatchDelete,
            ),
          ),
        ),
      );
    } else if (bp == Breakpoint.tablet) {
      _scaffoldKey.currentState?.openEndDrawer();
    }
    // desktop: panel is always visible; _editing drives its content.
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
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('分类管理'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: FilledButton.icon(
              onPressed: () => _openEditor(null),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('新建分类'),
            ),
          ),
        ],
      ),
      endDrawer: Breakpoints.of(context) == Breakpoint.tablet
          ? Drawer(
              width: 380,
              child: BlocBuilder<CategoryBloc, CategoryState>(
                buildWhen: (_, c) => c is! CategorySubmitting,
                builder: (ctx, state) => _EditPanel(
                  key: CategoryManagementPage.editPanelKey,
                  type: _type,
                  item: _editing,
                  candidates: _parentCandidates(state, _editing?.id),
                  onSave: _dispatchSave,
                  onDelete: _dispatchDelete,
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          _TypeTabsRow(type: _type, onChanged: _switchType),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ResponsiveLayout(
              mobile: _listOnly(),
              tablet: _listOnly(),
              desktop: _listPlusPanel(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listOnly() {
    return BlocBuilder<CategoryBloc, CategoryState>(
      buildWhen: (p, c) => c is! CategorySubmitting,
      builder: (context, state) {
        final items = _itemsOf(state);
        if (state is CategoryLoading && items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('暂无分类，点击右上角「新建分类」',
                  style: TextStyle(color: AppColors.muted)),
            ),
          );
        }
        return ReorderableListView.builder(
          buildDefaultDragHandles: false,
          itemCount: items.length,
          onReorderItem: (oldIndex, newIndex) {
            context
                .read<CategoryBloc>()
                .add(ReorderCategoriesRequested(oldIndex: oldIndex, newIndex: newIndex));
          },
          itemBuilder: (context, i) => _CategoryRow(
            key: CategoryManagementPage.rowKey(items[i].id),
            item: items[i],
            onTap: () => _openEditor(items[i]),
            onReorderHandle: (ctx) => ReorderableDragStartListener(
              index: i,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(LucideIcons.gripVertical, size: 18, color: AppColors.muted),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _listPlusPanel() {
    return Row(
      children: [
        Expanded(flex: 3, child: _listOnly()),
        const VerticalDivider(width: 1, color: AppColors.border),
        Expanded(
          flex: 2,
          child: BlocBuilder<CategoryBloc, CategoryState>(
            buildWhen: (_, c) => c is! CategorySubmitting,
            builder: (ctx, state) => _EditPanel(
              key: CategoryManagementPage.editPanelKey,
              type: _type,
              item: _editing,
              candidates: _parentCandidates(state, _editing?.id),
              onSave: _dispatchSave,
              onDelete: _dispatchDelete,
            ),
          ),
        ),
      ],
    );
  }

  List<CategoryItem> _itemsOf(CategoryState state) {
    if (state is CategoryLoaded) return state.categories;
    if (state is CategoryLoading) return state.categories;
    if (state is CategorySubmitting) return state.categories;
    if (state is CategoryError) return state.categories;
    return const [];
  }

  /// Parent-category candidates for the dropdown: same-type top-level
  /// categories (no parentId), excluding the item being edited (can't be
  /// own parent) and any descendants (avoids cycles). For now children are
  /// also excluded from being parents to keep the picker to depth-2.
  List<CategoryItem> _parentCandidates(CategoryState state, String? selfId) {
    final items = _itemsOf(state);
    return items
        .where((c) =>
            c.parentId.isEmpty && // only top-level can be a parent
            c.id != selfId &&
            !c.isSystem) // presets aren't meant as custom parents
        .toList();
  }
}

class _TypeTabsRow extends StatelessWidget {
  const _TypeTabsRow({required this.type, required this.onChanged});
  final CategoryType type;
  final ValueChanged<CategoryType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          for (final t in CategoryType.values) ...[
            _Pill(
              label: t.label,
              selected: t == type,
              onTap: () => onChanged(t),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.surface,
            border: Border.all(
                color: selected ? AppColors.accent : AppColors.border),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.fg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    super.key,
    required this.item,
    required this.onTap,
    required this.onReorderHandle,
  });

  final CategoryItem item;
  final VoidCallback onTap;
  final WidgetBuilder onReorderHandle;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CategoryBloc>();
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: _colorOf(item.color).withValues(alpha: 0.15),
        child: _iconContent(item.icon, item.color, 18),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(item.name,
                style: const TextStyle(
                    color: AppColors.fg, fontWeight: FontWeight.w600)),
          ),
          if (item.isSystem) ...[
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('系统',
                  style: TextStyle(fontSize: 10, color: AppColors.accent)),
            ),
          ],
        ],
      ),
      subtitle: Text(
        item.monthlyAmountReady ? '本月：¥${(item.monthlyAmountCents / 100).toStringAsFixed(2)}' : '本月：待统计',
        style: const TextStyle(fontSize: 12, color: AppColors.muted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          onReorderHandle(context),
          IconButton(
            key: CategoryManagementPage.deleteKey(item.id),
            tooltip: '删除分类',
            icon: const Icon(LucideIcons.trash2, size: 20, color: AppColors.negative),
            onPressed: item.isSystem
                ? null
                : () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: const Text('删除分类'),
                        content: Text('确定删除「${item.name}」吗？此操作不可撤销。'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(d, false),
                              child: const Text('取消')),
                          FilledButton(
                              onPressed: () => Navigator.pop(d, true),
                              child: const Text('删除')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      bloc.add(DeleteCategoryRequested(item.id));
                    }
                  },
          ),
        ],
      ),
    );
  }
}

/// 编辑面板（desktop 右栏常驻 / tablet 抽屉 / mobile sheet 共用同一组件）。
class _EditPanel extends StatefulWidget {
  const _EditPanel({
    super.key,
    required this.type,
    required this.item,
    required this.candidates,
    required this.onSave,
    required this.onDelete,
  });

  final CategoryType type;
  final CategoryItem? item; // null = 新建
  /// 可选父分类候选（同 accountType 的顶级分类，排除当前编辑项）。
  final List<CategoryItem> candidates;
  final void Function(String name, String icon, String color, String parentId) onSave;
  final VoidCallback onDelete;

  @override
  State<_EditPanel> createState() => _EditPanelState();
}

/// 常用 emoji 图标（餐饮/交通/购物/娱乐/居家/医疗/工资/兼职/理财/红包/教育/旅行...）。
/// 存为 account.icon 字符串（emoji 直接保存，前端渲染即字符串）。
const _presetIcons = <String>[
  '🥢', '🍔', '☕', '🍷',
  '🚌', '🚗', '✈️', '🚕',
  '🛍️', '👕', '💻', '📦',
  '🎮', '🎬', '🎵', '📚',
  '🏠', '🛏️', '💡', '🔧',
  '💊', '🏥', '🦷', '💪',
  '💰', '💼', '📈', '🏦',
  '🧧', '🎁', '🎓', '🌍',
];

/// 色板：御财品牌色 + 常用色（hex 字符串，存 account.color）。
const _presetColors = <String>[
  '#B08D57', '#2D8A6E', '#C4544D', '#1C1E21',
  '#3B82F6', '#8B5CF6', '#F59E0B', '#EC4899',
  '#10B981', '#EF4444', '#6366F1', '#14B8A6',
];

class _EditPanelState extends State<_EditPanel> {
  final _nameCtrl = TextEditingController();
  // 默认图标用首个预设 emoji，避免空值。
  String _icon = _presetIcons.first;
  String _color = _presetColors.first;
  String _parentId = ''; // 空 = 一级分类

  @override
  void initState() {
    super.initState();
    _hydrate(widget.item);
  }

  void _hydrate(CategoryItem? item) {
    if (item != null) {
      _nameCtrl.text = item.name;
      _icon = item.icon.isEmpty ? _presetIcons.first : item.icon;
      _color = item.color.isEmpty ? _presetColors.first : item.color;
      _parentId = item.parentId;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _EditPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item?.id != widget.item?.id) {
      _hydrate(widget.item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final isSystem = widget.item?.isSystem ?? false;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        // iOS 软键盘遮挡避让。
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEdit ? '编辑分类' : '新建分类',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.fg)),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '分类名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _Label('图标'),
            _IconPicker(
              value: _icon,
              onChanged: (v) => setState(() => _icon = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _Label('颜色'),
            _ColorPicker(
              value: _color,
              onChanged: (v) => setState(() => _color = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '父分类（二级）',
                border: OutlineInputBorder(),
              ),
              // ignore: deprecated_member_use
              value: _parentId,
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('无（一级分类）'),
                ),
                ...widget.candidates.map(
                  (c) => DropdownMenuItem<String>(
                    value: c.id,
                    child: Row(
                      children: [
                        _IconBadge(icon: c.icon, color: c.color, size: 18),
                        const SizedBox(width: 8),
                        Text(c.name),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: isSystem
                  ? null
                  : (v) => setState(() => _parentId = v ?? ''),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: isSystem
                        ? null
                        : () => widget.onSave(
                              _nameCtrl.text.trim(),
                              _icon,
                              _color,
                              _parentId,
                            ),
                    child: Text(isEdit ? '保存修改' : '确认创建'),
                  ),
                ),
                if (isEdit) ...[
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: isSystem ? null : widget.onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.negative,
                    ),
                    child: const Text('删除'),
                  ),
                ],
              ],
            ),
            if (isSystem)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: Text('系统预置分类不可修改或删除',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      );
}

/// 图标网格选择器：点击 emoji 选中高亮。
class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.value, required this.onChanged});
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
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: e == value
                      ? AppColors.accentSoft
                      : AppColors.surface,
                  border: Border.all(
                    color: e == value ? AppColors.accent : AppColors.border,
                    width: e == value ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(e, style: const TextStyle(fontSize: 18)),
              ),
            ),
          ),
      ],
    );
  }
}

/// 颜色色板选择器：点击色块选中高亮。
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
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
                    color: hex.toUpperCase() == value.toUpperCase()
                        ? AppColors.fg
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: hex.toUpperCase() == value.toUpperCase()
                    ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// 图标徽章（下拉项用）：圆形背景 + emoji/兜底 label 图标。
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color, this.size = 18});
  final String icon;
  final String color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: _colorOf(color).withValues(alpha: 0.15),
      child: _iconContent(icon, color, size),
    );
  }
}

/// Renders the leading icon: emoji text when [icon] is an emoji, else the
/// default label glyph tinted by [color].
Widget _iconContent(String icon, String color, double size) {
  final isEmoji = icon.isNotEmpty && icon.runes.first > 0x2000;
  return isEmoji
      ? Text(icon, style: TextStyle(fontSize: size * 0.9))
      : Icon(LucideIcons.tag, size: size, color: _colorOf(color));
}

Color _colorOf(String hex) {
  if (hex.isEmpty || !hex.startsWith('#')) return AppColors.accent;
  final v = int.tryParse(hex.substring(1), radix: 16);
  return v == null ? AppColors.accent : Color(0xFF000000 | v);
}
