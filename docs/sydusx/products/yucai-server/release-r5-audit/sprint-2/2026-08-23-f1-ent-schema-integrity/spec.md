---
feature: 2026-08-23-f1-ent-schema-integrity
status: confirmed
---

# Spec — ent schema 完整性(FK+Min(0)+UNIQUE+Immutable+partial unique)

> R5 sprint-2 feature E(05 决策 1/2/4/5 前半)。现状(research 2026-08-23):全仓仅 1 对 edge(User→UserIdentity,无 OnDelete 注解);金额字段零 Min(0);4 项 UNIQUE 均缺;软删 4 表中 budget/tag 的 unique 不含 deleted_at;FK 列仅 tenant_id Immutable;`entsql.OnDelete`/`IndexAnnotation.Where` 全仓零先例(本 feature 首例)。

## ADDED Requirements

### Requirement: FR-1 模块内 parent-child FK edge + OnDelete
- [ ] 下列**已有 FK 列**的模块内父子对 SHALL 加 ent edge(父 `edge.To`+子 `edge.From(...).Field(...).Required()`)并带 `entsql.OnDelete(entsql.Cascade)`:budget↔BudgetItem、transaction↔TransactionEntry、holding↔HoldingLot、debt↔PaymentSchedule、debt↔DebtProgressSnapshot、goal↔GoalProgressSnapshot、holding(security)↔SecurityPriceHistory、template↔TemplateRecordLog。
- [ ] **HoldingTransaction↔Holding 不加**(schema 无 holding_id 列,逻辑关联走 (tenant,account,security)——加列+回填超 05 scope,记 defer;跨模块 orphan 由 feature F 的引用拒绝兜底)。
- [ ] goal links 表**不加**(schema 注释明示设计不用 edge——跨模块)。

#### Scenario: 硬删父行级联子行
- GIVEN 一个 budget 及其 2 个 items(DB 层直删父行)
- WHEN 硬删除该 budget
- THEN DB 级联删除 2 个 items(不依赖 app 层)

### Requirement: FR-2 金额字段 Min(0)
- [ ] 下列字段 SHALL 加 `field.Min(0)`(builder-level 校验,新写入生效,无 DDL):debt.total_principal_cents;payment_schedule.principal/interest/total/paid_cents;transaction_entry.debit/credit_cents(与既有 DB CHECK 的 >0 语义对齐);budget.total_amount_cents;budget_item.planned/actual_amount_cents;holding_transaction.price/fee/amount_cents·quantity;holding_lot.price_cents·quantity·remaining_quantity;goal.target_amount_cents。
- [ ] 余额/PnL/快照类字段 SHALL NOT 加(可负语义:account 两余额、realized/unrealized_pnl、goal.current_amount、snapshot 各字段)。

#### Scenario: 负金额写入被 builder 拒绝
- GIVEN 新建一笔 payment schedule
- WHEN principal_cents = -100
- THEN ent builder 校验失败返回 validator 错误

### Requirement: FR-3 UNIQUE 4 项
- [ ] SHALL 加:Backup.filename(`index.Fields("filename").Unique()`,全局);BudgetItem.(`budget_id`,`account_id`) 复合(替换前缀冗余的 budget_id 单列索引);PaymentSchedule.(`debt_id`,`payment_date`) 复合(同理)。
- [ ] User.email SHALL 加 **partial unique**(`Where: "email <> ''"`——字段 Default("") 存量可能多行空串,裸 unique 必撞)。
- [ ] DDL 类改动(unique/FK)的**存量数据兼容**:启动前 SHALL 提供一次性核查/清理 SQL 脚本(`scripts/` 下,清 email 空串重复/旧时间戳 filename 重复/复合键重复/孤儿行),文档说明先跑后启动(auto-migrate 遇重复即启动失败——这是约束不是可选项)。

#### Scenario: 同预算同账户重复 item 被 DB 拒绝
- GIVEN budget B1 已有 item(budget=B1, account=A1)
- WHEN 绕过 app 层直插第二行(B1, A1)
- THEN unique 违例,DB 报错

### Requirement: FR-4 软删表 partial unique
- [ ] budget.(tenant_id,month) 与 tag.(tenant_id,name) 的 unique SHALL 改 **partial**(`Where: "deleted_at IS NULL"`)——软删行不占额度,同月/同名可重建。

#### Scenario: 软删 budget 后同月重建
- GIVEN budget(tenant=T, month=2026-08) 软删(deleted_at 非空)
- WHEN 重建 (T, 2026-08)
- THEN 成功(软删行不参与唯一判定)

### Requirement: FR-5 FK 列 Immutable
- [ ] 下列 FK 列 SHALL 加 `.Immutable()`:transaction_entry.transaction_id/account_id;budget_item.budget_id/account_id;payment_schedule.debt_id/transaction_id;holding.account_id/security_id;holding_transaction.account_id/security_id/transaction_id;holding_lot.holding_id/security_id/acquired_trade_id;debt_details.account_id;template_record_log.template_id/transaction_id;transaction_template.source/destination_account_id;security_price_history.security_id;transaction_tag.transaction_id/tag_id。
- [ ] 既有业务路径 SHALL 不受影响(整行替换式更新不受列级 Immutable 影响——单测回归验证;有改写需求的路径若被测试暴露,记录并复议该列)。

### Requirement: NFR-1 质量基线
- [ ] `go test ./...` 61 包全绿(生成物重跑后);schema 级测试:负金额拒绝/重复唯一拒/partial unique 行为(sqlite 测试库——partial index Where 语法 SQLite 兼容性需验证,不兼容则该测试 PG-only skip 记 ledger)。

### Requirement: NFR-2 scope 排除
- [ ] SHALL NOT 做:跨模块 FK(决策明示不加)/ HoldingTransaction.holding_id 列(defer)/ TimeMixin(→10)/ SyncLog·SyncDevice unique(→16)/ F12-F13 / DB CHECK(决策 2:builder-level 即可)。

## scope boundary

- **IN**:约 8 对 edge+Cascade/约 15 字段 Min(0)/4 项 unique(1 partial)/2 处 partial unique 化/约 20 列 Immutable/存量清理 SQL+文档/全模块 codegen 重跑。
- **OUT**:见 NFR-2;feature F 的 DeleteAccount 引用拒绝。
- **依赖**:无(D6 已 merge;restore purge 硬删与 Cascade 兼容——级联删与 purge 的 DeleteByTenant 并存不冲突)。

## 可行性

- **technical**:可行——全部 schema 文件改动+codegen;首例注解(OnDelete/Where)按 ent v0.14 文档;存量兼容是最大风险(私域单机数据量小,核查脚本可行)。
- **economic**:中——约 12 文件+12 模块 regen;测试回归面广但机械。
- **operational**:可行——升级前跑一次清理脚本(私域单步操作)。
