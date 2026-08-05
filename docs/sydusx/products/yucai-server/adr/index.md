# ADR 索引 — 御财 Server 架构决策

> yucai-server 产品特定架构决策。cross-cutting ADR(ADR-001/002)见 [portfolio/adr](../../../portfolio/adr/index.md);client ADR 见 [yucai-client/adr](../../yucai-client/adr/index.md)。
> 2026-08-05 拆分自原统一 adr/index。

| # | 决策 | 状态 |
|---|---|---|
| [ADR-003](#adr-003-orm--entgoschema-first) | ORM = entGo(schema-first) | Accepted |
| [ADR-004](#adr-004-digo--wirewire_gengo-手维护) | DI(Go)= Wire,**wire_gen.go 手维护** | Accepted(债务,audit 10) |
| [ADR-007](#adr-007-多租户-tenant_idvision-降为个人优先预留) | 多租户 `tenant_id`;vision 降为个人优先(预留) | Accepted(演进) |

---

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

## ADR-007: 多租户 `tenant_id`;vision 降为个人优先(预留)
- **Decision**: 全表 `tenant_id` + `TenantMixin`(spec multi-tenant SaaS 设计)**保留实施**,但 vision 演进为「个人专业理财优先」,tenant 作预留扩展。
- **Rationale**: 审计 01 已为 tenant 隔离投入(IDOR 修 + 跨租户拒绝矩阵 CI 门);撤回浪费。vision 把家庭共享 defer 到远期,tenant 架构正好预留。
- **Alternatives**:
  - **撤回 tenant 简化为单租户**:丢审计 01 投资 + 堵死家庭/多设备演进。**rejected**。
  - **现在就做家庭共享(多租户主力)**:vision 明确个人优先,家庭 defer。**rejected**。
- **Note**: 近期 feature 以单用户为现实主力,但所有数据层仍带 tenant_id;阶段三家庭共享落地时无需 schema 迁移。
- **Status**: Accepted(演进)。
