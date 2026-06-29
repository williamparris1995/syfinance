# Holding Flutter 移植(A-flutter)实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** holding 模块 Flutter 移植(DDD 四层),6 界面对齐 A-od 设计源,✅ 端点真对接 + ⏳ 端点调真 proto fail 降级。

**Architecture:** 照搬御财 [debt DDD 模式](../../../yucai/client/lib/debt/)(domain/data/presentation + bloc)+ fl_chart 图表 + 纯 gRPC(无 drift 缓存)。前置:Dart stub 重生成(fromAccountId)+ fl_chart pubspec。

**Tech Stack:** Flutter + flutter_bloc ^8.1.6 + go_router + get_it/injectable + grpc + dartz(`Either<Failure,T>`)+ Equatable(无 freezed)+ fl_chart + bloc_test/mocktail。

## Global Constraints

- **照搬御财 debt 模式**:[yucai/client/lib/debt/](../../../yucai/client/lib/debt/)(domain/data/presentation/bloc 全套),source_account_id 双写链路是 from-account picker 直接模板。
- **状态** flutter_bloc;entity Equatable(无 freezed);event 带参数用 `XxxParams extends Equatable`;state `XxxInitial/Loading/Loaded/DetailLoaded/Submitting/Error`(Error/Submitting 携带 `last`)。
- **错误** `Either<Failure,T>`(dartz);repo 接口 `Future<Either<Failure,T>>`,impl `_guard`;remote ds 抛裸异常 + `_retry.call`(401 透明刷新)。
- **枚举 NAME 映射**(off-by-one:proto UNSPECIFIED=0+业务 1+,domain 0+。**绝不按 int 强转**,按符号 NAME switch — debt mapper 已验证)。
- **DI** get_it/injectable;`@injectable`(bloc)、`@LazySingleton()`(remote_ds)、`@LazySingleton(as: HoldingRepository)`(repo_impl);改完 `make flutter-build-runner`(`dart run build_runner build --delete-conflicting-outputs`)再生 `injection.config.dart`。
- **路由** go_router;`app/router.dart` 新增 `/holdings` 分支(列表/详情/表单 BlocProvider)+ 加进 `redirect` goingProtected 白名单。
- **fl_chart** 图表(饼图/sparkline/收益曲线/配置环图);御财设计语言(金 `#b08d57`/衬线/米白/盈绿亏红)。
- **无 i18n**(中文硬编码,御财惯例);**无 candlestick**(holding 非交易 K 线)。
- **测试**:domain/data/bloc 用 bloc_test/mocktail(单元);UI 用 widget test(关键交互)+ `flutter analyze` + `flutter build` 编译验证。
- **commit**:中文 conventional。
- **设计源**:[design-output/holding/](../../../design-output/holding/)(6 界面三端 HTML)+ spec [2026-06-29-holding-ui-design.md](../specs/2026-06-29-holding-ui-design.md)。
- **proto**:10 RPC 在 [holding.proto](../../../yucai/proto/holding/v1/holding.proto),gRPC client 方法 Dart stub 生成。

## File Structure

```
yucai/client/lib/holding/
├── domain/
│   ├── entities/holding_entity.dart      # Holding/Security/HoldingTransaction/GoalLink(Equatable)
│   ├── repositories/holding_repository.dart  # abstract,10 RPC,Either<Failure,T>
│   └── value_objects.dart                # SecurityType/TradeType enum
├── data/
│   ├── holding_repository_impl.dart      # @LazySingleton(as:),_guard
│   ├── holding_remote_ds.dart            # @LazySingleton(),HoldingServiceClient+_retry
│   └── mappers/holding_mapper.dart       # toDomain + 枚举 NAME 映射
└── presentation/
    ├── bloc/{holding_event,holding_state,holding_bloc}.dart
    ├── pages/{holdings,trade_sheet,security,holding_detail,performance,goal_link}_page.dart
    └── widgets/  # fl_chart 图 widget(holding_pie/sparkline/perf_curve)
```
- 前置:`yucai/client/lib/proto/holding/v1/holding.pb*.dart`(重生成)+ `pubspec.yaml`(fl_chart)+ `app/router.dart`(分支)+ `core/di/injection.config.dart`(重生成)。

