# 事务一致性架构 · Design Spec

- **日期**:2026-07-26
- **关联**:御财审计 wayfinder [03 事务一致性架构](../../../.scratch/yucai-audit/issues/03-transactional-architecture.md)、[04 备份恢复可靠性](../../../.scratch/yucai-audit/issues/04-backup-restore-reliability.md)(04 依赖本 spec 的阶段 A)
- **状态**:设计已确认,待 writing-plans 出实施 plan
- **scope**:阶段 A(基础设施)+ B(P0 四处写事务化)+ C(autoRecord 幂等键)。**D(JIT provisioning S10,P1,auth 模块)拆为独立小 plan**,与 `auth-oidc-migration` 的 jit provisioning tx 原子性 followup 合并。

## 1. 背景与问题

御财 server 当前**跨模块财务写无原子性保证**(审计 D7 根因 + D1/D2/D3/D4)。

**根因(D7)**:每个业务模块(auth/account/transaction/budget/debt/goal/tag/template/holding)是**独立 ent codegen**(各自 `package ent`、各自 `Client`/`Tx`/`txDriver`),且 wire 里每个模块各自 `sql.Open("pgx", cfg.DatabaseURL)` 打开**独立 `*sql.DB`**(`wire/providers.go:103` `openEntDriver` 被 9 个 `provide*EntClient` 调用)。独立 ent 包意味着 `*budgetent.Tx` 与 `*transactionent.Tx` 是不同类型、不可共享;独立 `*sql.DB` 意味着没有公共底层 tx 通道。整个 server 仅 1 处手写 ent tx(`budget_repo.go:172-225`,`client.Tx(ctx)` 单模块内 Budget+BudgetItem 多表原子),**跨模块写全是 best-effort swallow**。

**四处 P0 失效**:
- **D1** 交易创建(`transaction/application`+`transaction_repo.go:79-109`+`balance/updater.go`):header + N entries + 余额更新 = N+1+M 独立写,崩溃即复式记账破缺 / Transfer split-brain。balance updater 注入 accountRepo(跨 transaction→account)。
- **D2** holding 交易(`holding/application/service.go:92-147` BuyHolding/SellHolding + handler):`holdingRepo.SaveOrUpdate`+`tradeRepo.Save`+`lotRepo.SaveAll`(holding 同包 3 写)+ handler 层经 recorder port 调 transaction 扣现金(handler 注释 "trade not rolled back"),5 写 fan-out。
- **D3** debt 还款(`debt/application/service.go:235-263`+`debt_handler.go`):schedule.Paid+principal 落库(debt)+ 现金 RecordTransaction(transaction)best-effort 吞错 → 债标已还但现金未扣 → 净资产虚高。
- **D4** template autoRecord(`template/application/service.go:180-218`+`scheduler/scheduler.go:88-114`):recorder 记账(transaction)+ NextDate 推进(template)非原子 → crash 重复记账;两 scheduler 实例 → TOCTOU 双扣。

## 2. 目标与非目标

**目标**:建一套统一的跨模块事务抽象,把 P0 四处财务写包成原子事务,并补 autoRecord 幂等键防并发/crash 重试。unblock 04(备份恢复的快照隔离 + 原子 restore 复用本 spec 的共享 `*sql.DB` + TxContext 基础设施)。

**非目标(明确排除)**:
- outbox / saga / 对账 job(03 决策不引入;统一同步 tx 解决根因,御财单 server 不需要)。
- 04 的 D5 backup `REPEATABLE READ` 快照隔离 / D6 restore 原子化 / D12 写冻结(属 04,本 spec 只提供它们依赖的 `sqltx` 基础设施,隔离级别由调用方传 `sql.TxOptions`)。
- 全部跨模块写事务化(只 P0 四处;其余跨模块写渐进)。
- D(JIT provisioning S10,P1,auth 模块)——拆独立小 plan。

## 3. 设计决策(brainstorming 确认)

