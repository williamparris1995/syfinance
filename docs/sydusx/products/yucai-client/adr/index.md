# ADR 索引 — 御财 Client 架构决策

> yucai-client 产品特定架构决策。cross-cutting ADR(ADR-001/002)见 [portfolio/adr](../../../portfolio/adr/index.md);server ADR 见 [yucai-server/adr](../../yucai-server/adr/index.md)。
> 2026-08-05 拆分自原统一 adr/index。

| # | 决策 | 状态 |
|---|---|---|
| [ADR-005](#adr-005-client-本地-db-drift设计未实施--grpc-直连) | client 本地 DB:Drift(设计)**未实施** → gRPC 直连 | Superseded-by-defer(ticket 16) |
| [ADR-006](#adr-006-i18n-中文直写阶段二-i18next) | i18n:中文直写(当前),阶段二 i18next | Accepted(阶段二触发) |

---

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