---

## Task 1: 前置(Dart stub 重生成 + fl_chart pubspec)

**Files:**
- Regenerate: `yucai/client/lib/proto/holding/v1/holding.pb*.dart`
- Modify: `yucai/client/pubspec.yaml`(加 fl_chart)

**Interfaces:**
- Produces: `HoldingTradeRequest.fromAccountId`(Dart 字段)+ fl_chart 依赖。后续所有 task 依赖。

> 基础设施 task(无单测)。验证 = stub 有 fromAccountId + fl_chart 解析 + flutter analyze。

- [ ] **Step 1: 重生成 Dart stub**

前置:`dart pub global activate protoc_plugin` + `protoc`(libprotoc 25+) on PATH。
Run(从 `yucai/`):
```bash
cd yucai && make gen-dart
```
(执行 `proto/gen-dart.sh`:Pub bin 放 PATH + `--plugin=protoc-gen-dart=<全路径>` + `protoc --proto_path=. --dart_out=../client/lib/proto --dart_opt=grpc <所有 .proto>`)
Expected: `holding.pb.dart` 的 `HoldingTradeRequest` 出现 `fromAccountId` 字段 + `HoldingServiceClient` 有 10 RPC 方法。grep `fromAccountId` 在 `holding.pb.dart` 有匹配。

- [ ] **Step 2: 加 fl_chart 依赖**

修改 `yucai/client/pubspec.yaml` dependencies 加(查最新稳定版,~0.69+):
```yaml
  fl_chart: ^0.69.0   # 或最新稳定,flutter pub get 时确认
```
Run:`cd yucai/client && flutter pub get`。Expected: fl_chart 解析成功。

- [ ] **Step 3: flutter analyze + 编译验证**

Run:`cd yucai/client && flutter analyze`。Expected: 无新 error(stub 重生成可能修复/引入类型变化,关注 holding 相关)。

- [ ] **Step 4: Commit**

```bash
git add yucai/client/lib/proto/holding/ yucai/client/pubspec.yaml yucai/client/pubspec.lock
git commit -m "feat(holding-flutter): 重生成 Dart stub(fromAccountId)+ 加 fl_chart 依赖"
```

---

## Task 2: domain(entity + repo abstract + value_objects)TDD

**Files:**
- Create: `yucai/client/lib/holding/domain/entities/holding_entity.dart`
- Create: `yucai/client/lib/holding/domain/repositories/holding_repository.dart`
- Create: `yucai/client/lib/holding/domain/value_objects.dart`
- Test: `yucai/client/test/holding/domain/value_objects_test.dart`

**Interfaces:**
- Produces: `Holding`/`Security`/`HoldingTransaction`/`GoalLink` entity + `HoldingRepository` abstract(10 RPC,`Either<Failure,T>`)+ `SecurityType`/`TradeType` enum。Task 3-4 依赖。

参考 [debt/domain/](../../../yucai/client/lib/debt/domain/)(entity/repo/value_objects 结构 + Equatable)。

- [ ] **Step 1: 写 value_objects + 测试**

`value_objects.dart`:
```dart
enum SecurityType { stock, fund, etf, bond, gold, option, other }
enum TradeType { buy, sell, dividend, split }
```
测试(`value_objects_test.dart`):枚举值 + NAME(用于 mapper 验证)。

- [ ] **Step 2: 写 entity(Equatable)**

