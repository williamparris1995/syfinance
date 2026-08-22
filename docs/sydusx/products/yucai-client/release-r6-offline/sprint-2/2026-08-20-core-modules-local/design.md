---
feature: 2026-08-20-core-modules-local
status: confirmed
---

# Design — 核心记账模块本地化(transaction/tag/template/currency)

> 消费 [spec.md](spec.md)(confirmed)。**server 语义提取(2026-08-22,照抄依据)**:
> ① Simple* 借贷方向(BuildSimpleEntries(amount, debit, credit),service.go:324/352/384):**income=借 asset 贷 income;expense=借 expense 贷 asset;transfer=借 to 贷 from**。
> ② summary 口径(transaction_repo.go:611-614 CASE):**income 型账户的 credit 计收入;expense 型账户的 debit 计支出;其余类型 0**;byDay 按 transaction_date;byCategory=account 粒度。
> ③ AdvanceNextDate(record_port.go:22-37,record 推进即此):weekly +7d/monthly +1 月(AddDate 直加)/yearly +1 年/custom +cycleDays/未指定不变。

## Context

sprint-2 首役:按 C 范式复制到四个核心模块。drift 表/DAO 全备(A);tracker/Uuid DI 就位(C)。category 零改动(account 视图子集,spec 修正)。

## Goals / NonGoals

- **Goals**:transaction(9 方法含聚合)/tag(7)/template(8 含 record 联动)/currency(list+bloc 分支)双源化 + 静态种子。
- **NonGoals**:category(自动继承)/镜像(H)/上传(G)/汇率在线刷新/summary 全量对拍 e2e(feature I)。

## Decisions(ADRs)

### ADR-1 transaction local ds:Simple* 组对 + 嵌套事务性写入
- **Decision**:`TransactionLocalDataSource` 镜像 9 方法。Simple* 按上表方向组两条 entries(复式校验:恰一 debit/credit>0);recordTransaction 原样落;**头+子表写入包在 drift `transaction(() {...})` 内**(update=同事务内旧 entries 全删再插 + 乐观锁前置);delete 走 FK cascade。
- **Rationale**:与 server 单 RPC 原子语义对齐;entries 中途失败整包回滚(FR-3 场景 2)。
- **Alternatives**:分步写无事务——半事务状态,拒绝。

### ADR-2 list 分页模拟:typeFilter 语义复制
- **Decision**:本地全量按 transactionDate 倒序(+id 稳定序)→ 过滤(accountId/dateFrom/dateTo/typeFilter 同 remote 的客户端推断)→ **offset 型游标切片**(nextPageToken=字符串化 offset,hasMore/totalCount 同语义)。typeFilter 复用 remote ds 的 flavour 推断逻辑(提为共享纯函数或复制,design 执行时按重复度定)。
- **Rationale**:单用户数据量下全量内存排序足够;游标语义与远端可观察一致。
- **Alternatives**:键集分键(date+id cursor)——数据量不支持必要,YAGNI。

### ADR-3 summary 本地聚合:CASE 口径镜像
- **Decision**:读窗口内 transactions join entries join accounts(本地三表内存 join),每 entry 金额 = income 型→credit / expense 型→debit / 其余→0;按日分桶 byDay、按 account 分桶 byCategory(accountType 带 out);scope 窗口 day=当日/month=整月/year=整年(与 server SummaryScope 对齐);accountId 过滤=entry 维度命中即整笔计入(与 server accountScopeClause 一致)。
- **Rationale**:口径逐字照抄 server SQL,oracle 测试钉死核心场景。

### ADR-4 template record 联动:本地建交易 + AdvanceNextDate 照抄
- **Decision**:record(templateId) 在**单个 drift 事务**内:①按模板 direction 组 entries(direction 映射 Simple* 方向表:expense=借 category 对应 expense 账户 贷 source;income 反向;transfer=借 destination 贷 source)落一笔交易(transactionDate=nextDate);②nextDate=AdvanceNextDate(nextDate, cycle, cycleDays)(规则照抄③);③version+1。幂等键(template,date)本地不建(单写者 guest,server 的 UNIQUE 防调度重试——client 手动触发无此竞态,记 accepted 简化)。
- **Rationale**:与 server record 的可观察行为一致(建交易+推进);幂等保护针对 server 调度场景。
- **Alternatives**:也建本地 record_log 表——防不存在的竞态,YAGNI。

