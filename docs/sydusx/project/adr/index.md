# ADR 索引 — 御财架构决策

> Architecture Decision Records。回填自现有实施 + [2026-06-09 重写 spec](../../../superpowers/specs/2026-06-09-architecture-redesign-design.md)。
> 由 `/sydusx-architect` 建立(2026-08-01)。每条:decision + rationale + **named alternatives** + status。

| # | 决策 | 状态 |
|---|---|---|
| [ADR-001](#adr-001-整体重写-tauri--rust--react--go--flutter) | 整体重写 Tauri+Rust+React → Go+Flutter | Accepted(2026-06-09) |
| [ADR-002](#adr-002-ddd-四层--hexagonal-port--cqrs) | DDD 四层 + Hexagonal port + CQRS | Accepted |
| [ADR-003](#adr-003-orm-entgo) | ORM = entGo(schema-first) | Accepted |
| [ADR-004](#adr-004-di-wire-手维护) | DI(Go)= Wire,**wire_gen.go 手维护** | Accepted(债务,audit 10) |
| [ADR-005](#adr-005-client-本地-db-drift-未实施--gRPC-直连) | client 本地 DB:Drift(设计)**未实施** → gRPC 直连 | Superseded-by-defer(ticket 16) |
| [ADR-006](#adr-006-i18n中文直写阶段二-i18next) | i18n:中文直写(当前),阶段二 i18next | Accepted(阶段二触发) |
| [ADR-007](#adr-007-多租户-tenant_idvision-降为个人优先预留) | 多租户 `tenant_id`;vision 降为个人优先(预留) | Accepted(演进) |

---

## ADR-001: 整体重写 Tauri+Rust+React → Go+Flutter
- **Date**: 2026-06-09
- **Decision**: 将御财从 Tauri/Rust/SQLite 单用户桌面应用**整体重写**为 Go + Flutter + PostgreSQL 的 C/S 分离架构。
- **Rationale**: 多租户 SaaS 能力 + 跨平台(desktop+mobile)+ 类型安全全栈(gRPC/protobuf codegen)+ Go 生态对后端 DDD/ent/wire 的契合。
- **Alternatives**(named):
  - **继续 Tauri+Rust+React**:保留已完成的 Phase 1-8 + Sprint 1-8 工作,但 Rust 后端 DDD 生态不如 Go 成熟、multi-tenant + gRPC 集成成本高。**rejected**:生态 + C/S 分离诉求。
  - **Electron + Node**:跨平台 + JS 全栈,但性能/资源占用差,Node 后端类型安全弱。**rejected**。
  - **渐进迁移(保留 Tauri shell + 加 Go 后端)**:混合复杂度高于整体重写。**rejected**。
- **Cost**: Tauri 时代 Phase/Sprint 工作(specs/plans 2026-05~06-08)全部废弃。

## ADR-002: DDD 四层 + Hexagonal port + CQRS
- **Decision**: server + client 均采用 Explicit Architecture(DDD 限界上下文 + Hexagonal 端口适配器 + CQRS command/query)。
- **Rationale**: 复杂金融领域需要严格的聚合/值对象/不变量;port 模式保证跨模块不直接 import(可测、可替换)。
- **Alternatives**:
  - **简单分层(MVC/三层)**:不足以表达 double-entry 不变量与聚合边界。**rejected**。
  - **Clean Architecture**:与 Explicit Architecture 同源但少了 CQRS command/query 显式映射。**rejected**。
  - **Event-driven 微服务**:MVP 过度,NATS 后置(spec 决策)。**rejected for MVP**。
- **Port 范式实现**:networth 3 port / goal `AccountMarketValueSource` / budget `entryFunc` 闭包 / debt `CreateDebtCashRecorder`。

## ADR-003: ORM = entGo(schema-first)
- **Decision**: server 用 entGo(Meta)作 ORM,schema-first code generation。
- **Rationale**: 类型安全 + schema 即真理 + mixin(TenantMixin/TimeMixin)+ 自动 migration。
- **Alternatives**:
  - **gorm**:运行时反射,类型安全弱,schema 非代码生成。**rejected**。
  - **sqlc**:查询优先(写 SQL 生成 Go),但 schema 演进 + 关系遍历不如 ent。**rejected**。
  - **raw sqlx**(Tauri 原栈):无类型安全,51 个手写 SQL 文件难维护。**rejected**。

## ADR-004: DI(Go)= Wire,wire_gen.go 手维护
- **Decision**: server 用 Google Wire 编译期 DI,**但 `wire_gen.go` 手维护**,不跑 wire CLI。
- **Rationale**: wire 工具链 tree-wide 坏(ent schema 空 + wire.go stale + Go 版本);手改成本低于修工具链(镜像现有 provider 顺序,消费方在依赖方后声明)。
- **Alternatives**:
  - **修 wire 工具链再跑 CLI**:投入大、风险高(ent schema/codegen 链路)。**defer**(audit 10 ticket)。
  - **换 fx(uber,运行时 DI)**:反射 + 启动开销,丢编译期检查。**rejected**。
  - **手写 DI(无框架)**:provider 一多就失控。**rejected**。
- **Status**: Accepted 但为债务 → audit 10(wire/schema 技债)归属。

## ADR-005: client 本地 DB:Drift(设计)未实施 → gRPC 直连
- **Decision**: spec 设计 client 用 Drift(SQlite)offline-first + 双向 sync stream;**实施时放弃**,client 直连 gRPC,无 local DB。
- **Rationale**: 云备份/多设备同步 2026-07-25 cancelled;local-first 通过 server + Postgres 持久化满足。offline 能力当时非必需。
- **Alternatives**:
  - **按 spec 实施 Drift offline-first**:双写复杂度 + sync engine/conflict resolver 工程量大,当时无多设备需求。**rejected(2026-07)**。
  - **保留 Drift 仅作缓存(不 sync)**:YAGNI,直连够用。**rejected**。
- **Cost / 重新评估**: server down 则 client 不可用(可用性 NFR 偏差)。**vision 已把多设备同步重纳入 scope(阶段二,ticket 16)**,届时 Drift/sync 重评估。
- **Status**: Superseded-by-defer — 待 ticket 16 多设备同步实施时重决策。

## ADR-006: i18n = 中文直写,阶段二改 i18next
- **Decision**: client UI **中文直写**(非 i18next)。阶段二(vision)改 i18next 全量改造。
- **Rationale**: 当前单用户/中文场景,i18n 抽象层 YAGNI;阶段二商业级分发才需要多语言。
- **Alternatives**:
  - **现在预留 i18n seam(包裹所有文案)**:增加当前复杂度,且阶段二 i18next API 可能变。**rejected(YAGNI)**。
  - **现在就全量 i18next**:与私域阶段不匹配,拖慢功能交付。**rejected**。
- **Cost**: 阶段二需全量文案抽取(所有 pages/widgets)。**接受**(vision 阶段二独立 milestone)。
- **Status**: Accepted — 阶段二触发。

## ADR-007: 多租户 `tenant_id`;vision 降为个人优先(预留)
- **Decision**: 全表 `tenant_id` + `TenantMixin`(spec multi-tenant SaaS 设计)**保留实施**,但 vision 演进为「个人专业理财优先」,tenant 作预留扩展。
- **Rationale**: 审计 01 已为 tenant 隔离投入(IDOR 修 + 跨租户拒绝矩阵 CI 门);撤回浪费。vision 把家庭共享 defer 到远期,tenant 架构正好预留。
- **Alternatives**:
  - **撤回 tenant 简化为单租户**:丢审计 01 投资 + 堵死家庭/多设备演进。**rejected**。
  - **现在就做家庭共享(多租户主力)**:vision 明确个人优先,家庭 defer。**rejected**。
- **Note**: 近期 feature 以单用户为现实主力,但所有数据层仍带 tenant_id;阶段三家庭共享落地时无需 schema 迁移。
- **Status**: Accepted(演进)。