`holding_entity.dart`:`Holding`(security_id/quantity/avg_cost_cents/current_price_cents/market_value_cents/unrealized_pnl_cents/pnl_pct/type/currency)、`Security`(id/symbol/name/type/exchange/currency/price_cents)、`HoldingTransaction`(id/security_id/trade_type/quantity/price_cents/fee_cents/trade_date/notes)、`GoalLink`(goal_id/name/backing_holding_id/target_cents/current_market_value_cents/pct/status)。全 `extends Equatable` + `props`。

- [ ] **Step 3: 写 repo abstract**

`holding_repository.dart`(参考 `debt_repository.dart`):
```dart
abstract class HoldingRepository {
  Future<Either<Failure, List<Holding>>> listHoldings({String? accountId});
  Future<Either<Failure, List<HoldingTransaction>>> listHoldingTransactions({String? holdingId});
  Future<Either<Failure, HoldingTransaction>> buy({required String accountId, required String securityId, required String fromAccountId, required double quantity, required int priceCents, int feeCents = 0, required String tradeDate, String? notes});
  Future<Either<Failure, HoldingTransaction>> sell({...同 buy...});
  Future<Either<Failure, HoldingTransaction>> recordDividend({required String securityId, required String incomeAccountId, required double perShareDividend, required String date});
  Future<Either<Failure, HoldingTransaction>> recordSplit({required String securityId, required int ratioFrom, required int ratioTo, required String date});
  Future<Either<Failure, Security>> createSecurity({required String symbol, required String name, required SecurityType type, String? exchange, required String currency});
  Future<Either<Failure, List<Security>>> listSecurities({SecurityType? type});
  Future<Either<Failure, List<Security>>> searchSecurities(String query);
  Future<Either<Failure, void>> updateSecurityPrice(String id, int priceCents);
}
```

- [ ] **Step 4: 跑测试 + flutter analyze**

Run:`cd yucai/client && flutter test test/holding/domain/value_objects_test.dart && flutter analyze`。Expected: PASS + analyze 无 error。

- [ ] **Step 5: Commit**

```bash
git add yucai/client/lib/holding/domain/ yucai/client/test/holding/domain/
git commit -m "feat(holding-flutter): domain(entity + repo abstract + value_objects)"
```

---

## Task 3: data(mapper + remote_ds + repo_impl)TDD

**Files:**
- Create: `yucai/client/lib/holding/data/mappers/holding_mapper.dart`
- Create: `yucai/client/lib/holding/data/holding_remote_ds.dart`
- Create: `yucai/client/lib/holding/data/holding_repository_impl.dart`
- Test: `yucai/client/test/holding/data/{holding_mapper,holding_remote_ds}_test.dart`

**Interfaces:**
- Consumes: Task 1(stub)+ Task 2(domain)
- Produces: `HoldingRepository` 实现(注入 bloc)。

参考 [debt/data/](../../../yucai/client/lib/debt/data/)(mapper NAME 映射 + remote_ds client+_retry + repo_impl _guard)。

- [ ] **Step 1: mapper + 测试(NAME 映射 off-by-one)**

`holding_mapper.dart`:static `toDomain`(HoldingDTO/SecurityDTO/HoldingTransactionDTO → entity)+ `securityTypeFromProto/toProto`、`tradeTypeFromProto/toProto`(**按 NAME switch**,注释警告 off-by-one)。
测试:proto UNSPECIFIED(0)→ domain 默认;BUY/SELL/DIVIDEND/SPLIT 按 NAME 映射;STOCK/FUND/ETF/BOND/GOLD/OPTION 按 NAME。

- [ ] **Step 2: remote_ds + 测试(mocktail mock HoldingServiceClient)**

`holding_remote_ds.dart`:`@LazySingleton()`,构造 `HoldingServiceClient(channel, interceptors:[authInterceptor])`(注入 GrpcClient + AuthRetryCaller,照搬 `debt_remote_ds.dart:28-33`);每 RPC 包 `_retry.call(() async {...})`。`buy/sell` 写 `fromAccountId: fromAccountId ?? ''`(空串=不双写)。
测试(mocktail):mock HoldingServiceClient,验证 buy 调用传 fromAccountId + 返回 mapper toDomain。

