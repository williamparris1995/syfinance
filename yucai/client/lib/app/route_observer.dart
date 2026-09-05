import 'package:flutter/widgets.dart';

/// 全局路由观察者。
///
/// accounts_page 订阅它，在 [RouteAware.didPopNext]（从详情页/编辑页 pop 回来）时
/// 重新拉取账户列表：详情页 /accounts/:id 用独立 AccountBloc 实例（router 为其单独
/// create），编辑账户只刷新详情页那个 bloc，列表页的 bloc 不会自动更新，于是出现
/// 「编辑估值后详情页更新、但列表 Card 估值没变」。这里在返回列表时强制 reload。
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

/// ───────── F14 疑点 #3/#4:branch 嵌套 Navigator 观察者 ─────────
/// StatefulShellRoute 各 branch 的子路由(/transactions/new、/holdings/trade
/// 等)push/pop 发生在 branch 自己的嵌套 Navigator 上,顶层 [routeObserver]
/// (挂根 Navigator)看不到;而 NavigatorObserver 不允许同时挂多个 Navigator
/// (`observer.navigator == null` 断言)。故为需要 RouteAware 回拉的 branch
/// 各配一个独立观察者(router.dart branch observers 传入),页内订阅对应实例:
/// - [transactionsRouteObserver]:交易列表(顶栏创建/详情/编辑 pop 回来回拉);
/// - [holdingsRouteObserver]:持仓列表(TradeSheet pop 回来回拉)。
final RouteObserver<PageRoute> transactionsRouteObserver =
    RouteObserver<PageRoute>();
final RouteObserver<PageRoute> holdingsRouteObserver =
    RouteObserver<PageRoute>();
