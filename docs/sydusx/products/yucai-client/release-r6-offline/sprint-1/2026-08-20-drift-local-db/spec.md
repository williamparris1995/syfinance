---
feature: 2026-08-20-drift-local-db
status: confirmed
---

# Spec — drift 本地库落地(全实体 schema + backup/proto 契约对齐)

> R6 sprint-1 feature A(地基,unblock B/C)。源:R6 release 方案 A(2026-08-20 clarify→approach→grill 收敛)+ 代码事实:backup `TenantDataPort`/`BackupEnvelope` 契约(`internal/backup/domain/port.go`)+ exporter Import 保留 caller-supplied ID(`adapter/driven/exporter/holding.go` create-with-given-id)。
> 纯 behavior,零实现代码(schema/DAO 细节留 design.md)。本 feature 只交付库本体,**不改任何 repository 调用方**(feature C seam 负责)。

## ADDED Requirements

### Requirement: FR-1 drift 库初始化
- [ ] 客户端 SHALL 在启动时初始化 drift(SQLite)数据库,按 schema v1 建全全部业务实体表;测试环境 SHALL 可用内存库替代文件库。

#### Scenario: 全新安装首次启动
- GIVEN 全新安装,本地无数据库文件
- WHEN app 启动
- THEN drift 库创建,schema v1 全部表就绪,可执行基本 DAO 读写

#### Scenario: 测试内存库
- GIVEN DAO 单测
- WHEN 以内存库构造 database
- THEN 同一 schema 建表,测试无文件 IO

### Requirement: FR-2 表覆盖 = backup 契约 8 模块 + 引用数据 + 派生快照
- [ ] schema SHALL 覆盖 backup TenantDataPort 的 8 个业务模块(account/transaction/debt/budget/goal/holding/tag/template)的全部实体表,以各模块 backup payload(exporter marshal 的领域结构体 JSON)为契约源;另含引用数据表(currency/rate_history/security/security_price_history)与派生快照表(debt/goal progress_snapshot、holding_snapshot)。
- [ ] design.md SHALL 落一份「drift 表列 ↔ backup payload 字段」映射表(G1 契约,feature G 绑定导出的依据),显式记录转换规则,无遗漏实体。

> 排除:auth(tenant/user/user_identity)/ backup(backup/backup_settings)/ sync(sync_log/sync_device/sync_conflict,ticket 16)。template_record_log 是否入 schema 由 design 定(镜像价值低)。

#### Scenario: 契约映射完整
- GIVEN 8 模块各自的 backup payload 结构
- WHEN 对照 design.md 映射表
- THEN 每个业务实体的每个字段在 drift 表有对应列(或显式记录的转换规则),无遗漏实体

### Requirement: FR-3 ID 策略(UUID TEXT 主键,client 生成)
> 2026-08-20 勘误(design research):server 领域 PK 是 uuid.UUID(非自增 int)——原「自增 int + remote_id」方案基于错误事实,修订;详见 design.md ADR-1。

- [ ] 每业务表 SHALL 使用 TEXT(UUID 字符串)主键 `id`,游客态由 client 生成;SHALL NOT 设 remote_id 映射列(server Import 保留 caller-supplied ID,首绑导入后 server/local 同一 UUID,全程无需映射)。
- [ ] 依据 SHALL 记录:exporter Import 保留 caller-supplied ID(create-with-given-id);绑定后在线创建行走 server UUID 镜像回写——同一行同一 UUID。

#### Scenario: 游客建行
- GIVEN 游客态(无绑定)
- WHEN 本地创建一行(如 account)
- THEN `id` 为 client 生成的 UUID 字符串

#### Scenario: 首绑导入对齐(预期,feature G 实施)
- GIVEN 游客态创建的行(UUID=U1)
- WHEN 空账号首绑上传(Import 保留 caller-supplied ID)
- THEN 服务端该行 ID = U1,server/local 同 UUID——本 feature 仅保证 schema 支持(TEXT PK),不实现上传

### Requirement: FR-4 DI 注册
- [ ] drift database(及 DAO)SHALL 经 injectable 注册为 LazySingleton,app 生命周期单实例。

#### Scenario: DI 解析
- GIVEN app 启动完成
- WHEN getIt 解析 database
- THEN 得到同一已打开实例(重复解析同实例)

### Requirement: FR-5 migration 骨架
- [ ] SHALL 提供 migration strategy 骨架:v1 全量建表起步,机制支持后续 onUpgrade 增量(不做具体 v2)。

#### Scenario: 升级机制占位
- GIVEN schema v1 库文件
- WHEN 未来 bump schemaVersion + onUpgrade 规则(后续 feature)
- THEN 机制就位可增量迁移(本 feature 仅保证骨架,不验证具体迁移)

### Requirement: FR-6 DAO 基础 CRUD
- [ ] 每业务表 SHALL 有基础 DAO(CRUD + 主要关系查询)及内存库单测。

#### Scenario: DAO 回归
- GIVEN 内存库
- WHEN 跑 DAO 单测
- THEN 全绿,秒级完成(无网络/文件依赖)

### Requirement: NFR-1 零调用方改动
- [ ] 本 feature SHALL NOT 改任何现有 repository/remote_ds/bloc/page;纯新增(库/DAO/DI + pubspec 死依赖转用)。flutter test 基线不退化(≤ 3 fail/2 文件)+ flutter analyze 不新增告警(`*.pbserver` 基线外)。

### Requirement: NFR-2 零 server 改动
- [ ] 本 feature SHALL NOT 改动 yucai/server 任何代码;go test ./... 保持全绿(不受影响)。

## scope boundary

- **IN**:drift 库 + 全实体 schema + 契约映射表(design 产物)+ DI 注册 + migration 骨架 + DAO 单测。
- **OUT**:repository 双源接线(feature C)/ 引用数据 seed 机制与首连拉取(设计决策记 design,实施可随 C/E)/ 派生快照本地写路径(本地重算 vs 镜像,design 定)/ 绑定导出与上传(feature G)。
- **依赖**:pubspec 已有 drift ^2.21.0 / sqlite3_flutter_libs / connectivity_plus(预留未用)。
- **风险标记(feature G design 验证)**:Import 显式 ID 后 postgres 自增序列是否复位(现有 restore 路径同题,R5 D6 实测覆盖则免)。

## 可行性

- **technical**:可行——依赖已在 pubspec,drift 成熟,纯新增层不动现有链路,风险低。
- **economic**:可行——单 feature 增量,零 server 成本。
- **operational**:可行——单用户桌面/移动,库文件落 app 数据目录,无运维面。
