import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, LogicalKeyboardKey;
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// Ctrl+K 唤起命令面板的 intent(⑨ 导航增强 B)。
/// 挂载:AppShell 层 Flutter 内建 Shortcuts/Actions(任务书 B1 选型:
/// 优先内建,不用 window_manager 键盘钩子 —— 路由内/焦点链内即可达,
/// 且免平台通道);已开状态下再次触发 = 关闭(原型 toggle 语义)。
class OpenCommandPaletteIntent extends Intent {
  const OpenCommandPaletteIntent();
}

/// 命令面板条目(v1 硬编码静态清单,任务书 B4:不留插件面)。
class _PaletteEntry {
  const _PaletteEntry(this.group, this.label, this.icon, this.route);

  /// 「页面」或「操作」。
  final String group;
  final String label;
  final IconData icon;

  /// 激活目标路由(页面与操作统一为导航)。
  final String route;
}

/// 页面组 = 路由静态表(覆盖侧栏全部目的地 + 财务报告;命名与侧栏逐字
/// 同源 —— 「订阅管理」沿用侧栏标签而非任务书行文「订阅中心」,面板与
/// 侧栏同名互查是导航加速器的前提)。排序照任务书列举序,余项按侧栏序。
const _kPages = <_PaletteEntry>[
  _PaletteEntry('页面', '仪表盘', LucideIcons.layoutDashboard, '/home'),
  _PaletteEntry('页面', '报表分析', LucideIcons.barChart, '/reports'),
  _PaletteEntry('页面', '财务报告', LucideIcons.fileText, '/reports/full'),
  _PaletteEntry('页面', '交易记录', LucideIcons.receipt, '/transactions'),
  _PaletteEntry('页面', '预算管理', LucideIcons.piggyBank, '/budgets'),
  _PaletteEntry('页面', '投资组合', LucideIcons.lineChart, '/holdings'),
  _PaletteEntry('页面', '账户管理', LucideIcons.wallet, '/accounts'),
  _PaletteEntry('页面', '订阅管理', LucideIcons.repeat, '/accounts/subscriptions'),
  _PaletteEntry('页面', '债务管理', LucideIcons.landmark, '/debts'),
  _PaletteEntry('页面', '债权管理', LucideIcons.arrowUpRight, '/receivables'),
  _PaletteEntry('页面', '目标追踪', LucideIcons.target, '/goals'),
  _PaletteEntry('页面', '分类管理', LucideIcons.tags, '/categories'),
  _PaletteEntry('页面', '设置', LucideIcons.settings, '/settings'),
];

/// 操作组语境取舍(钉):记一笔 → /transactions/new(与顶栏创建按钮/
/// 窄屏 FAB 同目标);生成财务报告 → /reports/full;**导出报告 / AI 解读
/// 仅在报告页上下文有真实 handler**(F45 导出 = 页面级 _export、F46 AI =
/// 页面 _narrate,bloc 均挂 /reports/full 路由子树)—— 面板层不可达,
/// v1 统一跳报告页(原型 v10 nav-palette 操作组后两者 href 即财务报告页);
/// 「全局态置灰」分支留待页面 handler 提升为可外部触发的 controller 后
/// 再启用(避免死灰条目)。
const _kOperations = <_PaletteEntry>[
  _PaletteEntry('操作', '记一笔', LucideIcons.plus, '/transactions/new'),
  _PaletteEntry('操作', '生成财务报告', LucideIcons.fileText, '/reports/full'),
  _PaletteEntry('操作', '导出报告', LucideIcons.download, '/reports/full'),
  _PaletteEntry('操作', 'AI 解读', LucideIcons.zap, '/reports/full'),
];

const _kAllEntries = [..._kPages, ..._kOperations];

