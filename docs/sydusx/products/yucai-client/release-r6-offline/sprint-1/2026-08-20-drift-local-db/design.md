---
feature: 2026-08-20-drift-local-db
status: drafted
---

# Design — drift 本地库落地

> 消费 [spec.md](spec.md)(confirmed)。契约源事实(2026-08-20 research):8 模块 backup payload = 领域结构体 json.Marshal(PascalCase key、int 枚举、RFC3339Nano 时间、金额一律 int64 分);**PK 全部是 uuid.UUID**(勘误 spec FR-3 原「ent 自增 int」假设)。

## Context

客户端零本地库(ADR-005 偏差),R6 要 drift 作未绑定态主存储。本 feature 交付库本体:全实体 schema + DAO + DI + migration 骨架,**零调用方改动**(seam 是 feature C)。

## Goals / NonGoals

- **Goals**:schema v1 建全表(契约表 + 本地自有表);每模块基础 DAO + 内存库单测;契约映射表落档(G1,feature G 依据)。
- **NonGoals**:repository 接线(C)/引用数据 seed 机制实施(C/E)/派生快照写路径(E/H)/绑定导出(G)/任何 server 改动。

## Decisions(ADRs)

### ADR-1 ID 策略 = UUID TEXT 主键,client 生成(勘误 spec FR-3)
- **Decision**:契约表 PK 一律 TEXT(UUID 字符串),游客态由 client 生成(`uuid ^4.5.1` 已在 pubspec);**不设 remote_id 列**。
- **Rationale**:server 领域 PK 是 uuid.UUID,exporter Import 保留 caller-supplied ID → 首绑导入后 server/local 同 UUID,绑定后在线创建行走 server UUID 镜像回写——全程同一 ID,映射列无存在必要。
- **Alternatives**:①spec 原案「自增 int PK + nullable remote_id」——基于「ent 自增 int」的错误事实,reject;②client UUID + server int 映射——同错。
- **spec 勘误**:FR-3 已同步修订(见 spec.md changelog 注)。

### ADR-2 库位置 = `lib/core/localdb/`
- **Decision**:database/tables/daos 全部置于 `core/localdb/`,与 `core/network`(GrpcClient)同列共享基础设施。
- **Rationale**:单库跨全模块,drift 要求单 `@DriftDatabase` 汇总;core 是既有共享 infra 惯例位,依赖方向 `data → core` 合法且 localdb 不 import 任何业务模块(port 模式不破)。
- **Alternatives**:①每模块独立库——跨模块 join(交易↔账户)困难、连接管理翻倍,reject;②顶层 `lib/localdb/`——与 core 语义重复。

### ADR-3 表分两类:契约表(列=payload 字段)+ 本地自有表(无契约义务)
- **Decision**:
  - **契约表**(8 模块,绑定导出的依据):列 = backup payload 字段直存,形态对齐契约——金额 `int64`(*Cents)、UUID/时间 `TEXT`(RFC3339)、枚举 `int`(backup JSON 数字形态,iota 值原样)、bool `BOOL`。列名 PascalCase→snake_case。
  - **本地自有表**(派生/引用/联结):结构对齐 server 语义但**无契约义务**——派生快照(可重算)、security/currency/chart 引用数据、transaction_tag 联结(契约不含,见 R1)。
- **Rationale**:契约表直存 = mapper 零形态转换(仅命名转换),feature G 导出风险最低;自有表跟随 server 语义为镜像(E/H)留路。
- **Alternatives**:按 proto DTO 建表——proto 是 gRPC 读模型(字符串枚举/YYYY-MM-DD/缺 chartCode 等字段),与 backup JSON 不同型,reject。

### ADR-4 DAO = 每模块一个 `@DriftAccessor`
- **Decision**:AccountDao/TransactionDao/DebtDao/BudgetDao/GoalDao/TagDao/TemplateDao/HoldingDao + ReferenceDao(currencies/securities/chart)+ DerivedDao(快照/lot,最小 CRUD)。`AppDatabase` 汇总注册全部 table+dao。
- **Rationale**:DAO 边界 = backup 模块边界,feature C seam 按模块接线;引用/派生各一 DAO 避免八处散落。
- **Alternatives**:每表一 DAO——粒度过细,与模块边界错位。