- [ ] **Step 3: repo_impl + 测试(_guard)**

`holding_repository_impl.dart`:`@LazySingleton(as: HoldingRepository)`,持 `HoldingRemoteDS`,每方法 `_guard<T>(() async => await _remote.xxx(...))`(照搬 `debt_repository_impl.dart:86`)。
测试:remote 抛 GrpcError → repo 返回 `Left(ServerFailure)`;成功 → `Right`。

- [ ] **Step 4: 跑测试 + analyze**

Run:`cd yucai/client && flutter test test/holding/data/ && flutter analyze`。Expected: PASS + analyze 无 error。

- [ ] **Step 5: build_runner 重生成(注册 @LazySingleton)**

Run:`cd yucai/client && make flutter-build-runner`(或 `dart run build_runner build --delete-conflicting-outputs`)。Expected:`injection.config.dart` 注册 HoldingRemoteDS + HoldingRepositoryImpl。

- [ ] **Step 6: Commit**

```bash
git add yucai/client/lib/holding/data/ yucai/client/test/holding/data/ yucai/client/lib/core/di/injection.config.dart
git commit -m "feat(holding-flutter): data(mapper + remote_ds + repo_impl)"
```

---

## Task 4: bloc(event + state + bloc)TDD

**Files:**
- Create: `yucai/client/lib/holding/presentation/bloc/{holding_event,holding_state,holding_bloc}.dart`
- Test: `yucai/client/test/holding/presentation/bloc/holding_bloc_test.dart`

**Interfaces:**
- Consumes: Task 2-3(domain/data)
- Produces: `HoldingBloc`(6 界面共用)。Task 5-10 UI 依赖。

参考 [debt/presentation/bloc/](../../../yucai/client/lib/debt/presentation/bloc/)(event/state/bloc 三件套 + bloc_test)。

- [ ] **Step 1: event + state**

`holding_event.dart`:`abstract HoldingEvent` + `LoadHoldingsRequested({SecurityType? typeFilter})` / `LoadDetailRequested(id)` / `LoadSecuritiesRequested` / `SearchSecuritiesRequested(query)` + 业务事件 `BuyRequested(BuyParams)` / `SellRequested(SellParams)` / `RecordDividendRequested(DividendParams)` / `RecordSplitRequested(SplitParams)` / `CreateSecurityRequested(SecurityParams)` / `UpdatePriceRequested(id,priceCents)`。Params `extends Equatable`(含 `fromAccountId`)。
`holding_state.dart`:`HoldingInitial/Loading/Loaded(holdings+summary+securities)/DetailLoaded(detail+trades+pnlBreakdown)/Submitting(last)/Error(message,last,isPendingBackend)`。全 Equatable,Error/Submitting 携带 `last`。

- [ ] **Step 2: bloc + bloc_test**

`holding_bloc.dart`:`@injectable`,注入 `HoldingRepository`,`on<EachEvent>`;成功后 `add(LoadHoldingsRequested(filter:_lastFilter))` 自刷新;⏳ RPC(ListHoldingTransactions 等)fail → `emit Error(last: currentList, isPendingBackend: true)`(UI 空态 + ⏳ 标注)。
测试(bloc_test + mocktail mock repo):LoadHoldingsRequested → Loaded;BuyRequested → Submitting→Loaded;ListHoldingTransactions fail → Error(isPendingBackend:true)。

- [ ] **Step 3: 跑测试 + analyze**

Run:`cd yucai/client && flutter test test/holding/presentation/bloc/ && flutter analyze`。Expected: PASS + analyze 无 error。

- [ ] **Step 4: build_runner + Commit**

```bash
cd yucai/client && make flutter-build-runner
git add yucai/client/lib/holding/presentation/bloc/ yucai/client/test/holding/presentation/bloc/ yucai/client/lib/core/di/injection.config.dart
git commit -m "feat(holding-flutter): bloc(event + state + bloc + ⏳ fail 降级)"
```

