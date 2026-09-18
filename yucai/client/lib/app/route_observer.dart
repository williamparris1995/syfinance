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
/// - [holdingsRouteObserver]:持仓列表(TradeSheet pop 回来回拉);
/// - [accountsRouteObserver]:账户列表(账户详情/记一笔弹层 pop 回来回拉)。
///   修复:accounts_page 原订阅顶层 routeObserver,但 accounts 分支此前未挂
///   任何观察者(go_router 14.6 只把 GoRouter.observers 给根 Navigator,分支
///   Navigator 只认 branch.observers)→ didPopNext 从未触发,「详情页编辑
///   估值后回列表,列表 Card 余额不变」实为一直存在。
/// - [debtsRouteObserver]:债务列表(表单/详情/编辑 pop 回来回拉 + 汇总回拉);
/// - [receivablesRouteObserver]:债权列表(同上;额外回拉 ReceivablesSummary
///   —— 否则创建债权后「债权笔数」停留在 initState 时的旧值(首笔创建前
///   = 0),正是「明细有显示但笔数为 0」缺陷的根因之一)。
final RouteObserver<PageRoute> transactionsRouteObserver =
    RouteObserver<PageRoute>();
final RouteObserver<PageRoute> holdingsRouteObserver =
    RouteObserver<PageRoute>();
final RouteObserver<PageRoute> accountsRouteObserver =
    RouteObserver<PageRoute>();
final RouteObserver<PageRoute> debtsRouteObserver = RouteObserver<PageRoute>();
final RouteObserver<PageRoute> receivablesRouteObserver =
    RouteObserver<PageRoute>();
