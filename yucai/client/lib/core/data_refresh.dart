import 'package:flutter/foundation.dart';

/// 数据发生跨页可见变更后的全局刷新通知器(getIt lazySingleton)。
///
/// 背景(hotfix 修复根因):设置页「导入存档」会用 ArchiveImporter 整批
/// 替换本地库,但首页等页面驻留在 StatefulShellRoute.indexedStack 分支里
/// (initState 一次性加载,切分支不重建不 didPopNext),页面级缓存在导入
/// 后仍停留在启动时的空态 —— 用户看到 dashboard 全零。
///
/// 语义(2026-09 扩充):两类变更由执行方调用 [bump] 自增 value,长期驻留的
/// 页面级缓存订阅本通知器重拉:
/// 1. 数据被外部整批替换(存档导入,设置页);
/// 2. 交易记账/编辑/删除(表单页/交易详情页)—— 账户余额与仪表盘摘要随之
///    变,但变更方所在 branch 的嵌套 Navigator 与驻留页(概览/账户)互不可见,
///    RouteAware didPopNext 够不着跨 branch 场景,故走本通知器广播。
/// 绑定的刷新语义不走这里 —— 各绑定路径有自己的刷新链。
///
/// 形态照 CurrencySettings.listenable 的跨页刷新先例(ValueNotifier 广播),
/// 区别是只携带「代数」不携带值:消费方只关心「变了」,不关心变成什么。
class DataRefreshNotifier extends ValueNotifier<int> {
  DataRefreshNotifier() : super(0);

  /// 通知所有监听者:本地数据已变更,请重拉页面级缓存。
  void bump() => value++;
}
