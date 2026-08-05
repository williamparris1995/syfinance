# 御财 Server — Architecture

> server 产品架构(Go DDD 四层 + Hexagonal port + CQRS + 跨切面决策 + 质量目标)。栈细节见 [tech-stack.md](tech-stack.md),决策溯源见 [adr/index.md](adr/index.md);repo-global monorepo 形态 + 跨产品共享基建见 [portfolio/infrastructure.md](../../portfolio/infrastructure.md)。
> 由 `/sydusx-architect` 建立(回填 2026-08-01);2026-08-05 portfolio 多产品拆分自原统一 architecture。

## 架构风格

**Explicit Architecture**(Herberto Gracia)— DDD + Hexagonal(Ports & Adapters)+ CQRS。Package by Component(按限界上下文纵向切片)。本决策见 [ADR-002](../../portfolio/adr/index.md#adr-002)(cross-cutting,server + client 共同采用)。

```
Driving Adapter(gRPC)→ Application(handler/service)→ Domain(entity/VO/service)
                                                          ↑
Driven Adapter(ent repo)implements Domain port interfaces
```

依赖规则(严格):
- **Domain 层**:无外部 import(stdlib + shared kernel)
- **Application 层**:只 import domain + shared
- **Driven adapter**:实现 domain 定义的接口
- **Driving adapter**:调用 application handler/service
- **跨组件**:account/transaction/holding/debt/... 之间**绝不直接 import**,走 domain event 或 port 注入

### server(`yucai/server/internal/`)— DDD 四层
| 层 | 职责 |
|---|---|
| `domain/` | aggregates + value objects + repository **接口**(account/transaction/debt/budget/goal/holding/currency/tag/template/sync/backup/...) |
| `application/` | 业务服务 + DTO |
| `infrastructure/`(driven) | ent repos + schedulers + 加密 + 同步 |
| `presentation/`(driving) | gRPC handlers |

## 跨切面决策(server 端)

- **多租户隔离**:`tenant_id` + `TenantMixin` 全表注入,repo 强制 `WHERE tenant_id`(审计 01 加固)。**注:vision 演进为个人专业优先,tenant 作预留扩展**——见 [ADR-007](adr/index.md#adr-007)。
- **account-as-category + 双账**:`TransactionType` = Income/Expense/**Transfer**(asset→asset)。budget item = expense 账户(category);transfer 不涉 expense → 自动排除出预算。
- **money precision**:`int64 cents` 全栈(proto → Go → PostgreSQL → Dart),零浮点。计算层 `math.Round`(审计 06 F5)。
- **乐观锁**:可变实体 `version BIGINT`,`WHERE version = ?` + `SET version+1`,零行受影响 = 冲突(7 模块已 CAS,审计 05 D11 确认)。
- **事务抽象**(审计 03,2026-07-26 落地):共享 `*sql.DB` 跨所有 ent client + `TxContext` 传播 + `sqltx` 包(dialect.Driver wrapper + 编译期接口守卫)。P0 财务写(交易/holding/debt/template)跨模块原子化。
- **跨模块 port 模式**:消费模块不 import 生产模块,走函数/接口注入。范式:networth 3 port / goal `AccountMarketValueSource` / budget `entryFunc` 闭包 / debt `CreateDebtCashRecorder`。

## Product-level 质量目标(NFR 上限,绑定所有 feature)

> feature 级 NFR(各 `spec.md`)refine 这些,**永不违反**。

| 维度 | 目标 | 现状 |
|---|---|---|
| **安全/合规** | 近期:私域级(密钥安全审计 02 + JWT jti/aud/iss)。阶段二:完整 GDPR/PIPL 后端支撑 | 近期达标,阶段二 defer(vision 阶段二) |
| **性能** | holding e2e performance suite 守卫;XIRR/TWR 计算精度有 oracle 测试 | performance e2e 套件完成 |
| **持久度** | 备份(审计 04)+ 乐观锁 + 跨模块事务(审计 03) | 03 落地,04 待专项 plan |

## 实施 vs spec 偏差(重要)

[2026-06-09 重写 spec](../../../superpowers/specs/2026-06-09-architecture-redesign-design.md) 设计与当前 server 实施的偏差:

| spec 设计 | 实施 | 原因 / 归属 |
|---|---|---|
| multi-tenant SaaS + Family | tenant 隔离实施,**vision 降为个人专业优先** | 产品定位演进([ADR-007](adr/index.md#adr-007)) |
| Atlas migration(entGo companion) | ent migrate + 手维护 | 实施简化 |
| Redis session | 部分(miniredis 测,jti blacklist) | auth OIDC 后 |

## 架构风险 / 待定点

均已有 audit ticket 归属,**不在此重新决策**:
- 事务抽象后续(audit 03 follow-up:tx-port 跨 repo 绿地重构、多账户 SyncNow + harness struct)。
- DDD/port A4 intra-module app→infra defer(audit 09)— ROI 低,软层违。
- wire 手维护是债(audit 10 wire/schema 技债)— 工具链 tree-wide 坏。
