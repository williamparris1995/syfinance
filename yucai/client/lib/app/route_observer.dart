import 'package:flutter/widgets.dart';

/// 全局路由观察者。
///
/// accounts_page 订阅它，在 [RouteAware.didPopNext]（从详情页/编辑页 pop 回来）时
/// 重新拉取账户列表：详情页 /accounts/:id 用独立 AccountBloc 实例（router 为其单独
/// create），编辑账户只刷新详情页那个 bloc，列表页的 bloc 不会自动更新，于是出现
/// 「编辑估值后详情页更新、但列表 Card 估值没变」。这里在返回列表时强制 reload。
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
