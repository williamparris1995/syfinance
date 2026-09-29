/// MaterialApp.builder 层统一 chrome(自 app.dart 内联抽出为可测单元)。
///
/// - F29 自定义标题栏(ADR-2 取舍:builder 层统一挂,而非 app_shell):
///   登录前(guest)无 shell 的窗口同样要有标题栏,shell 层挂会漏登录页;
///   builder 包住整个 Navigator,所有路由(含窄屏底导形态)顶部一致,
///   chrome 全断点不缺席(FR-5),亦不与 app_shell 布局叠加(无双标题栏)。
///   仅 Windows 桌面非 web(移动/web 无原生窗口概念,系统标题栏保留)。
///
/// - 反馈⑥(桌面文本体验)曾在此全局包 [SelectionArea] —— 反馈1a 真机
///   实测拖选完全无效,根因(诊断 e2e + widget 矩阵复现,2026-09-29):
///   **单一 SelectionArea scope 内并存多个可见滚动容器**(侧栏 ListView
///   + 各页面滚动 + shell 外报表页)时,选区边沿更新(edge update)在
///   SelectionContainer 层级间被静默丢弃 —— 手势竞技场本身全胜
///   (TapAndPanGestureRecognizer 独成员默认胜出,onDragStart 亦达),
///   但 forEnd 派发零效果;对应 Flutter 上游开放缺陷 #153004
///   (P2, SelectableRegion Improvements)。嵌套 scope(全局+页内)同样坏。
///   故本层不再持选区;scope 下沉到**页面体**(ADR):
///   展示型大页面页身自包 [CurrentRouteSelectionArea](core/widgets,
///   含过渡期摘除防注册排序断言)—— 先例面:交易记录页(行内描述/
///   金额)与财务报告页(报告正文);侧栏/顶栏等 chrome 不选,与标题
///   栏同口径。TextField/SelectableText 自持选择系统,不受影响。
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:yucai_client/core/widgets/app_title_bar.dart';

/// [MaterialApp.builder] 的实现体:Windows 标题栏(F29)。
class AppChrome extends StatelessWidget {
  const AppChrome({super.key, required this.child});

  /// builder 的 child = 整个 Navigator(Router),全部路由/对话框在内。
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isWindows) {
      return child ?? const SizedBox.shrink();
    }
    return Column(
      children: [
        const AppTitleBar(),
        Expanded(child: child ?? const SizedBox.shrink()),
      ],
    );
  }
}
