# Feature — drift 本地库落地(全实体 schema + proto DTO 契约)

> R6 sprint-1 feature A(地基,unblock B/C 及 sprint-2 全模块)。
> 依赖:无(drift ^2.21.0 / sqlite3_flutter_libs / connectivity_plus 已在 pubspec 预留未用)。

## Description

客户端当前零本地库(ADR-005 记录的架构偏差):所有业务数据 gRPC 实时拉取。本 feature 落地 drift(SQLite)本地库,作为未绑定态的**主存储**与绑定后的镜像载体。

schema 覆盖全部业务实体(account/transaction/category/tag/template/holding/budget/goal/debt/receivable/currency 等,对齐 ent 业务表范围);**G1 决策**:表结构以 proto DTO / backup 格式为唯一契约源(绑定上传的交换格式),避免 drift↔ent 双 schema 手工漂移。DI 注册 Database/Dao(injectable)。本 feature 只交付库本体 + 契约对齐,**不改任何 repository 调用方**(那是 feature C 的 seam)。

## Stories

1. drift database + 全业务实体表 schema(字段/关系对齐 proto DTO 契约,枚举/金额按 proto 语义)
2. G1 契约对齐:与 backup 格式/proto 消息的字段映射表落到 design.md(绑定上传交换格式的依据)
3. DI 注册(injectable)+ 连接生命周期(app 启动开库/测试内存库 seam)
4. 基础 DAO 单测(CRUD + 关系查询,内存库跑)
5. schema migration 起步(migration strategy 骨架,v1 从空库建)

## title

drift 本地库落地:全业务实体 schema + DI 注册 + proto DTO 契约对齐

## keywords

drift, local db, sqlite, offline, schema, dao, R6, G1