---

## Task 5: 持仓列表 holdings_page(fl_chart 饼图/sparkline)

**Files:**
- Create: `yucai/client/lib/holding/presentation/pages/holdings_page.dart`
- Create: `yucai/client/lib/holding/presentation/widgets/{holding_pie_chart,holding_sparkline}.dart`

**Interfaces:**
- Consumes: Task 4(HoldingBloc)+ A-od 设计源 [design-output/holding/holdings-{desktop,tablet,mobile}.html](../../../design-output/holding/)
- Produces: 持仓列表页(holding 入口)。

参考 A-od `holdings-*.html` UI(StatCard 4 格 + 饼图 type 占比 + 持仓列表 sparkline + chips + 多币种汇总)+ debt `debts_page.dart`(BlocBuilder 模式)+ `core/widgets`(page_header/data_card/filter_bar/type_tabs)。

- [ ] **Step 1: fl_chart widget(饼图 + sparkline)**

`holding_pie_chart.dart`:fl_chart `PieChart`(type 占比,御财金色板);`holding_sparkline.dart`:fl_chart `LineChart`(迷你走势,无轴)。复用 A-od 配色(`AppColors`)。

- [ ] **Step 2: holdings_page(BlocBuilder<HoldingBloc,HoldingState>)**

StatCard(总市值/成本/盈亏/收益率,fl_chart 饼图)+ chips 筛选(type_tabs)+ 持仓列表(每行 symbol/名称/量/市值/sparkline/盈亏色块)+ 多币种汇总(CurrencyBloc 复用换算)。对齐 A-od `holdings-mobile.html` 布局。空态(BlocBuilder Error/Loaded empty)。

- [ ] **Step 3: widget test + flutter analyze**

widget test:holdings_page 渲染持仓列表 + StatCard + 饼图;chips 筛选触发 event。
Run:`cd yucai/client && flutter test test/holding/presentation/pages/holdings_page_test.dart && flutter analyze`。

- [ ] **Step 4: Commit**

```bash
git add yucai/client/lib/holding/presentation/pages/holdings_page.dart yucai/client/lib/holding/presentation/widgets/ yucai/client/test/holding/presentation/pages/
git commit -m "feat(holding-flutter): 持仓列表页(StatCard+fl_chart 饼图+sparkline+多币种)"
```

---

## Task 6: 交易 Sheet trade_sheet_page(buy/sell/dividend/split + from-account picker)

**Files:**
- Create: `yucai/client/lib/holding/presentation/pages/trade_sheet_page.dart`

**Interfaces:**
- Consumes: Task 4(HoldingBloc:Buy/Sell/RecordDividend/RecordSplit)+ A-od [trade-sheet-*.html](../../../design-output/holding/)
- Produces: 统一交易 form(4 类型)。

参考 A-od `trade-sheet-*.html`(4 类型 segmented + from-account picker + 实时金额 + 余额 fail-fast)+ **debt [receivable_form_page.dart:576](../../../yucai/client/lib/debt/presentation/pages/receivable_form_page.dart)(from-account picker 直接模板:DropdownButtonFormField + `_loadSourceAccounts`:asset 非 otherAsset + 提交校验)**。

- [ ] **Step 1: trade_sheet_page**

4 类型 segmented(buy/sell/dividend/split,字段随类型变):security 选择 + **from-account picker**(照搬 receivable_form `_loadSourceAccounts` + 币种过滤 disabled 跨币种 — 跨币种客户端预校验防线)+ 数量/价格/费用/日期 + 备注;实时金额(price×qty)+ 余额 fail-fast 预览(buy 不足红字);dividend 用 income-account picker;split 用拆分比例。提交 → Bloc buy/sell/recordDividend/recordSplit event。AbsorbPointer(submitting)+ spinner。