### ADR-5 currency:静态种子 + repo 补 guard + bloc guest 分支
- **Decision**:`CurrencyLocalDataSource.list()` 读 drift Currencies;**首次(guest)读时若空则播种内置静态表**(常用 ~10 币种 code/name/symbol/rate=1.0 除基准,标注陈旧由 UI 层处理);绑定态走远端(现有)。`CurrencyRepositoryImpl` 重写为 account 式 _guard(GrpcError 分类 + on Failure 透传)。`CurrencyBloc` 注入 SessionModeTracker:guest 时 preferred=CurrencySettings.value、intervalHours=24,两条 RPC 不发。
- **Rationale**:种子解决"guest 无处拉列表";bloc 分支避免两条直连 RPC 在 guest 报错(FR-5)。

### ADR-6 tag/template 接线:_guard 补透传
- **Decision**:两模块 repo `_guard` 补 `on Failure` 透传分支(对齐 account),remote 路径行为不变;构造器 +local +tracker 一行路由(C 范式)。

## HLD

```
新增 local ds(4):transaction/data/transaction_local_ds.dart(最大)
                  tag/data/tag_local_ds.dart
                  template/data/template_local_ds.dart
                  currency/data/currency_local_ds.dart(含静态种子)
改 repo(4):transaction/tag/template/currency _repository_impl(+local +tracker 路由 + guard 对齐)
改 bloc(1):currency_bloc(+tracker guest 分支)
零改动:domain 接口/remote ds/其余 bloc/pages/category 全链
```

## LLD 要点

### TransactionLocalDataSource 方法映射

| repo 方法 | 本地行为 |
|---|---|
| recordExpense/Income/Transfer | 方向表组 2 entries → _insertWithEntries |
| recordTransaction | params.entries 原样(逐条校验互斥)→ _insertWithEntries |
| list | 全量倒序→过滤→offset 切片 |
| getById | 头+entries 组装(entries 二次查询) |
| update | 乐观锁→同事务:头 update + entries delete-then-insert |
| delete | FK cascade |
| summary | ADR-3 聚合 |

`_insertWithEntries`:drift transaction 内 insert 头(UUID/version=1/时间戳)→ 循环 insertEntry(entry id 空→UUID)。

### 方向表(照抄 server)

| 操作 | debit | credit |
|---|---|---|
| expense | expenseAccount(category) | assetAccount |
| income | assetAccount | incomeAccount |
| transfer | toAccount | fromAccount |

### 聚合伪码(ADR-3)

```
entries = window 内全部 (txn join entry join account)
amount(e) = e.account.type==income ? e.credit : (e.account.type==expense ? e.debit : 0)
incomeCents = Σ amount; expenseCents 同口径;net = income-expense
dailyAvg = income/当月天数(与 server 对齐,执行时核对)
byDay: 按 txn.transactionDate 分桶;byCategory: 按 entry.account 分桶(name/type)
```

### 静态种子表(currency)

CNY(¥,1.0)/USD($,1.0)/EUR(€,1.0)/GBP/JPY/HKD/TWD/KRW/SGD/AUD——rate 全 1.0 占位(陈旧),绑定首连远端 list 覆盖。

### 测试计划

- transaction_local_ds_test:Simple* 方向 oracle(2 entries 借贷对)/嵌套事务回滚(坏 accountId)/update 整包替换+乐观锁/分页切片+typeFilter/summary 口径 oracle(§ADR-3 场景)。
- tag/template/currency local ds 测试:CRUD/乐观锁/record 联动(建交易+nextDate 推进各 cycle)/种子播种幂等。
- repo 路由测试 ×4(guest 本地/会话远端/切换),对齐 C 的模式。
- currency_bloc guest 分支测试;既有各模块测试零改动回归。

## Risks

- **R1 summary 口径细节偏差**(dailyAvg 分母/边界日)**——oracle 测试覆盖核心;全量对拍归 feature I e2e。
- **R2 monthly AddDate 直加**在月末(1.31→2.31→3.31?)Dart AddDate 与 Go 同为 clamp 到月末——行为一致,测试钉 1/31 场景。
- **R3 时间口径**:server 按日截断窗口(UTC vs 本地)——本地实现统一 UTC(与 drift 存储 UTC 一致),测试钉跨月边界。

## Migration

纯新增;无数据迁移。injectable 重新生成(4 repo 构造器扩展)。

## Open Questions

1. typeFilter flavour 推断逻辑是否值得提共享(重复度执行时判断,若复制则记 ledger)。
2. 汇率陈旧标注的 UI 呈现(货币下拉旁提示)——F 的断网 UX 一并处理。
