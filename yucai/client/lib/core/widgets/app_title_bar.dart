import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// F29 自定义标题栏 —— 经典双层第一层(spec FR-2)。
///
/// - 高 38;纯 chrome:无徽标无文字(验收拍板 2026-09-16,品牌锚点在侧栏),
///   整行拖拽/双击区 + 右侧窗口钮;
/// - 右=三窗钮「─ / □(最大化态切 ❐)/ ✕」;
/// - 整行(钮除外)=拖拽区:onPanStart → windowManager.startDragging();
///   双击 = toggle 最大化。窗钮为拖拽区**兄弟节点**(非子节点)—— 否则
///   双击手势竞技场会 hold 住钮的单击,最多延迟 kDoubleTapTimeout 才响应;
/// - 三钮零状态本地化(ADR-3):minimize / maximize(toggle isMaximized)/
///   close 直调 windowManager —— close 在 setPreventClose(true) 下触发
///   F22 TrayController.onWindowClose 决策树,本组件零关闭逻辑;最大化
///   图标态由 WindowListener.onWindowEvent(maximize/unmaximize) 驱动;
/// - 交互色按 ADR-4 语义派生(context.yucai,禁裸 hex):底/描边=侧栏令牌
///   同口径;钮 hover=fg@6%、按下=fg@12%、关闭钮 hover=negative@10%
///   (行业惯例红警示);图标 muted → hover fg。
///
/// 接入:app.dart MaterialApp builder 层统一挂(ADR-2:登录前无 shell 的
/// guest 窗口同样生效);仅 Windows 桌面非 web,窄屏同样保留(FR-5)。
class AppTitleBar extends StatefulWidget {
  const AppTitleBar({super.key});

  @override
  State<AppTitleBar> createState() => _AppTitleBarState();
}

class _AppTitleBarState extends State<AppTitleBar> with WindowListener {
  /// 最大化态(ADR-3:窗口事件驱动,不自行查询/缓存)。
  final ValueNotifier<bool> _maximized = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // review P1:播种真实最大化态(waitUntilReadyToShow 内部有未 await 的
    // isMaximized?unmaximize 副作用;F30 恢复最大化时须在此决议后恢复)。
    // ignore: unawaited_futures
    windowManager.isMaximized().then((v) => _maximized.value = v);
  }

  @override
  void dispose() {
    windowManager.removeListener(this); // 插件单例:卸载必须注销,防跨页残留
    _maximized.dispose();
    super.dispose();
  }

  @override
  void onWindowEvent(String eventName) {
    if (eventName == kWindowEventMaximize) {
      _maximized.value = true;
    } else if (eventName == kWindowEventUnmaximize) {
      _maximized.value = false;
    }
  }

  /// FR-3:最大化语义 = isMaximized ? unmaximize : maximize。
  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return Container(
      height: 38,
      decoration: BoxDecoration(
        // FR-4:标题栏底/描边走语义令牌(侧栏同口径)。
        color: t.sidebarBg,
        border: Border(bottom: BorderSide(color: t.sidebarBorder)),
      ),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            // opaque:整行空白处同样命中 —— 拖拽/双击区 = 钮以外整行;
            // 窗钮为兄弟节点不进本手势竞技场(见类注释)。
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => windowManager.startDragging(),
            onDoubleTap: _toggleMaximize,
            // 验收拍板(2026-09-16):徽标+「御财」文字移除,标题栏只留窗口钮
            // (品牌锚点=侧栏徽标;chrome 极简)。整行纯拖拽/双击区。
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(height: 38),
            ),
          ),
        ),
        _TitleBarButton(
          tooltip: '最小化',
          icon: LucideIcons.minus,
          onTap: () => windowManager.minimize(),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _maximized,
          builder: (context, maximized, _) => _TitleBarButton(
            tooltip: maximized ? '还原' : '最大化',
            icon: maximized ? LucideIcons.copy : LucideIcons.square,
            onTap: _toggleMaximize,
          ),
        ),
        _TitleBarButton(
          tooltip: '关闭',
          icon: LucideIcons.x,
          onTap: () => windowManager.close(),
          close: true,
        ),
      ]),
    );
  }
}

/// 标题栏窗钮(ADR-4):40×38;hover=fg@6%、按下=fg@12%、图标 muted→hover fg;
/// [close] 钮 hover=negative@10%(行业惯例红警示)。[tooltip] 作 Semantics
/// 标签(见 build 内注释:builder 层无 Overlay,不能用 Tooltip)。
class _TitleBarButton extends StatefulWidget {
  const _TitleBarButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.close = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool close;

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    final Color bg;
    if (_pressed) {
      bg = t.fg.withValues(alpha: 0.12);
    } else if (_hover) {
      bg = widget.close
          ? t.negative.withValues(alpha: 0.10)
          : t.fg.withValues(alpha: 0.06);
    } else {
      bg = Colors.transparent;
    }
    final Color fg = _hover || _pressed ? t.fg : t.muted;
    // 无 Tooltip:标题栏挂在 MaterialApp builder 层(Navigator/Overlay 之外),
    // Tooltip 无 Overlay 祖先会断言失败;以 Semantics 提供无障碍标签代替。
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() {
          _hover = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: Container(
            width: 40,
            height: 38,
            decoration: BoxDecoration(color: bg),
            child: Icon(widget.icon, size: 16, color: fg),
          ),
        ),
      ),
    );
  }
}
