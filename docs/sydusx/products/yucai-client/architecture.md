# 御财 Client — Architecture

> client 产品架构(Flutter DDD 四层 + 偏差记录)。栈细节见 [tech-stack.md](tech-stack.md),决策溯源见 [adr/index.md](adr/index.md);repo-global monorepo 形态见 [portfolio/infrastructure.md](../../portfolio/infrastructure.md)。
> 2026-08-05 portfolio 多产品拆分自原统一 architecture。

## 架构风格

**Explicit Architecture**(DDD 限界上下文 + Hexagonal 端口适配器 + CQRS),与 server 共同采用([ADR-002](../../portfolio/adr/index.md#adr-002) cross-cutting)。client 侧:Event→State 映射的 CQRS 由 flutter_bloc 承担。

### client(`yucai/client/lib/`)— DDD 四层
| 层 | 职责 |
|---|---|
| `domain/` | entities + repositories abstract(纯 Dart) |
| `data/` | repository_impl + remote_ds(GrpcClient + AuthRetryCaller `_retry`) |
| `presentation/` | bloc + pages |
| `core/` | di injection + network grpc_client + error failures |

依赖规则:domain ← data ← presentation;跨模块走抽象 repository(port),不跨层 import。

## 跨切面决策(client 端)

- **状态管理**:flutter_bloc(Event→State CQRS 映射)。
- **DI**:getIt + injectable(`@LazySingleton` / `@Injectable`),build_runner 重生成。
- **网络**:`GrpcClient` + `AuthRetryCaller._retry`(401→RefreshToken→retry)。
- **路由**:go_router;静态子路由(`/new` `/edit`)必须在 `/:id` 前。
- **UI 文案**:中文直写(非 i18next,[ADR-006](adr/index.md#adr-006));lucide icons;OD 原型作设计源。
- **本地 DB**:**Drift(SQLite)本地优先**(R6 落地,schemaVersion=11;guest=本地主库,绑定后=全量镜像[bound_mirror rebuild],断网续写+增量同步。[ADR-005](adr/index.md#adr-005) 为历史决策,离线能力已由 R6/R9/R10 重建)。

## Product-level 质量目标

| 维度 | 目标 | 现状 |
|---|---|---|
| **可用性** | 本地优先 | ✅ 已落地(R6 本地模式 guest 单机可用;R9 绑定后断网续写;R10 多设备同步;server down 不影响记账) |
| **安全/合规** | 近期:私域级(auth OIDC PKCE client loopback)。阶段二:完整 i18n + client 安全 | 近期达标,i18n 阶段二([ADR-006](adr/index.md#adr-006)) |
| **性能** | JIT debug 运行;release 卡 accessibility_bridge 循环 → 用 debug | — |

## 实施 vs spec 偏差

| spec 设计 | 实施 | 原因 / 归属 |
|---|---|---|
| client Drift(SQlite)offline-first + 双向 sync stream | **已实施**(R6 本地模式 + R9 离线续写 + R10 多设备同步;绑定后本地=全量镜像) | 原 2026-07-25 cancelled 后由 R6/R9/R10 重建落地 |

## 架构风险 / 待定点

- client i18n seam:当前不预留(YAGNI),阶段二全量改造([ADR-006](adr/index.md#adr-006))。
- ~~离线能力缺失~~ 已消除:R6/R9/R10 落地本地优先([ADR-005](adr/index.md#adr-005) 转历史记录)。
