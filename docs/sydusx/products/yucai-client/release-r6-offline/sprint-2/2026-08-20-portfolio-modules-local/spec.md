---
feature: 2026-08-20-portfolio-modules-local
status: drafted
---

# Spec — 资产类模块本地化(holding/budget/goal/debt/receivable/report/networth)

> R6 sprint-2 feature E(依赖 A/B/C/D)。范式经 C/D 两轮验证;drift 表/DAO 全备。
> 事实基础(research 2026-08-22):①holding 买卖复式在 **server** 组装(buy=credit from 现金−/debit holding 投资+;sell 反向;**fee 不进现金腿,资本化进 lot 每股成本**;校验:from 为 asset/非同户/同币种/buy 余额充足),本地须镜像;②五类聚合原为 server 计算(marketValue/networth/receivables summary/budget actuals/goal currentAmount);③行情(Yahoo/Sina)与 XIRR/TWR 全在 server,client 无纯 Dart 实现;④**report 无独立层,已随 D 自动落地(零改动)**;⑤receivables=debt 子面(同 repo,typeFilter),仅 summary 独立。

## ADDED Requirements

### Requirement: FR-1 holding 游客全链路(本地复式+成本)
- [ ] Guest 态 holding 的 buy/sell/recordDividend/recordSplit/listHoldings/listHoldingTransactions/securities CRUD+search/updateSecurityPrice SHALL 对本地生效:
  - **buy/sell 在单个 drift 事务内**:holding/lot/流水写入 + **本地复式交易**(entries 按 server 方向表;fromAccountId 必填,镜像四项校验:存在/asset 类型/≠holding 账户/同币种;buy 另校验现金余额充足)。
  - **成本语义镜像**:buy 每股成本=(price×qty+fee)/qty 资本化建 lot;sell 按 **FIFO 消耗 lot**、realizedPnl 扣减 sell fee、avgCost 从剩余 lot 重算。
  - 持仓展示字段(securityName/symbol/marketValue/unrealizedPnl/currentPrice)读时本地合成(securities 表 join + 现价,无现价则按 avgCost 标注陈旧)。

#### Scenario: 断网买入(成功判据①资产面)
- GIVEN Guest,本地有现金账户(余额足额)与证券
- WHEN buy(100 股 × ¥10 + ¥5 fee)
- THEN 持仓 quantity=100、avgCost=1005;流水多一条 buy;**本地交易两条 entries**(现金 credit 1000、投资 debit 1000——fee 不进现金腿);全程零网络

#### Scenario: buy 余额不足被拒
- GIVEN 现金余额 < price×qty
- WHEN buy
- THEN 失败(语义同远端),holding/lot/流水/交易零写入(整包回滚)

### Requirement: FR-2 行情与收益的离线降级(显式)
- [ ] Guest 态 syncPrices 与 getPortfolioPerformance/getHoldingPerformance SHALL 返回明确的 ServerFailure 提示('离线暂不支持行情同步/收益分析')而非假数据;行情快照字段按 FR-1 读时合成降级。**XIRR/TWR/CAGR 的 client 移植 defer**(依赖行情快照,离线无意义;绑定后走远端)。

### Requirement: FR-3 budget 游客全链路(含 actuals 本地聚合)
- [ ] Guest 态 budget 的 list/get/getByMonth/create/delete/addItem/removeItem/update SHALL 对本地生效:items 嵌套子表;update 为**整包替换 items**(镜像远端,无显式 version 参数——远端为隐式乐观锁,本地可观察行为一致即可);**actuals 本地聚合**:按 item.accountId + month 窗口扫本地交易 entries 求和(口径同远端 BudgetActualsService)。

#### Scenario: 游客月度预算实际额
- GIVEN Guest,8 月餐饮账户支出两笔共 5000
- WHEN getBudget(8 月含餐饮 item)
- THEN item.actualAmountCents=5000,usagePct 对应

### Requirement: FR-4 goal 游客全链路(三源 actuals)
- [ ] Guest 态 goal 的 list/get/create/update/delete/complete/recordContribution/clone SHALL 对本地生效:links 联结表双向聚合;update 镜像 patch+**显式乐观锁**;**currentAmount 按类型本地三源聚合**(Savings=Σ 账户余额/Investment=Σ 持仓市值/DebtPayoff=Σ 已还);getProgressHistory 返回空列表(快照 scheduler 为 server 物,记 accepted 简化)。

### Requirement: FR-5 debt/receivables 游客全链路(还款复式)
- [ ] Guest 态 debt 的 list/get/create/update/delete/recordPayment/upcomingPayments SHALL 对本地生效:schedule 嵌套子表;update 显式乐观锁;**recordPayment 本地复式**(borrowedIn:credit from+debit debt 账户;borrowedOut 反向)+ schedule 行 paid/paidCents 更新,单事务;**borrowedOut create 双写**(credit source 现金−/debit receivable+);receivables 页(同 repo typeFilter)自动继承;**ReceivablesSummary 本地聚合**(borrowedOut 全量 14 字段口径)。

### Requirement: FR-6 networth 本地三源聚合
- [ ] NetWorthDataSource SHALL 双源化:Guest 态 getNetWorth 本地计算(Σ资产账户余额 + Σ持仓市值 − Σ借入负债 remaining;折算 base currency 用本地汇率,标注陈旧),绑定态走远端原样。

### Requirement: FR-7 范式遵循 + report 零改动记录
- [ ] 各模块遵循 C/D 范式(local ds @LazySingleton 注册 + repo 一行路由 + 写语义镜像 + 路由测试);**report 零改动**(直连 TransactionRepository.summary,已随 D 落地);bloc/pages 零改动(被改类自身测试随构造器更新除外)。

### Requirement: NFR-1 质量基线
- [ ] `flutter test` 基线不退化(≤ 4 fail / 3 文件);`flutter analyze` 不新增;data 层不 import presentation。

### Requirement: NFR-2 零 server 改动
- [ ] 本 feature SHALL NOT 改动 yucai/server;`go test ./...` 保持全绿。

## scope boundary

- **IN**:holding(含复式/FIFO/校验镜像/展示合成)/budget(+actuals)/goal(+三源)/debt+receivables(+还款复式+summary)/networth(+三源)五面双源化;行情与收益显式降级。
- **OUT**:XIRR/TWR/CAGR client 移植(defer,依赖行情)/行情缓存队列(YAGNI)/progress history 与 holding/debt/goal 快照 scheduler 的本地模拟(空/读时合成,accepted)/派生快照表的写路径(sprint-1 A 已记 open question,维持读时合成)/绑定后镜像(H)。
- **依赖**:A(drift 表/DAO)/B(Guest)/C(tracker+范式)/D(transaction local ds 的复式写入与 summary 口径——holding/debt 复式直接复用)。

## 可行性

- **technical**:可行——表/DAO/复式基建全备;最大新面是 holding FIFO 成本引擎与五处聚合,均为本地纯计算;行情降级为显式失败,无外部依赖。
- **economic**:可行——范式第 3 轮复制,边际成本递减;holding 是最后一块重头。
- **operational**:可行——纯 client;guest 行情缺失以明确提示呈现,无静默错误。
