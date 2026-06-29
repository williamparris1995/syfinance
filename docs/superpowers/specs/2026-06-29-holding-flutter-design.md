# Holding Flutter 移植(A-flutter)设计

> 子项目 A 的 Flutter 移植阶段。A-server 双写 ✅(后端,commit `a869c15..b32157f`),A-od 原型 ✅(设计源 `design-output/holding/`,6 界面三端)。本 spec 细化 A-flutter(yucai/client Flutter 移植 + 真 API 对接)。

**Goal:** holding 模块 Flutter 移植(DDD 四层),6 界面对齐 A-od 设计源,真 API 对接(✅ 端点)+ ⏳ 端点调真 proto fail 降级。

**架构基调:** 照搬御财 **debt DDD 模式**(yucai/client/lib/debt/,source_account_id 双写刚做完)+ **fl_chart** 图表 + 纯 gRPC(无 drift 本地缓存,御财惯例)。

## 目标 / 非目标

**目标:**
- 6 界面 Flutter widget(对齐 A-od `design-output/holding/`):持仓列表 / 交易 Sheet(buy/sell/dividend/split)/ Security 管理 / 持仓详情 / 收益统计页 / 投资目标关联
- DDD 四层(domain/data/presentation),照搬 debt 命名与模式
- ✅ 端点真对接(ListHoldings/BuyHolding/SellHolding/CreateSecurity/ListSecurities/SearchSecurities/UpdateSecurityPrice/RecordDividend)
- ⏳ 端点调真 proto + fail 降级(ListHoldingTransactions/RecordSplit/snapshot/goal)
- Dart stub 重生成(`fromAccountId`)
- fl_chart 饼图/sparkline/收益曲线/配置环图

**非目标:**
- drift 本地缓存(御财现有模块纯 gRPC,holding 首版同样)
- ⏳ 端点后端实现(各自子项目 B/C/D;A-flutter 调真 proto fail 降级)
- i18n(御财惯例中文硬编码)
- candlestick K 线(holding 是持仓管理,非交易;若 B/C 需要再加 syncfusion/k_chart)

## 前置(阻塞,Task 0)

1. **Dart stub 重生成**:`make gen-dart`(从 `yucai/`)。`HoldingTradeRequest.fromAccountId` 当前 Dart stub 缺(proto 已有,Task 1 A-server 加的)。前置:`dart pub global activate protoc_plugin`(25.0.0)+ `protoc`(libprotoc 25+) on PATH。**不能用 buf**(local resolver 无法 exec protoc-gen-dart.bat,见 `yucai/proto/.buf.gen.dart.local.yaml`)。
2. **fl_chart 加入 pubspec**:`yucai/client/pubspec.yaml` 加 `fl_chart: ^0.69.0`(或最新稳定)+ `flutter pub get`。

## 总体架构

- **DDD 四层 feature-first**(`yucai/client/lib/holding/`):domain(data 无依赖)→ data(impl+remote_ds+mapper)→ presentation(bloc+pages+widgets)。
- **状态管理** flutter_bloc ^8.1.6;entity 用 `Equatable`(无 freezed);event 带参数用 `XxxParams extends Equatable`;state `XxxInitial/Loading/Loaded/DetailLoaded/Submitting/Error`,Error/Submitting 携带 `last` 保持上下文。
- **错误** `Either<Failure,T>`(dartz);repo 接口返回 `Future<Either<Failure,T>>`,impl 用 `_guard` 包;remote ds 抛裸异常 + `_retry.call`(401 透明刷新)。
- **路由** go_router;`app/router.dart` 新增 `/holdings` 分支(列表/详情/表单各 BlocProvider);加进 `redirect` 的 `goingProtected` 白名单。
- **DI** get_it + injectable;`@injectable`(bloc factory)、`@LazySingleton()`(remote_ds)、`@LazySingleton(as: HoldingRepository)`(repo_impl);改完 `make flutter-build-runner`(`dart run build_runner build --delete-conflicting-outputs`)再生 `injection.config.dart`。
- **枚举 NAME 映射**(off-by-one:proto UNSPECIFIED=0 + 业务 1+;domain 0+。**绝不按 int 强转**,按符号 NAME switch — debt mapper 已验证此坑)。
- **无 i18n**(中文硬编码,御财惯例)。

## domain(`holding/domain/`)

照搬 `debt/domain/` 结构:

