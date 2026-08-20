# 御财 Client (yucai-client) — Product Vision

> Product Goal — sole source for the client product。`sydusx-portfolio` 的 product checkpoint 重读本文件。
> 由 `/sydusx-portfolio` 自统一「御财 Product Vision」拆分(2026-08-05)。sibling 产品:[yucai-server](../yucai-server/vision.md)。

## Positioning(定位)

御财 **桌面客户端**——用户直接接触的 Flutter 应用(desktop + mobile 响应式,flutter_bloc + injectable)。本地优先架构下经 gRPC 直连 server(无本地 DB,[ADR-005](adr/index.md#adr-005))。承担全部 UI / 交互 / 表单 / 报表可视化 / 离线降级体验。

- **主力场景**:单用户个人理财的桌面 UI;中文直写([ADR-006](adr/index.md#adr-006),阶段二 i18n)。
- **消费契约**:消费 server 的 proto/gRPC API(consumes [yucai-api 契约](../../portfolio/contracts/yucai-api/README.md))。
- **差异化**:对标商业级客户端的 UI 交互与操作效率(gap-analysis 四维度之一);OD 原型作设计源。

## Long-term Goal(长期目标 / 终态)

**终态 = 可分发的商业级个人专业理财应用的客户端。**(与 [yucai-server](../yucai-server/vision.md) 共同服务统一的御财产品目标。)

- 19 模块 UI 行业级(对标随手记 / MoneyWiz / YNAB);UI 交互 / 操作效率达行业 4-5 分。
- 阶段二:完整 i18n(全量文案抽取改 i18next)+ 商业级安全审计的 client 侧。

## Overall Scope

### IN(client 端)
- 领域模块 UI:account / transaction 表单 + 列表 / 详情 / debt / budget / goal / holding(收益展示)/ report / currency / tag / template。
- DDD 四层(domain / data / presentation / core)+ flutter_bloc + getIt injectable。
- OD 原型驱动 UI(holding + accounts-responsive 已产出)。
- 测试基线:flutter test(3 fail / 2 文件 test drift)+ flutter analyze(22 `*.pbserver` 基线)。

### 近期豁免(阶段二补齐)
- i18n 国际化(全量文案抽取,[ADR-006](adr/index.md#adr-006))。
- ~~离线能力~~ → 已提前立项 [R6 offline-first 本地模式](release-r6-offline/release.md)(2026-08-20;绑定后离线续写/多设备同步仍留 ticket 16)。

## Execution Path(分阶段)

见统一执行路径(原 vision 四关键决策)—— 对 client 同样适用。client 特有决策:[ADR-005](adr/index.md#adr-005)(本地 DB 未实施 gRPC 直连)+ [ADR-006](adr/index.md#adr-006)(i18n 中文直写阶段二)。client 当前 active release:[R6 offline-first 本地模式](release-r6-offline/release.md)(2026-08-20 立项,无账号单机可用 + 绑定上传);R5 审计整改为 server-only,client 不在 scope。后续:功能对标模块 / 阶段二 i18n。

## 决策溯源

本 vision 由原统一「御财 Product Vision」(2026-08-01)按 portfolio 多产品 roster 拆分(2026-08-05)。
