/// MaterialApp.builder 层统一 chrome(自 app.dart 内联抽出为可测单元)。
///
/// - F29 自定义标题栏(ADR-2 取舍:builder 层统一挂,而非 app_shell):
///   登录前(guest)无 shell 的窗口同样要有标题栏,shell 层挂会漏登录页;
///   builder 包住整个 Navigator,所有路由(含窄屏底导形态)顶部一致,
///   chrome 全断点不缺席(FR-5),亦不与 app_shell 布局叠加(无双标题栏)。
///   仅 Windows 桌面非 web(移动/web 无原生窗口概念,系统标题栏保留)。
/// - 反馈⑥(桌面文本体验):展示类文本(金额/摘要/标签/报告正文)全局
///   可选可复制 —— [SelectionArea] 包住 Navigator 内容,静态 [Text] 即选;
///   桌面右键 context menu 为 Flutter 内建 adaptiveTextSelectionToolbar
///   (Copy/Select All),不引第三方。
///
/// 挂载细节(反馈⑥):SelectionArea 需 [Overlay] 祖先(选区 toolbar/handles
/// 的挂载点),而 builder 层在 Navigator/其 Overlay 之上 —— 故自供一个
/// Overlay 承载(照 framework 内部 _WrappingOverlay 同构:持久 entry,
/// didUpdateWidget 时 markNeedsBuild 透传新 child,theme 切换不致 stale)。
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:yucai_client/core/widgets/app_title_bar.dart';

/// [MaterialApp.builder] 的实现体:全局文本选择(反馈⑥)+ Windows 标题栏(F29)。
class AppChrome extends StatefulWidget {
  const AppChrome({super.key, required this.child});

  /// builder 的 child = 整个 Navigator(Router),全部路由/对话框在内。
  final Widget? child;

  @override
  State<AppChrome> createState() => _AppChromeState();
}

class _AppChromeState extends State<AppChrome> {
  late final OverlayEntry _entry = OverlayEntry(
    canSizeOverlay: true,
    opaque: true,
    builder: (BuildContext context) => _selectableContent(),
  );

  @override
  void didUpdateWidget(covariant AppChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      _entry.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _entry
      ..remove()
      ..dispose();
    super.dispose();
  }

  /// 反馈⑥:SelectionArea 包内容不包标题栏 —— 标题栏是 chrome 非内容,
  /// 其整行拖拽/双击最大化手势与选区手势无谓同场。表单不受影响:
  /// TextField/SelectableText 不消费祖先 SelectionRegistrar(自持选择
  /// 系统),analyst_note ADR-5 的 SelectableText 嵌套在内亦独立。
  Widget _selectableContent() =>
      SelectionArea(child: widget.child ?? const SizedBox.shrink());

  @override
  Widget build(BuildContext context) {
    final content = Overlay(initialEntries: <OverlayEntry>[_entry]);
    if (kIsWeb || !Platform.isWindows) {
      return content;
    }
    return Column(
      children: [
        const AppTitleBar(),
        Expanded(child: content),
      ],
    );
  }
}
