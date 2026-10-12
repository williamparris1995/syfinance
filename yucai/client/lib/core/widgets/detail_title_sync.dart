import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/shell_detail_title.dart';

/// F58 I-1(评审修复):详情标题同步组件 —— build 期经帧回调幂等注入
/// [ShellDetailTitle]。
///
/// 为什么不用 BlocListener set:listener 只吃 bloc 新 emission;「跨分支
/// 回退」路径(debts → 别分支 → go 回 debts)下,分支冻结的 bloc 无新
/// 发射、scrubber 已按实体 key 清零 → 顶栏当前级永停「…」。
///
/// 触发时机(实证修正):go_router 14.6.2 分支回退时路由 builder **不重跑**
/// (冻结分支整树缓存,DebugPrint 实测零重建),「builder 重跑 → 组件重建」
/// 不成立;实际重建信号 = StatefulShellRoute 分支容器的
/// `Offstage(TickerMode(enabled: isActive))` —— TickerMode 是
/// InheritedWidget,分支切换必翻转活跃位、依赖者必重建。故本组件依赖
/// [TickerMode]:
///  - 非活跃分支(`of == false`)不注入 —— 离开分支时冻结页重建也不会
///    回写旧标题污染当前分支;
///  - 分支回退(`of == true` 重建)→ 重排帧回调完成重注入。
///
/// 约束:
///  - 不可 build 期同步 set —— set 会打 _TopBar 的 ValueListenableBuilder
///    markNeedsBuild during build;帧回调已脱离 build 期,合法;
///  - 幂等:回调内 `port.value != title` 才 set(同值零 notify,不 churn);
///  - [title] null(未加载/失败)= 不动(占位「…」由 shell 兜;清理归
///    页面 dispose clear + shell scrubber 双保险,本组件不清理);
///  - guarded getIt:stripped 测试 harness 未注册 port 时静默跳过。
class DetailTitleSync extends StatelessWidget {
  const DetailTitleSync({super.key, required this.title});

  /// 详情实体标题(counterparty/账户名);null = 未加载/失败,不动。
  final String? title;

  @override
  Widget build(BuildContext context) {
    // 分支活跃守卫(必先行调用注册 Inherited 依赖,使分支切换的活跃位
    // 翻转触发本组件重建 —— 分支回退的重注入时机)。valuesOf 为 of 的
    // 非弃用形态(Flutter 3.35+),同样建立依赖。
    if (!TickerMode.valuesOf(context).enabled) return const SizedBox.shrink();
    final t = title;
    if (t == null) return const SizedBox.shrink();
    if (!getIt.isRegistered<ShellDetailTitle>()) {
      return const SizedBox.shrink();
    }
    final port = getIt<ShellDetailTitle>();
    // 同值短路:值已就位时不再排帧回调(loaded 分支重建高频,免无谓调度)。
    if (port.value == t) return const SizedBox.shrink();
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      // 帧内再校验:build 与回调的间隙 port 可能已被 scrubber 清零/他页改写。
      if (port.value != t) port.set(t);
    });
    return const SizedBox.shrink();
  }
}