/// 全局命令面板(⑨ 导航增强 B,原型 v10 nav-palette):居中 560px +
/// 遮罩、搜索框 autofocus、结果分组「页面/操作」、↑↓ 高亮(循环)、
/// ↵ 执行、Esc/点遮罩关闭、实时过滤(contains,拼音 = backlog)、
/// 空态「无匹配」。配色全走 design-v2 语义令牌(零裸色)。
class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key, required this.onClose});

  /// 关闭请求(宿主隐藏面板;Esc/遮罩点击/执行后触发)。
  final VoidCallback onClose;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _controller = TextEditingController();
  late final FocusNode _focusNode =
      FocusNode(onKeyEvent: _onSearchKey);

  List<_PaletteEntry> _filtered = _kAllEntries;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // 挂载即夺焦:shell 场景下此前已有焦点持有者(如 shell 级兜底 Focus),
    // EditableText 的 autofocus 仅在 scope 空闲时生效 —— 显式 requestFocus
    // 保证面板一开搜索框即就位(↑↓/↵/Esc 键位链路的前提)。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// 搜索框键位拦截:↑↓/↵/Esc 在焦点节点层处理(先于 EditableText 默认
  /// 键位 —— 方向键默认被文本编辑消费,外层 Shortcuts 收不到)。
  KeyEventResult _onSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _executeSelected();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _refilter() {
    final q = _controller.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _kAllEntries
          : _kAllEntries
              .where((e) =>
                  e.label.toLowerCase().contains(q) ||
                  e.group.toLowerCase().contains(q))
              .toList();
      _selectedIndex = 0;
    });
  }

  void _move(int delta) {
    if (_filtered.isEmpty) return;
    setState(() {
      _selectedIndex =
          (_selectedIndex + delta + _filtered.length) % _filtered.length;
    });
  }

  void _execute(_PaletteEntry entry) {
    widget.onClose();
    context.go(entry.route);
  }

  void _executeSelected() {
    if (_filtered.isEmpty) return;
    _execute(_filtered[_selectedIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    final media = MediaQuery.of(context);

    // 遮罩 + 面板(原型 .pal-mask:12vh 顶部留白 + 居中 560px;入场
    // 150ms 淡入上移 —— 原型 palIn 关键帧的 TweenAnimationBuilder 等价)。
    return GestureDetector(
      // 点遮罩关闭;面板自身吞点(原型 mask click → close)。
      onTap: widget.onClose,
      child: Container(
        color: t.bg.withValues(alpha: 0.55),
        child: Align(
          alignment: const Alignment(0, -0.55),
          child: GestureDetector(
            onTap: () {},
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 150),
              builder: (context, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(
                  offset: Offset(0, -10 * (1 - v)),
                  child: child,
                ),
              ),
              // 面板本体用 Material 承载(shell 挂载点在 Scaffold 之上,
              // TextField 需 Material 祖先;shape 兼任描边+圆角)。
              child: Material(
                color: t.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: t.border),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _searchRow(t),
                      Divider(height: 1, color: t.border),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxHeight: media.size.height * 0.52),
                          child: _resultList(t),
                        ),
                      ),
                      Divider(height: 1, color: t.border),
                      _footer(t),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchRow(YucaiTheme t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 16, color: t.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              onChanged: (_) => _refilter(),
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: '搜索页面,或输入操作…',
                isDense: true,
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: t.border),
            ),
            child: Text('ESC',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: t.muted)),
          ),
        ],
      ),
    );
  }

  Widget _resultList(YucaiTheme t) {
    if (_filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: Text('无匹配', style: TextStyle(fontSize: 13, color: t.muted)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      shrinkWrap: true,
      children: [
        for (final group in const ['页面', '操作'])
          ..._groupRows(t, group),
      ],
    );
  }

  List<Widget> _groupRows(YucaiTheme t, String group) {
    final rows = _filtered.where((e) => e.group == group).toList();
    if (rows.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Text(
          '$group · ${rows.length}',
          style: TextStyle(
            fontSize: 10.5,
            color: t.muted,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ),
      for (final (i, entry) in _filtered.asMap().entries
          .where((m) => m.value.group == group)
          .map((m) => (m.key, m.value)))
        _PaletteRow(
          entry: entry,
          selected: i == _selectedIndex,
          onTap: () => _execute(entry),
        ),
    ];
  }

  Widget _footer(YucaiTheme t) {
    Widget hint(String keys, String action) => Text.rich(
          TextSpan(children: [
            TextSpan(
              text: keys,
              style: TextStyle(fontWeight: FontWeight.w700, color: t.fg),
            ),
            TextSpan(text: ' $action'),
          ]),
          style: TextStyle(fontSize: 11, color: t.muted),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          hint('↑↓', '选择'),
          const SizedBox(width: 18),
          hint('↵', '打开'),
          const SizedBox(width: 18),
          hint('Esc', '关闭'),
        ],
      ),
    );
  }
}

/// 结果行(原型 .pal-row):图标 + 名称;选中行以 sidebarActive* 点亮。
/// 行标识 key 挂在内层 Container(测试/e2e 可观测契约),本 widget 无 key。
class _PaletteRow extends StatelessWidget {
  const _PaletteRow({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final _PaletteEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    // 选中行滚入视口(键盘链路):零时长 ensureVisible,避免与列表惯性
    // 动画叠加;未选中/已可见时为 no-op。
    if (selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Scrollable.ensureVisible(context, duration: Duration.zero);
        }
      });
    }
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          key: ValueKey('paletteRow-${entry.label}'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? t.sidebarActiveBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(entry.icon,
                  size: 16, color: selected ? t.sidebarActiveFg : t.muted),
              const SizedBox(width: 12),
              Text(
                entry.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: selected ? t.sidebarActiveFg : t.fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