| 决策 | 选定 | 理由 |
|---|---|---|
| tx 接入形态(Q1) | **(A) application service 层开 tx + repo `clientFor(ctx)` helper** | 最小侵入、显式、向后兼容(ctx 无 tx → 默认 client);budget 单模块 tx 范式的跨包延伸 |
| plan scope(Q2) | **(a) A+B+C,D 拆后续** | A+B 是 P0 财务写核心;C 与 B template 同模块顺带;D 跨 auth 模块且 P1,独立 |
| 测试策略(Q3) | **(a) SQLite 主测 + Postgres e2e** | 原子性 SQLite 可测;真实 pg 验证共享 db 连接池行为;不引 testcontainer 重基建 |
| autoRecord 幂等键(C) | **(Y) 独立 `template_record_log` 表** | 职责清晰、不污染 transaction 表、兼审计;与统一 tx 协同(log unique 冲突→整 tx 回滚)。03 Answer 字面的 "template 表 unique" 语义错(否决) |
| ctx 载体 | 携带 `dialect.Driver`(tx driver) | repo helper 一行拿 driver;ctx value 只 repo 层取,repo 已依赖 entgo |
| commit 粒度 | 细粒度,每步 build+test 绿 | 易回滚、易 review、降低 wire 手改风险 |

## 4. 核心机制

### 4.1 共享 `*sql.DB`

新增单例 provider `provideDB(cfg) (*sql.DB, error)`,9 个 `provide*EntClient` 改用它(替代各自 `openEntDriver` 独立 `sql.Open`)。所有 ent client 底层连同一 `*sql.DB` → `db.BeginTx()` 得到的 `*sql.Tx` 可注入任意模块 ent client。

`provideDB` 设保守连接池参数(私域单机负载):`SetMaxOpenConns(25)` / `SetMaxIdleConns(5)` / `SetConnMaxLifetime` 适当。**副作用**:连接池从 9 个独立池变为 1 个共享池——Postgres e2e 验证。

### 4.2 新公共包 `server/internal/sqltx`

```go
// WithTx 在 db 上开 tx,包装成 dialect.Driver 注入 ctx,跑 fn。
// fn 返 nil → Commit(失败返 commit err);返 err → Rollback(忽略 rollback err,返原 err);panic → Rollback + re-panic。
func WithTx(ctx context.Context, db *sql.DB, opts *sql.TxOptions, fn func(context.Context) error) error
// 03 调用方传 opts=nil(默认隔离);04 D5 传 REPEATABLE_READ+ReadOnly —— 同一基础设施复用。

// DriverFrom 从 ctx 取 tx driver(若有)。
func DriverFrom(ctx context.Context) (dialect.Driver, bool)
```

内部 `txDriver` 实现 `entgo.io/ent/dialect.Driver`:`Exec/Query` 转发 `*sql.Tx`;`Tx()` 返回自身(nop,防嵌套开 tx);`Close()` nop;`Dialect()` 返回 `"postgres"`。**与 `budget/ent/tx.go` 的 codegen `txDriver` 同构**,只是从 ent 包提取成跨包公共版。因 `dialect.Driver` 是 entgo 公共接口,一个 txDriver 实例可喂给任意模块的 `moduleEnt.Driver(d)`。

### 4.3 repo `clientFor(ctx)` helper

每模块一份(返回类型不同,各写):

```go
func (r *HoldingRepo) clientFor(ctx context.Context) *holdingent.Client {
    if d, ok := sqltx.DriverFrom(ctx); ok {
        return holdingent.NewClient(holdingent.Driver(d)) // tx-bound
    }
    return r.client // 默认,非事务路径
}
```

**向后兼容是关键**:ctx 无 tx → 默认 client,所有现有非事务调用零改动。P0 写方法把 `r.client.X` 改 `r.clientFor(ctx).X`;只读方法本 spec 不动(04 D5 才需只读 tx)。

## 5. 阶段 A · 基础设施(零行为变化)

**验收**:`go build ./...` + `go test ./...` 全绿,零行为变化(纯结构重构)。

落地步骤:
1. `provideDB(cfg)` 单例(`sql.Open("pgx", cfg.DatabaseURL)` + 池参数)。
2. 9 个 `provide*EntClient` 改签名 `(cfg)` → `(cfg, db *sql.DB)`(或纯 `(db)`);内部 `entsql.OpenDB(dialect.Postgres, db)` → `NewClient(Driver(drv))`。删 `openEntDriver` 各自 Open。
3. `provideTransactionRepo` 的 `db`(现状从 `provideTransactionDB` 独立 Open)切到 `provideDB` 单例,消除最后重复 Open。
4. P0 模块 repo(holding/transaction/debt/template/account)定义 `clientFor(ctx)` helper(本阶段定义,**写方法暂不改用**,阶段 B 启用)。
5. `sqltx` 包落地(`WithTx`/`DriverFrom`/txDriver)+ 单元测。

