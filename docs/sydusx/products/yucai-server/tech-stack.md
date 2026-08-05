# 御财 Server — Tech Stack

> server 产品栈(Go)。决策溯源见 [adr/index.md](adr/index.md);架构见 [architecture.md](architecture.md);共享基建见 [portfolio/infrastructure.md](../../portfolio/infrastructure.md)。
> 2026-08-05 拆分自原统一 tech-stack。

| 类别 | 选型 | 备注 |
|---|---|---|
| 语言 | Go | — |
| 架构 | DDD 四层 + Hexagonal + CQRS | 见 [architecture.md](architecture.md) |
| ORM | **entGo**(Meta) | schema-first code generation;类型安全 |
| DI | **Google Wire** | ⚠️ `wire_gen.go` **手维护**(CLI tree-wide 坏),[ADR-004](adr/index.md#adr-004) |
| RPC | **gRPC + Protobuf** | type-safe,高性能;produces [yucai-api 契约](../../portfolio/contracts/yucai-api/README.md) |
| 日志 | **slog** | English 结构化日志,**无 CJK 在 log 串** |
| 加密 | scrypt(KDF 版本化自描述 header)+ AES | 审计 02/04 |
| session | Redis(miniredis 测)jti blacklist | access JWT + refresh |
| 事务 | `sqltx` 包(`*sql.DB` 共享 + TxContext + dialect.Driver) | 审计 03 |
| migration | ent migrate + 手维护 | spec 设计 Atlas,实施简化 |
| 测试 | `go test` + enttest SQLite + Testcontainers(Postgres)+ e2e(grpcurl) | — |

## 关键约束(影响栈使用)

> 详见 [portfolio/conventions.md](../../portfolio/conventions.md) 与 `CLAUDE.md`「关键约束」。这里仅列栈相关:
- proto 改后 Go + Dart stub **都要 regen**(Dart protoc_plugin 25.0.0)。
- ent schema 改后 `go generate ./internal/<pkg>/ent/...`。
- interface 加方法 → grep 全 implementer(含 test fake)→ 跑**全量 suite**。
- wire `wire_gen.go` 手改,不跑 wire CLI。
