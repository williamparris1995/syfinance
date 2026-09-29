/// 反馈⑥(桌面文本选择)+ 反馈1a 修复的页身选区挂载件。
///
/// 语义:仅当本页**处于稳定可视态**(入场过渡完成且未被页面路由压栈
/// 过渡中)时包 [SelectionArea];过渡期间(入场动画进行 / 被页面 push
/// 覆盖退场)裸透传。
///
/// 为何要过渡门(反馈1a 诊断,2026-09-29):
/// - 全局 scope(builder 层包整个 Router)在多滚动容器并存时拖选边沿
///   更新被静默丢弃(Flutter #153004 家族)→ 真机拖选全废;修法是
///   scope 下沉到页面体、每页一个。
/// - 但**过渡帧内**页面子树(重)建,selectables 注册进 scope 时
///   `_flushAdditions` 的屏序排序会对过渡中未布局盒 `getTransformTo`
///   断言崩溃(router_test 回归:/transactions/new 压栈覆盖列表页、
///   /reports/full 入场即带 scope 均触发)。过渡期摘 scope = 无注册
///   无排序;稳定后挂 scope = 页面已在布局中,注册安全。
///
/// 判定 = [PageRoute] 的 primary 动画 completed 且 secondary 动画
/// dismissed(压栈覆盖走 secondaryAnimation)。PopupMenu/Dialog 覆盖
/// 也驱动 secondaryAnimation → 期间摘 scope(弹层下页面无需选区,
/// 弹层自身在 root overlay 不受影响)。
///
/// 取舍:过渡/覆盖期间(视觉过渡或不可见)无选区,无语义损失;
/// 侧栏/顶栏等 chrome 文本不在页身 scope 内,与标题栏同口径不选。
/// TextField/SelectableText 自持选择系统,不受影响。
library;

import 'package:flutter/material.dart';

/// 页身选区:路由稳定可视态时包 [SelectionArea],过渡期裸透传。
class CurrentRouteSelectionArea extends StatefulWidget {
  const CurrentRouteSelectionArea({super.key, required this.child});

  final Widget child;

  @override
  State<CurrentRouteSelectionArea> createState() =>
      _CurrentRouteSelectionAreaState();
}

class _CurrentRouteSelectionAreaState extends State<CurrentRouteSelectionArea> {
  /// 入场/退场过渡是否仍在进行(primary 未完成或 secondary 未归零)。
  ///
  /// 直接 `route.animation.status` 快照 + AnimationStatusListener 跟踪
  /// 后续翻转;didChangeDependencies 重挂(路由同一实例生命周期内
  /// animation 不换引用,重挂幂等)。
  bool _inTransition = true;

  Listenable? _listened;

  void _updateFrom(Animation<double>? primary, Animation<double>? secondary) {
    final transitioning = !(primary?.isCompleted ?? false) ||
        !(secondary?.isDismissed ?? true);
    if (transitioning != _inTransition) {
      setState(() => _inTransition = transitioning);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is! PageRoute) {
      if (_inTransition) setState(() => _inTransition = false);
      return;
    }
    _listened?.removeListener(_onTick);
    _listened = Listenable.merge([
      if (route.animation != null) route.animation!,
      if (route.secondaryAnimation != null) route.secondaryAnimation!,
    ]);
    _listened!.addListener(_onTick);
    _updateFrom(route.animation, route.secondaryAnimation);
  }

  @override
  void dispose() {
    _listened?.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      _updateFrom(route.animation, route.secondaryAnimation);
    }
  }

  @override
  Widget build(BuildContext context) =>
      _inTransition ? widget.child : SelectionArea(child: widget.child);
}