**`wire_gen.go` 手改(CLAUDE.md 约束 2,本阶段最高风险点)**:
- 新增 `provideDB` provider 声明,**置于所有 `provide*EntClient` 之前**(消费方在依赖方之后声明)。
- 9 个 client provider 签名改 + 注入 `db`;`provideTransactionRepo` db 源切换。
- **每改一个 provider → 立即 `go build ./cmd/server` 验证**,顺序敏感,不跑 wire CLI。

## 6. 阶段 B · 四处 P0 写事务化 + tx 传播链

**编排形态**:每个 P0 写的**编排 service**(holding/debt/template/transaction)持有 `*sql.DB`,方法内 `sqltx.WithTx`;tx 经 ctx 传播到**整条写链所有下游 repo 写方法**的 `clientFor(ctx)`。

⚠️ `clientFor` 不只加在直接改的表 repo,而是**整条 P0 写链涉及的所有 repo 写方法**都要 `r.client → r.clientFor(ctx)`(机械但面广,阶段 B 主要工作量)。**漏改自带防漏网**:B 的"部分失败回滚"测里,漏改的写不会回滚 → 测试红。

| | 编排 service | tx 内涉及模块/repo | 现状痛点 |
|---|---|---|---|
| **D1** 交易创建 | `transaction.CreateTransaction` | transaction(header+entries)+ account(余额 via balance updater) | N+1+M 独立写 |
| **D2** holding 交易 | `holding.BuyHolding`/`SellHolding` | holding(持仓)+ trade + lot + transaction(现金 via recorder port) | "trade not rolled back",5 写 fan-out |
| **D3** debt 还款 | `debt` 还款 | debt(schedule/principal)+ transaction(现金 via recorder port) | best-effort 吞错 |
| **D4** template autoRecord | `template` autoRecord | transaction(记账 via recorder port)+ template(NextDate 推进) | 重复记账 |

**关键改造点**:
- D2/D3/D4 经 `TransactionRecorderAdapter` port(`provideTransactionRecorderAdapter`)调 transaction——adapter 背后的 `transaction_repo` 写方法必须 `clientFor`,才能加入调用方 tx。recorder port 接口不变(仍传 ctx)。
- D1 的 `balance updater`(注入 accountRepo)操作 account——`account_repo` 写方法 `clientFor`。
- 删 handler 层 "trade not rolled back"/best-effort 吞错注释与逻辑,改 service 层原子。
- D2 tx 编排在 **service 层**(holding service 持 db 开 tx,经 recorder port 传到 transaction),非 handler 层。

## 7. 阶段 C · autoRecord 幂等键(`template_record_log` 表)

阶段 B 统一 tx 解决 recorder+NextDate 原子,但**并发**(两 scheduler 实例 / scheduler+手动同 template 同日期)tx 解不了。C 是防并发/crash 重试最后一道,与 B tx 协同。

**新表**:

```
template_record_log
  id            uuid pk
  tenant_id     uuid
  template_id   uuid
  record_date   date        -- 本次记账对应的调度日期
  transaction_id uuid       -- 关联记出的 transaction
  created_at    timestamptz
  UNIQUE (tenant_id, template_id, record_date)
```

**流程**:autoRecord 在 B 的同一 tx 内 → `logRepo` 用 `OnConflictDoNothing` 插 log(**affected rows=0 → 已记,安静跳过,tx 空提交**;=1 → 继续)→ 记 transaction(回填 transaction_id)+ 推进 template.NextDate。log 兼做审计(何时为哪 template 记了哪笔)。

**落地**:
- 新 ent schema `template_record_log` + ent regen(CLAUDE.md 约束 5,固定 codegen 版本 + diff 审查)。wire 不受影响(schema regen,非 wire)。
- template 模块加 `template_record_log_repo`,autoRecord service 在 WithTx 内调它。

## 8. 错误处理

