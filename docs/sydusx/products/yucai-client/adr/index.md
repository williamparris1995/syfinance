# ADR 索引 — 御财 Client 架构决策

> yucai-client 产品特定架构决策。cross-cutting ADR(ADR-001/002)见 [portfolio/adr](../../../portfolio/adr/index.md);server ADR 见 [yucai-server/adr](../../yucai-server/adr/index.md)。
> 2026-08-05 拆分自原统一 adr/index。

| # | 决策 | 状态 |
|---|---|---|
| [ADR-005](#adr-005-client-本地-db-drift设计未实施--grpc-直连) | client 本地 DB:Drift(设计)**未实施** → gRPC 直连 | Superseded-by-defer(ticket 16) |
| [ADR-006](#adr-006-i18n-中文直写阶段二-i18next) | i18n:中文直写(当前),阶段二 i18next | Accepted(阶段二触发) |
| [ADR-007](#adr-007-组件命名产品中立化--公共组件库方向) | 组件命名产品中立化 + 公共组件库方向 | Accepted |

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

## ADR-007: 组件命名产品中立化 + 公共组件库方向
- **Decision**(2026-10-08 用户拍板):**共享 UI 原语禁止产品绑定前缀(`Yucai`)**,产品中立命名,为抽取公共组件库(供其他产品复用)做准备。三层规范(CLAUDE.md 约束 #8 single source):共享原语无前缀(`AnchoredMenu`/`ContextMenuRegion`/`MenuItemData`)/ `App` 前缀 = 应用级部件 / 领域前缀 = 模块部件。存量 `Yucai*` 可复用组件已即刻改名并抽入包。**治理(用户拍板 2026-10-08)**:组件需求选取次序 = ① design_kit 有则直接用 → ② 通用新组件先进包(中立命名 + 只读 DesignTokens,测试随包)→ ③ 仅产品特定(读业务模型/路由/bloc)才留 app。
- **Rationale**: 组件若嵌其他产品,类名带 `Yucai` 即泄漏实现方品牌;package 命名空间(import 路径)足以承载来源,类名应中立。改名即刻做,未来抽库=纯搬移零改名。
- **Alternatives**:
  - **保留 `Yucai` 前缀到抽库时再改**:累积更多引用面,改名成本随时间上涨。**rejected**。
  - **前缀改为其他品牌词**: 换个产品绑定词不解决泄漏。**rejected**。
- **Cost / 抽库时的剩余工作**: ~~组件直读 `context.yucai` 令牌~~ **已解决(2026-10-08 阶段1)**:共享原语已抽入独立包 `yucai/packages/design_kit/`(app path 依赖),包内 `DesignTokens` ThemeExtension 即依赖倒置缝 —— 组件只读 `context.designTokens`,AppTheme 从 YucaiTheme 同源映射注册(双主题视觉零变化)。剩余:产品身份类(`YucaiApp`/`YucaiTheme`)仍产品侧(本应如此);后续组件(Toast/输入类等)按需渐进入包;分发(git 依赖/私有 pub + SemVer)按需。
- **Status**: Accepted(阶段1 已落地:design_kit 包 + 令牌倒置缝 + 纯组件测试入包)。
