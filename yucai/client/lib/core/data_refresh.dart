import 'package:flutter/foundation.dart';

/// 数据整批替换后的全局刷新通知器(getIt lazySingleton)。
///
/// 背景(hotfix 修复根因):设置页「导入存档」会用 ArchiveImporter 整批
/// 替换本地库,但首页等页面驻留在 StatefulShellRoute.indexedStack 分支里
/// (initState 一次性加载,切分支不重建不 didPopNext),页面级缓存在导入
/// 后仍停留在启动时的空态 —— 用户看到 dashboard 全零。
///
/// 语义:数据被外部整批替换(存档导入)后,由执行方调用 [bump] 自增
/// value;长期驻留的页面级缓存(如 HomePage 的净资产/摘要 Future 组)订阅
/// 本通知器重拉。绑定的刷新语义不走这里 —— 各绑定路径有自己的刷新链。
///
/// 形态照 CurrencySettings.listenable 的跨页刷新先例(ValueNotifier 广播),
/// 区别是只携带「代数」不携带值:消费方只关心「变了」,不关心变成什么。
class DataRefreshNotifier extends ValueNotifier<int> {
  DataRefreshNotifier() : super(0);

  /// 通知所有监听者:本地数据已被整批替换,请重拉页面级缓存。
  void bump() => value++;
}