- [ ] **Step 2: widget test + analyze**

widget test:4 类型切换 + from-account picker 加载(asset 过滤)+ 提交触发 event + 跨币种 disabled。
Run:`flutter test test/holding/presentation/pages/trade_sheet_page_test.dart && flutter analyze`。

- [ ] **Step 3: Commit**

```bash
git add yucai/client/lib/holding/presentation/pages/trade_sheet_page.dart yucai/client/test/holding/presentation/pages/
git commit -m "feat(holding-flutter): 交易 Sheet(buy/sell/dividend/split form + from-account picker)"
```

---

## Task 7: Security 管理 security_page

**Files:**
- Create: `yucai/client/lib/holding/presentation/pages/security_page.dart`

参考 A-od `security-*.html`(列表 + 搜索 + 创建表单 + 价格管理 行内编辑 + 自动 sync 开关 disabled B)+ debt `debts_page.dart`。

- [ ] **Step 1: security_page**

列表(symbol/name/type/exchange/currency/现价)+ 搜索(实时过滤)+ 创建表单(symbol/name/type/exchange/currency → CreateSecurity event)+ 价格管理(行内编辑 → UpdatePrice event + 自动 sync 开关 disabled + "⏳B" 标注)。

- [ ] **Step 2: widget test + analyze + Commit**

widget test:列表渲染 + 搜索 + 创建表单提交 + 价格编辑。`git commit -m "feat(holding-flutter): Security 管理页(列表/搜索/创建/价格管理)"`

---

## Task 8: 持仓详情 holding_detail_page(收益曲线 + 交易历史 ⏳)

**Files:**
- Create: `yucai/client/lib/holding/presentation/pages/holding_detail_page.dart`
- Create: `yucai/client/lib/holding/presentation/widgets/perf_curve_chart.dart`(fl_chart 收益曲线,Task 9 复用)

参考 A-od `holding-detail-*.html`(摘要 + 收益曲线 + 交易历史 + 配置占比 + 关联目标)+ debt `debt_detail_page.dart`。

- [ ] **Step 1: holding_detail_page**

头部(symbol + 现价 + 刷新)+ 持仓卡(量/成本/市值/盈亏色块)+ fl_chart 收益曲线(日/月/年,`perf_curve_chart.dart`)+ realized/unrealized 前端算 + **交易历史**(ListHoldingTransactions ⏳ → BlocBuilder Error(isPendingBackend) 显示空态 + "⏳ 待后端")+ 配置占比环图(holding_pie_chart 复用)+ 关联目标卡(goal ⏳ 空态)+ 操作(buy/sell/dividend/split → trade_sheet)。

- [ ] **Step 2: widget test + analyze + Commit**

widget test:摘要 + 曲线 + 交易历史 ⏳ 空态 + 操作按钮。`git commit -m "feat(holding-flutter): 持仓详情页(收益曲线+交易历史⏳+配置占比+关联目标)"`

---

## Task 9: 收益统计页 performance_page(snapshot ⏳)

**Files:**
- Create: `yucai/client/lib/holding/presentation/pages/performance_page.dart`(复用 Task 8 perf_curve_chart)

参考 A-od `performance-*.html`(总收益曲线 + realized/unrealized + 年化 + 持仓/类型贡献条)。

- [ ] **Step 1: performance_page**

fl_chart 总收益曲线(日/月/年 + 区间,复用 perf_curve_chart)+ realized/unrealized 分解 + 年化 + 持仓/类型贡献条。snapshot ⏳ → 前端从 ListHoldingTransactions 聚合(⏳ fail 降级空态 + "⏳C 待后端")。

- [ ] **Step 2: widget test + analyze + Commit**

widget test:曲线 + 分解 + ⏳ 空态。`git commit -m "feat(holding-flutter): 收益统计页(总收益曲线+realized/unrealized+年化)"`

---

