# ADR 索引 — 御财 cross-cutting 架构决策

> repo-global / cross-product 架构决策(同时影响 yucai-server + yucai-client)。回填自现有实施 + [2026-06-09 重写 spec](../../../superpowers/specs/2026-06-09-architecture-redesign-design.md)。
> 产品特定 ADR:[yucai-server/adr](../../products/yucai-server/adr/index.md) · [yucai-client/adr](../../products/yucai-client/adr/index.md)。
> 由 `/sydusx-architect` 建立(2026-08-01);2026-08-05 portfolio 多产品拆分自原统一 adr/index。

| # | 决策 | 归属 | 状态 |
|---|---|---|---|
| [ADR-001](#adr-001-整体重写-taurirustreact--goflutter) | 整体重写 Tauri+Rust+React → Go+Flutter | cross-cutting | Accepted(2026-06-09) |
| [ADR-002](#adr-002-ddd-四层--hexagonal-port--cqrs) | DDD 四层 + Hexagonal port + CQRS | cross-cutting(server+client 共同) | Accepted |
| ADR-003 / 004 / 007 | ORM entGo / DI Wire 手维护 / 多租户 tenant_id | server | 见 [yucai-server/adr](../../products/yucai-server/adr/index.md) |
| ADR-005 / 006 | client 本地 DB Drift 未实施 / i18n 中文直写 | client | 见 [yucai-client/adr](../../products/yucai-client/adr/index.md) |

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
- **产品落地**:server 见 [server architecture](../../products/yucai-server/architecture.md);client 见 [client architecture](../../products/yucai-client/architecture.md)。Port 范式实现(server 端):networth 3 port / goal `AccountMarketValueSource` / budget `entryFunc` 闭包 / debt `CreateDebtCashRecorder`。
