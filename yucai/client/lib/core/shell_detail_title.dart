import 'package:flutter/foundation.dart';

/// 壳层详情标题 port(F58 ADR-1,FR-2):detail 页 → 顶栏面包屑当前级的
/// 标题注入通道。
///
/// 语义:详情页数据加载完成 `set(counterparty/账户名)`;离开页面 `clear()`;
/// shell 顶栏经 ValueListenableBuilder 监听本 notifier 消费,且 location
/// 变化即清零(双保险:页面 dispose + shell location-diff,防标题残留到
/// 后续页面)。加载中/失败态保持 null —— 顶栏按占位「…」渲染,不阻塞
/// page 级回退。
///
/// 形态照 DataRefreshNotifier 先例(ValueNotifier 广播 + getIt
/// lazySingleton);区别是携带值本身。不绑路由实现、不 import 任何模块
/// bloc —— 页面与 shell 只经本 port 相见(跨模块 port 约束)。
class ShellDetailTitle extends ValueNotifier<String?> {
  ShellDetailTitle() : super(null);

  /// 详情页注入当前实体标题(顶栏面包屑当前级随之更新)。
  void set(String title) => value = title;

  /// 离开详情页清理标题(回 branch 元数据口径,防残留)。
  void clear() => value = null;
}
