import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 提示类型：成功(绿) / 错误(红) / 警告(黄)。
enum ToastType { success, error, warning }

/// 全局轻提示。固定显示在**右上角**（顶栏下方），带类型色 + 图标，3 秒后自动消失。
///
/// 用 [OverlayEntry] 而非 [SnackBar]（SnackBar 原生只支持底部）。同一时刻只显示
/// 一条：新提示弹出时移除旧条，避免堆叠遮挡。
class AppToast {
  const AppToast._();

  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.success,
    Duration duration = const Duration(seconds: 3),
  }) {
    _current?.remove();
    _timer?.cancel();

    final overlay = Overlay.of(context, rootOverlay: true);
    _current = OverlayEntry(
      builder: (_) => _ToastView(message: message, type: type),
    );
    overlay.insert(_current!);

    _timer = Timer(duration, _dismiss);
  }

  static void _dismiss() {
    _current?.remove();
    _current = null;
    _timer?.cancel();
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({required this.message, required this.type});

  final String message;
  final ToastType type;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _style(widget.type);
    return Positioned(
      top: 72,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: style.color,
                borderRadius: AppRadius.smBorder,
                // 黑阴影豁免(暗底不可见 = v2 暗色无阴影),保原值;
                // toast 为悬浮 overlay,黑投影在两板均不刺眼。
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 6)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 白字/白 icon 落在类型色底上(固定 toast 面惯例,与
                  // success/error 一致;瞬时提示,双板均可辨识)。
                  Icon(style.icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ToastStyle _style(ToastType t) {
    switch (t) {
      case ToastType.success:
        return _ToastStyle(context.yucai.positive, LucideIcons.circleCheck);
      case ToastType.error:
        return _ToastStyle(context.yucai.negative, LucideIcons.circleAlert);
      case ToastType.warning:
        // F4-P2 裁决:原 v1 警示金 #CF9B3A → warn 语义令牌(亮 #D97706 琥珀 /
        // 暗 #FBBF24 提亮档),与 success=positive / error=negative 同为
        // 令牌取色;暗色下自动适配(非固定深面,故映射而非豁免)。
        return _ToastStyle(context.yucai.warn, LucideIcons.triangleAlert);
    }
  }
}

class _ToastStyle {
  const _ToastStyle(this.color, this.icon);
  final Color color;
  final IconData icon;
}