- **entities/holding_entity.dart**:`Holding`(security_id/quantity/avg_cost_cents/current_price_cents/market_value_cents/unrealized_pnl_cents/pnl_pct/type/currency)、`Security`(id/symbol/name/type/exchange/currency/price_cents)、`HoldingTransaction`(id/security_id/trade_type/quantity/price_cents/fee_cents/trade_date/notes)、`GoalLink`(goal_id/name/backing_holding_id/target_cents/current_market_value_cents/pct/status)。全 Equatable。
- **repositories/holding_repository.dart**:`abstract class HoldingRepository`(全 10 RPC,返回 `Future<Either<Failure,T>>`):
  - `listHoldings({accountId})` / `listHoldingTransactions({holdingId})`
  - `buy({...fromAccountId...})` / `sell({...fromAccountId...})` / `recordDividend({...})` / `recordSplit({...})`
  - `createSecurity({...})` / `listSecurities({type?})` / `searchSecurities(query)` / `updateSecurityPrice(id, priceCents)`
- **value_objects.dart**:`enum SecurityType { stock, fund, etf, bond, gold, option, other }` + `enum TradeType { buy, sell, dividend, split }`(domain 索引 0+)。

## data(`holding/data/`)

照搬 `debt/data/`:

- **holding_repository_impl.dart**:`@LazySingleton(as: HoldingRepository)`,持 `HoldingRemoteDS`,每方法 `_guard<T>(() async => ...)` 包 Either。
- **holding_remote_ds.dart**:`@LazySingleton()`,构造 `HoldingServiceClient(channel, interceptors:[authInterceptor])`(注入 GrpcClient + AuthRetryCaller);每 RPC 包 `_retry.call(() async {...})`。`buy/sell` 写入 `fromAccountId: fromAccountId ?? ''`(空串=不双写,对齐 debt remote_ds:90)。
- **mappers/holding_mapper.dart**:`static toDomain`(HoldingDTO/SecurityDTO/HoldingTransactionDTO → entity)+ 枚举 `securityTypeFromProto/toProto`、`tradeTypeFromProto/toProto`(**按 NAME switch**,注释警告 off-by-one)。

## presentation(`holding/presentation/`)

### bloc(照搬 `debt/presentation/bloc/`)
- **holding_event.dart**:`abstract HoldingEvent` + `LoadHoldingsRequested({typeFilter})` / `LoadDetailRequested(id)` / `BuyRequested(params)` / `SellRequested(params)` / `RecordDividendRequested(params)` / `RecordSplitRequested(params)` / `CreateSecurityRequested(params)` / `LoadSecuritiesRequested` / `SearchSecuritiesRequested(query)` / `UpdatePriceRequested(id,price)`。带参数事件用 `XxxParams extends Equatable`(含 `fromAccountId`)。
- **holding_state.dart**:`HoldingInitial/Loading/Loaded/DetailLoaded/Submitting/Error`。Loaded 携带 holdings+summary+securities;DetailLoaded 携带 detail+trades(⏳ 可能空)+pnlBreakdown;Error/Submitting 携带 `last`。
- **holding_bloc.dart**:`@injectable`,on<EachEvent>;成功后 `add(LoadHoldingsRequested(filter:_lastFilter))` 自刷新;⏳ RPC fail → emit Error(last: currentList, isPendingBackend: true)(UI 显示空态 + ⏳ 标注)。

### pages(6 界面,对齐 A-od `design-output/holding/`)
| Page | 对齐 A-od | 关键 |
|---|---|---|
| `holdings_page.dart` | holdings | StatCard(总市值/成本/盈亏/收益率)+ fl_chart **饼图**(type 占比)+ 持仓列表(sparkline fl_chart 迷你折线)+ chips 筛选 + 多币种汇总(CurrencyBloc 复用) |
| `trade_sheet_page.dart` | trade-sheet | buy/sell/dividend/split **4 类型 form**(segmented 切换)+ **from-account picker**(照搬 `receivable_form_page.dart:576` 的 DropdownButtonFormField + `_loadSourceAccounts`:asset 非 otherAsset)+ 实时金额 + 余额 fail-fast 预览(buy 不足红字) |
| `security_page.dart` | security | 列表 + 搜索 + 创建表单 + 价格管理(行内编辑 + 自动 sync 开关 disabled B) |
| `holding_detail_page.dart` | holding-detail | 摘要 + fl_chart **收益曲线**(日/月/年)+ realized/unrealized + **交易历史**(ListHoldingTransactions ⏳ fail 降级空态)+ 配置占比环图 + 关联目标卡(goal ⏳) |
| `performance_page.dart` | performance | fl_chart 总收益曲线(日/月/年 + 区间)+ realized/unrealized 分解 + 年化 + 持仓/类型贡献条(snapshot ⏳ fail 降级,前端从 trades 聚合) |
| `goal_link_page.dart` | goal-link | holding-backed goals 列表(进度条)+ 关联 holding 选择(goal ⏳ fail 降级) |

