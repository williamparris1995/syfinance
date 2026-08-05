# 御财 Server (yucai-server) — Product Vision

> Product Goal — sole source for the server product。`sydusx-portfolio` 的 product checkpoint 重读本文件判定 vision 是否仍有效。
> 由 `/sydusx-portfolio` 自统一「御财 Product Vision」拆分(2026-08-05)。sibling 产品:[yucai-client](../yucai-client/vision.md)。

## Positioning(定位)

御财 **后端服务**——驱动整个御财应用的 Go 后端(DDD + gRPC + ent + PostgreSQL),本地优先架构。它是御财客户端的单一数据源与业务大脑:记账 / 预算 / 投资 holding 收益引擎 / 报表 / 债务 / 目标 / 备份恢复 / 模板调度的全部领域逻辑与持久化在此。

- **主力场景**:单用户个人理财的 server 端;多租户隔离已实现(审计 01 加固),家庭共享作预留扩展。
- **对外契约**:经 proto/gRPC 对 client 暴露 API(produces [yucai-api 契约](../../portfolio/contracts/yucai-api/README.md))。
- **差异化**:对标商业级后端(随手记 / MoneyWiz / YNAB)的领域深度与财务计算正确性,保留本地优先 + 数据自主。

## Long-term Goal(长期目标 / 终态)

**终态 = 可分发的商业级个人专业理财应用的后端。**(与 [yucai-client](../yucai-client/vision.md) 共同服务统一的御财产品目标。)

- 核心领域模块达行业级;财务计算(portfolioCAGR/XIRR/TWR)有 oracle 测试守护。
- 工程最佳实践:事务一致性 / 备份可靠 / DB 完整性约束 / 错误处理统一 / DDD-port 边界(审计 03-09)。
- 阶段二:完整合规审计的后端支撑(GDPR/PIPL 数据主体权利 / 遗忘权 / 可携带)。

## Overall Scope

### IN(server 端)
- 领域模块后端:account / transaction(双账 + transfer)/ debt / budget / goal / holding(收益引擎 + 多币种)/ currency / tag / template(autoRecord scheduler)/ report。
- 备份恢复(审计 04)+ 跨模块事务(审计 03)+ DB 完整性约束(审计 05)+ 财务计算正确性(审计 06)。
- 错误处理统一(审计 08)+ DDD/port 边界 depguard(审计 09)。
- 多租户 tenant_id 隔离(预留家庭共享 / 多设备同步)。

### 近期豁免(阶段二补齐,与 client 一致)
- 完整公众级合规的后端实现(数据主体权利 API / 遗忘权 / 可携带导出)。
- 多设备同步 sync engine(届时重评估 client Drift + 后端 sync stream,ticket 16)。

## Execution Path(分阶段)

见统一执行路径(原 vision 四关键决策:定位锚点个人专业 / 全面功能对标 / 多设备同步 IN 家庭 defer / 分阶段商业级路径)—— 对 server 同样适用。server 当前 active release = **R5 审计整改**(03-09,全 server-side)。阶段二(合规后端支撑)为后置 release。

## 决策溯源

本 vision 由原统一「御财 Product Vision」(2026-08-01 `/sydusx-envision` light-grill 四关键决策收敛)按 portfolio 多产品 roster 拆分(2026-08-05)。