- `WithTx` 统一 commit/rollback/panic-safe;P0 四处的 repo 写方法照常返 error,**无需手动 Rollback**(budget 范式里的 `_ = tx.Rollback()` 是同包 tx 手动管理;新代码用 WithTx 封装不再需要)。`budget_repo.go` 本身不动(已是单模块原子,不在 P0 四处)。
- handler `mapError` 不变:service 返回的 error 语义不变(只是现在原子),gRPC status code 映射不动。
- C 的幂等判定:`logRepo` 用 `OnConflictDoNothing` 检查 affected rows:0 → 已记,autoRecord service 安静跳过 + slog Info(非真错,不映射 gRPC error);=1 → 继续记 transaction + 推进 NextDate。

## 9. 测试策略(SQLite 主测 + Postgres e2e)

- **阶段 A**:
  - `sqltx` 单元测:WithTx commit/rollback/panic-safe;txDriver Exec/Query 转发;DriverFrom 有/无。
  - 集成测(SQLite):共享 db 两模块 ent client 同 tx 写,模拟中间失败 → 全回滚(验证 tx 传播链)。
- **阶段 B**(每处):"部分失败回滚"测——注入一个 repo 失败,验证前面写未落库(漏改 clientFor → 测试红,自带防漏网)。D2/D3/D4 验证编排 service 开的 tx 经 ctx 传到 transaction_repo。
- **阶段 C**:同 `(template,record_date)` 二次 autoRecord → log unique 冲突 → 无重复 transaction。
- **Postgres e2e**(复用 grpcurl 框架):D2 holding buy 中途失败 → holding+transaction+account 全回滚;验证共享 db 连接池真实 pg 行为。

SQLite 够测原子性(支持 tx+rollback、UNIQUE 冲突、共享 `*sql.Tx` 注入多 ent client);REPEATABLE READ 隔离级别语义属 04(本 spec 用默认隔离)。

## 10. commit 粒度

每步 build+test 绿,独立可回滚:

1. **A1** `provideDB`+9 client 改+`provideTransactionRepo` db 切+`wire_gen.go` 手改
2. **A2** `sqltx` 包+单元测
3. **A3** repo `clientFor` helper(定义未启用)+tx 传播集成测
4. **B1** D1 交易创建事务化+测
5. **B2** D2 holding 事务化(含 recorder port 的 `transaction_repo` clientFor)+测
6. **B3** D3 debt 还款事务化+测
7. **B4** D4 template autoRecord 事务化(含 NextDate)+测
8. **C1** `template_record_log` schema+ent regen+repo+幂等检查+测
9. **e2e** Postgres 跨模块 tx 回滚用例

## 11. 风险与缓解

1. **`wire_gen.go` 手改顺序错**(最高风险)→ 每改一个 provider 立即 `go build`;镜像现有 provider 声明顺序(CLAUDE.md 约束 2);`provideDB` 置所有 client provider 前。
2. **共享 db 连接池 9→1 行为变化** → `provideDB` 保守池参数 + Postgres e2e 验证;关注死锁/连接耗尽。
3. **tx 传播链漏改 repo 写方法** → B 的"部分失败回滚"测自带防漏网。
4. **ent txDriver 跨包正确性**(公共 txDriver 与 codegen 细微差异)→ `sqltx` 单测 + 集成测(两模块同 tx 回滚)覆盖;参照 `budget/ent/tx.go` codegen 实现。
5. **向后兼容回归**(clientFor 无 tx 路径)→ 现有非事务测试全绿即证。
6. **C1 ent schema regen** → 固定 codegen 版本 + regen 后 diff 审查。

## 12. 关联

- wayfinder 决策:[03](../../../.scratch/yucai-audit/issues/03-transactional-architecture.md)(本 spec 锁方向)、[04](../../../.scratch/yucai-audit/issues/04-backup-restore-reliability.md)(依赖本 spec 阶段 A)。
- 单模块 tx 范式参照:`budget/adapter/driven/repository/budget_repo.go:172-225` + `budget/ent/tx.go`(codegen txDriver)。
- CLAUDE.md 约束:② wire_gen.go 手改、⑤ ent schema regen、⑥ interface 加方法 grep 全 implementer。
- follow-up:D(JIT provisioning S10,auth 模块)拆独立小 plan,与 `auth-oidc-migration` 合并。