### widgets
复用 `core/widgets/`(page_header/data_card/form_section/amount_input/filter_bar/type_tabs/app_toast)+ 新增 holding 专用(fl_chart 饼图/sparkline/曲线 widget)。

## ⏳ 端点 fail 降级模式

⏳ 端点(ListHoldingTransactions/RecordSplit/snapshot/goal):
- Flutter 调真 proto 方法(gRPC client 已生成,后端可能 Unimplemented)。
- bloc `_guard` catch GrpcError → `emit Error(last: currentList, isPendingBackend: true)`。
- UI:`isPendingBackend` 时显示**空态 + "⏳ 待后端" 标注**(非报错弹窗)。
- **后端 ready 后自动可用**(Flutter 代码是真对接,无需 mock/真切换)。

## 端点清单(10 RPC,✅/⏳)

| 端点 | 用途 | 状态 | Flutter |
|---|---|---|---|
| `CreateSecurity` | 建 security | ✅ | 真对接 |
| `ListSecurities` / `SearchSecurities` | 列表/搜索 | ✅ | 真对接 |
| `UpdateSecurityPrice` | 手动改价 | ✅ | 真对接 |
| `BuyHolding` | 买入(双写) | ✅ | 真对接(fromAccountId 必填) |
| `SellHolding` | 卖出(双写) | ✅ | 真对接(fromAccountId 必填) |
| `RecordDividend` | 分红 | ✅proto/⏳双写 | 真对接(端点 work,双写后端 ⏳) |
| `ListHoldings` | 持仓列表/详情 | ✅ | 真对接 |
| `ListHoldingTransactions` | 交易历史 | ⏳ | 调真 proto fail 降级 |
| `RecordSplit` | 拆分 | ⏳ | 调真 proto fail 降级(split form 提交 ⏳) |
| 收益 snapshot(日/月/年) | 收益曲线 | ⏳C | 调真 proto fail 降级(performance 前端从 trades 聚合) |
| `goal.backing_holding_id` | 目标关联 | ⏳D | 调真 proto fail 降级 |

**handoff 标注**:跨币种 gap(security vs account 币种)A-server 未校验 —— from-account picker 客户端预校验(disabled 跨币种,照搬 receivable_form 币种过滤)作防线。

## 关键模式(照搬 debt,直接参考文件)

- **Either+_guard**:[debt_repository_impl.dart](../../../yucai/client/lib/debt/data/debt_repository_impl.dart) `_guard<T>`
- **remote ds+_retry**:[debt_remote_ds.dart](../../../yucai/client/lib/debt/data/debt_remote_ds.dart)(client 构造 + `_retry.call`)
- **枚举 NAME 映射**:[debt_mapper.dart](../../../yucai/client/lib/debt/data/mappers/debt_mapper.dart)(off-by-one 警告)
- **from-account picker**:[receivable_form_page.dart:576](../../../yucai/client/lib/debt/presentation/pages/receivable_form_page.dart)(DropdownButtonFormField + `_loadSourceAccounts` + 提交校验)
- **路由 BlocProvider**:[app/router.dart:216-356](../../../yucai/client/lib/app/router.dart)(debt+receivables branch 写法)
- **状态/bloc 三件套**:[debt/presentation/bloc/](../../../yucai/client/lib/debt/presentation/bloc/)(event/state/bloc)

## 范围边界(本 A-flutter 不做)

- drift 本地缓存(御财纯远程惯例)。
- ⏳ 端点后端实现(各自子项目 B/C/D)。
- i18n(中文硬编码)。
- candlestick K 线(B/C 若需再加 syncfusion/k_chart)。
- A-od 原型重做(设计源已就绪)。

## 参考

- A-od 设计源:[design-output/holding/](../../../design-output/holding/)(6 界面三端 HTML + styles/mock)+ spec [2026-06-29-holding-ui-design.md](2026-06-29-holding-ui-design.md)
- debt Flutter layers(直接模板):[yucai/client/lib/debt/](../../../yucai/client/lib/debt/)
- A-server holding API:[holding.proto](../../../yucai/proto/holding/v1/holding.proto)(含 from_account_id,10 RPC)
- 总体设计:[2026-06-28-holding-asset-management-design.md](2026-06-28-holding-asset-management-design.md)(§4.3 Flutter 移植)
- 工作流:[[od-prototype-to-flutter]](OD 原型作设计源直接产 Flutter)