### ADR-5 DI = injection.dart 手动注册
- **Decision**:`getIt.registerLazySingleton<AppDatabase>(AppDatabase.new)` 手动注册(对齐 core infra 手动惯例:FlutterSecureStorage/GrpcClient 同位);DAO 经 `database.<dao>` accessor 访问,不单独注册。
- **Rationale**:drift 打开是惰性的(首次查询才连),lazy singleton 语义吻合;测试直接 `AppDatabase(NativeDatabase.memory())` 绕 getIt。

### ADR-6 契约形态直存(int64/TEXT RFC3339/int 枚举)
- **Decision**:见 ADR-3;时间一律 TEXT RFC3339(与 backup JSON 同形态),本地写入用 UTC。
- **Alternatives**:epoch INT 时间(导出需往返转换)/TEXT 枚举名(backup 是数字)——均增转换面,reject。

## HLD

```
lib/core/localdb/
├── app_database.dart        @DriftDatabase(全部表,全部 DAO) + migration 骨架
├── tables/
│   ├── account_tables.dart      Accounts(契约)
│   ├── transaction_tables.dart  Transactions + TransactionEntries(契约,entries 嵌套→子表)
│   ├── debt_tables.dart         Debts + PaymentScheduleEntries(契约)
│   ├── budget_tables.dart       Budgets + BudgetItems(契约)
│   ├── goal_tables.dart         Goals + GoalAccountLinks + GoalDebtLinks(契约,uuid数组→联结表)
│   ├── tag_tables.dart          Tags + TransactionTags(前者契约,后者本地自有 R1)
│   ├── template_tables.dart     TransactionTemplates(契约)
│   ├── holding_tables.dart      Holdings + HoldingTransactions(契约)
│   └── reference_tables.dart    Currencies/RateHistories/Securities/SecurityPriceHistories/ChartOfAccounts(自有)
│   └── derived_tables.dart      DebtProgressSnapshots/GoalProgressSnapshots/HoldingSnapshots/HoldingLots(自有)
└── daos/
    ├── <module>_dao.dart     ×8(基础 CRUD + 模块关系查询)
    ├── reference_dao.dart
    └── derived_dao.dart
```

依赖方向:`core/localdb` 不 import 业务模块;业务模块 data 层自 feature C 起消费(本 feature 无消费者)。`injection.dart` 手动注册 AppDatabase。

## LLD

### 契约表列清单(列名 snake_case;类型按 SQLite;NULL 标注;转换规则见表后)

**accounts**(payload `[]Account`):
`id TEXT PK` name account_type INT category INT currency_code initial_balance_cents INT current_balance_cents INT ownership INT icon color chart_code parent_id TEXT? is_system BOOL sort_order INT institution credit_limit_cents INT? card_number_tail notes opening_date TEXT? interest_rate REAL? credit_billing_day INT? credit_repayment_day INT? credit_annual_fee_cents INT? invest_cost_cents INT? invest_market_value_cents INT? invest_return_ytd REAL? fixed_principal_cents INT? fixed_start_date TEXT? fixed_maturity_date TEXT? fixed_term_months INT? gold_product_type gold_quantity REAL? gold_buy_price_cents INT? gold_current_price_cents INT? estate_purchase_price_cents INT? estate_current_value_cents INT? estate_purchase_date TEXT? estate_depreciation_rate REAL? loan_original_cents INT? loan_remaining_cents INT? loan_monthly_cents INT? loan_next_payment_date TEXT? status INT version INT created_at updated_at

**transactions**(payload `[]Transaction` 嵌套 Entries→子表):
`id TEXT PK` transaction_date transaction_time TEXT? description version created_at updated_at
**transaction_entries**:`id TEXT PK` transaction_id TEXT FK→transactions account_id TEXT(chart_of_account_code TEXT) debit_cents INT credit_cents INT note

**debts**:`id TEXT PK` account_id counterparty interest_rate REAL amortization_method INT start_date due_date total_principal_cents INT debt_type INT subtype contact contract_ref collection_account_id TEXT? version created_at updated_at
**payment_schedule_entries**:`id TEXT PK` debt_id TEXT FK→debts payment_date principal_cents INT interest_cents INT total_cents INT paid_cents INT paid BOOL transaction_id TEXT?

**budgets**:`id TEXT PK` name month("YYYY-MM" TEXT) total_amount_cents INT currency_code is_active BOOL version created_at updated_at
**budget_items**:`id TEXT PK` budget_id TEXT FK→budgets account_id planned_amount_cents INT actual_amount_cents INT notes