## Task 10: 投资目标关联 goal_link_page(goal ⏳)

**Files:**
- Create: `yucai/client/lib/holding/presentation/pages/goal_link_page.dart`

参考 A-od `goal-link-*.html`(holding-backed goals 列表 + 关联 holding 选择)。

- [ ] **Step 1: goal_link_page**

holding-backed goals 列表(目标名/关联持仓/市值/目标额/进度条%)+ 关联 holding 选择(goal ⏳ → BlocBuilder Error(isPendingBackend) 空态 + "⏳D 待后端")。

- [ ] **Step 2: widget test + analyze + Commit**

widget test:goals 列表 + ⏳ 空态。`git commit -m "feat(holding-flutter): 投资目标关联页(D:holding-backed goal 进度)"`

---

## Task 11: 路由 + DI 注入 + 闭环验证

**Files:**
- Modify: `yucai/client/lib/app/router.dart`(新增 /holdings 分支)
- Modify: `yucai/client/lib/core/di/injection.config.dart`(build_runner 重生成)

参考 [app/router.dart:216-356](../../../yucai/client/lib/app/router.dart)(debt+receivables branch BlocProvider 写法)。

- [ ] **Step 1: router 新增 /holdings 分支**

`router.dart` GoRouter 加 `/holdings`(列表)、`/holdings/:id`(详情)、`/holdings/security`(security 管理)、`/holdings/performance`(收益)、`/holdings/goals`(目标)、`/holdings/trade`(trade sheet,modal)。各 builder `BlocProvider<HoldingBloc>(create:(_)=>HoldingBloc(getIt<HoldingRepository>())..add(LoadXxxRequested()))`。加进 `redirect` goingProtected 白名单。app_shell 导航加 holding 入口。

- [ ] **Step 2: build_runner 重生成 + flutter analyze + build**

```bash
cd yucai/client && make flutter-build-runner && flutter analyze && flutter build windows --debug  # 或对应平台
```
Expected:analyze 无 error;build 成功。

- [ ] **Step 3: 闭环手动验证(flutter run)**

`flutter run`,走闭环:Security 管理 → 建 security → 交易 Sheet buy(from-account picker)→ 持仓列表(看新持仓)→ 持仓详情(曲线 + 交易历史⏳)→ 收益统计⏳ → 目标关联⏳ → dividend/split。✅ 端点真对接,⏳ 端点空态 + 标注。

- [ ] **Step 4: Commit + 更新 handoff memory**

```bash
git add yucai/client/lib/app/router.dart yucai/client/lib/core/di/injection.config.dart
git commit -m "feat(holding-flutter): 路由 /holdings 分支 + DI 注入 + 闭环验证"
```
更新 memory `holding-asset-management-todo`:A-flutter 完成(6 界面 + DDD 四层,✅ 端点真对接 + ⏳ 降级),holding 资产管理 A 子项目(A-server + A-od + A-flutter)完整。

---

## 范围边界(本 plan 不做)

- drift 本地缓存(御财纯远程惯例)。
- ⏳ 端点后端实现(B/C/D 子项目;A-flutter 调真 proto fail 降级)。
- i18n(中文硬编码)。
- candlestick K 线(B/C 若需再加)。

## 参考

- 设计源:[design-output/holding/](../../../design-output/holding/)(6 界面三端)+ spec [2026-06-29-holding-ui-design.md](../specs/2026-06-29-holding-ui-design.md)
- debt Flutter 模板:[yucai/client/lib/debt/](../../../yucai/client/lib/debt/)(domain/data/presentation/bloc + receivable_form from-account picker)
- A-flutter spec:[2026-06-29-holding-flutter-design.md](../specs/2026-06-29-holding-flutter-design.md)
- proto:[holding.proto](../../../yucai/proto/holding/v1/holding.proto)(10 RPC,from_account_id)
- 工作流:[[od-prototype-to-flutter]](OD 原型作设计源直接产 Flutter)
