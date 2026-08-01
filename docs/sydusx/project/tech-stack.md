# 御财 — Tech Stack

> monorepo 异构栈,按 context 分(server / client / 共享)。决策溯源见 [adr/index.md](adr/index.md)。
> 由 `/sydusx-architect` 建立(回填模式,2026-08-01)。

## server context(Go)

| 类别 | 选型 | 备注 |
|---|---|---|
| 语言 | Go | — |
| 架构 | DDD 四层 + Hexagonal + CQRS | 见 [architecture.md](architecture.md) |
| ORM | **entGo**(Meta) | schema-first code generation;类型安全 |
| DI | **Google Wire** | ⚠️ `wire_gen.go` **手维护**(CLI tree-wide 坏),ADR-004 |
| RPC | **gRPC + Protobuf** | type-safe,高性能 |
| 日志 | **slog** | English 结构化日志,**无 CJK 在 log 串** |
| 加密 | scrypt(KDF 版本化自描述 header)+ AES | 审计 02/04 |
| session | Redis(miniredis 测)jti blacklist | access JWT + refresh |
| 事务 | `sqltx` 包(`*sql.DB` 共享 + TxContext + dialect.Driver) | 审计 03 |
| migration | ent migrate + 手维护 | spec 设计 Atlas,实施简化 |
| 测试 | `go test` + enttest SQLite + Testcontainers(Postgres)+ e2e(grpcurl) | — |

## client context(Flutter)

| 类别 | 选型 | 备注 |
|---|---|---|
| 语言/框架 | Flutter(Dart) | desktop + mobile 响应式 |
| 架构 | DDD 四层 | 见 [architecture.md](architecture.md) |
| 状态管理 | **flutter_bloc** | Event→State 映射 CQRS |
| DI | **getIt + injectable**(`@LazySingleton` / `@Injectable`) | build_runner 重生成 |
| 路由 | go_router | 静态子路由(`/new` `/edit`)必须在 `/:id` 前 |
| 网络 | grpc + AuthRetryCaller `_retry` | 401→RefreshToken→retry |
| i18n | **中文直写(非 i18next)** | ⚠️ 阶段二改 i18next,ADR-006 |
| icons | lucide | — |
| 本地 DB | _(无 Drift,spec 设计未实施)_ | ⚠️ 直连 gRPC,离线 defer ticket 16 |
| 测试 | flutter test + mocktail(M/Fake)+ bloc_test | 基线 3 fail/2 文件(test drift) |

## 共享 / 基础设施

| 类别 | 选型 | 备注 |
|---|---|---|
| proto 定义 | `proto/` proto3 | gen Go + Dart stub |
| proto 工具链 | **Buf**(Go)+ make gen-dart(Dart) | ⚠️ Dart **protoc_plugin 必须 25.0.0**(21.x→protobuf 4.x 旧 API) |
| 数据库 | **PostgreSQL 16** | podman 容器 `yucai-pg`(DB 用户/密码/库名 = `yucai`) |
| 部署 | Docker Compose(api + postgres + redis + adminer) | dev profile |
| 版本 | git(无 tag/release,连续提交) | — |

## 关键约束(影响栈使用)

> 详见 [conventions.md](conventions.md) 与 `CLAUDE.md`「关键约束」。这里仅列栈相关:
- proto 改后 Go + Dart stub **都要 regen**(Dart protoc_plugin 25.0.0)。
- ent schema 改后 `go generate ./internal/<pkg>/ent/...`。
- interface 加方法 → grep 全 implementer(含 test fake)→ 跑**全量 suite**。
- wire `wire_gen.go` 手改,不跑 wire CLI。