**goals**:`id TEXT PK` name goal_type INT target_amount_cents INT current_amount_cents INT currency_code deadline TEXT? notes is_completed BOOL completed_at TEXT? version created_at updated_at
**goal_account_links / goal_debt_links**:`goal_id TEXT FK + linked_id TEXT`(payload 的 uuid 数组展平;导出时聚合回数组——转换规则③)

**tags**:`id TEXT PK` name color("#RRGGBB") version created_at updated_at

**transaction_templates**:`id TEXT PK` name description amount_cents INT direction INT source_account_id destination_account_id TEXT? cycle INT cycle_days INT billing_day INT next_date start_date end_date TEXT? auto_record BOOL paused BOOL last_transaction_id TEXT? category version created_at updated_at

**holdings**:`id TEXT PK` account_id security_id quantity REAL avg_cost_cents INT version created_at updated_at
**holding_transactions**:`id TEXT PK` account_id security_id trade_type INT quantity REAL price_cents INT amount_cents INT fee_cents INT realized_pnl_cents INT trade_date transaction_id TEXT? notes created_at(无 updated_at,append-only)

### 本地自有表(结构对齐 server,无契约义务)

**transaction_tags**(transaction_id FK + tag_id FK;R1 契约缺口)、**chart_of_accounts**(code TEXT PK name level account_type INT parent_code balance_direction)、**currencies**(code TEXT PK …)+ **rate_histories**、**securities**(id TEXT PK …)+ **security_price_histories**、**debt_progress_snapshots / goal_progress_snapshots / holding_snapshots / holding_lots**(字段对齐 server 同名结构,写路径 open question)。

### 转换规则(契约↔drift,feature G 导出依据)

1. `tenant_id`:drift 不存(本地单租户);导出时由绑定会话统一注入 envelope + 每结构体 TenantID。
2. `deleted_at`:backup 只导未软删行;本地删除 = 硬删,列不建(导出自然满足)。镜像态(E/H)如需软删另行演进。
3. goal 的 `LinkedAccountIDs/LinkedDebtIDs` ↔ 联结表双向聚合/展平。
4. 嵌套(Entries/Schedule/Items)↔ 子表 + FK,导出时按父聚合。
5. 枚举 = int 原样(iota 值);holding 外层包装 key `holdings`/`transactions` 其余模块为平铺数组(PascalCase key 映射在 feature G mapper)。

### DAO 契约(签名级)

每模块 DAO:`Future<void> insertX(X)/ Future<X?> getXById(String id)/ Stream<List<X>> watchAllX()/ Future<void> updateX(X)/ Future<void> deleteXById(String id)` + 模块特有关系查询(如 TransactionDao.`watchEntriesByTransaction`、BudgetDao.`watchItemsByBudget`、GoalDao.`linksFor`、HoldingDao.`watchTransactionsBySecurity`)。子表随父级联删(drift `onDelete: KeyAction.cascade`)。

### migration 骨架

`schemaVersion = 1`;`MigrationStrategy`:onCreate → 全表 Migrate.create;onUpgrade → 空实现 + TODO 注释(机制就位,FR-5)。

### 测试

`test/core/localdb/<module>_dao_test.dart`:NativeDatabase.memory() 构造 AppDatabase,每契约表 CRUD + 级联 + 关系查询断言;自有表最小冒烟。

## Risks

- **R1 transaction_tag 不进 backup 契约**(server tag.go:24 明示,restore 后关联丢失需重新打标)→ 绑定上传后**离线打的标签关联会丢**。零 server 改动约束下 accepted;记 R6 release 备忘,若日后救它需 server 契约改动(独立决策)。
- **R2 引用数据 seed 未定**(chart/IsSystem 账户/securities/currencies 全新离线安装从何而来)→ 本 feature 只建表;机制 open question,不阻塞(表空不影响库交付)。
- **R3 build_runner 生成物**(.g.dart)入库 + analyze 基线——drift 标准流程,注意 `flutter analyze` 不新增告警(NFR-1)。
- **R4 backup JSON 无 json tag(PascalCase)** — 形态怪但稳定(serde 与 Go 字段名绑定);mapper 集中 feature G 一处,不散落。

## Migration

v1 全量建表(onCreate)。后续 schema 演进走 onUpgrade 增量(骨架已就位);本 feature 无存量数据迁移面(全新库)。

## Open Questions

1. 引用数据 seed 机制(bundled JSON vs 首连拉取 vs 混合)→ feature C/E design 定。
2. 派生快照本地写路径(本地重算 vs 镜像 server)→ feature E/H 定。
3. IsSystem 预置账户本地初始化(离线首启体验)→ 随 seed 机制一并定。
