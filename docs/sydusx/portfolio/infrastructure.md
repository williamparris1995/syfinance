# 御财 — Shared Infrastructure(monorepo 形态 + 跨产品基建)

> repo-global,span yucai-server + yucai-client。由 `/sydusx-portfolio` 自原统一 architecture 拆出(2026-08-05)。
> 产品架构:[yucai-server](../products/yucai-server/architecture.md) · [yucai-client](../products/yucai-client/architecture.md)。cross-cutting ADR 见 [adr/index.md](adr/index.md)。

## Monorepo 形态

```
yucai/
  server/    # → product yucai-server(Go DDD 四层 + ent + wire)
  client/    # → product yucai-client(Flutter DDD 四层 + flutter_bloc + injectable)
proto/       # proto3 → 跨产品契约 yucai-api(gen Go + Dart stub)
```

两产品经 proto/gRPC 解耦:server **produces** [yucai-api 契约](contracts/yucai-api/README.md),client **consumes** it。

## 跨产品共享决策

- **架构风格统一**:server + client 共同采用 Explicit Architecture(DDD + Hexagonal + CQRS),[ADR-002](adr/index.md#adr-002)。
- **money precision**:`int64 cents` 全栈(proto → Go → PostgreSQL → Dart),零浮点。跨产品契约须保持一致。
- **proto / gRPC**:type-safe 全栈契约;proto 改后 Go + Dart stub **都要 regen**(Dart protoc_plugin 25.0.0)。

## 共享 / 基础设施栈

| 类别 | 选型 | 备注 |
|---|---|---|
| proto 定义 | `proto/` proto3 | gen Go + Dart stub;权威源(不复制入 contracts) |
| proto 工具链 | **Buf**(Go)+ make gen-dart(Dart) | ⚠️ Dart **protoc_plugin 必须 25.0.0**(21.x→protobuf 4.x 旧 API) |
| 数据库 | **PostgreSQL 16** | podman 容器 `yucai-pg`(DB 用户/密码/库名 = `yucai`) |
| 部署 | Docker Compose(api + postgres + redis + adminer) | dev profile;见 [ci-cd.md](ci-cd.md) |
| 版本 | git(无 tag/release,连续提交) | — |

## dev 运行(详见 memory `yucai-dev-env`)

- DB:podman 容器 `yucai-pg`。
- server:`DATABASE_URL=... JWT_SECRET=... GRPC_PORT=9090 ./bin/server.exe`
- client:`flutter run -d windows`(JIT debug;release 卡 accessibility_bridge 循环)。

## 质量目标(cross-product)

- **安全/合规**:近期私域级;阶段二完整 GDPR/PIPL + i18n + 商业级独立审计(统一 vision 阶段二)。
- 详见各产品 architecture 的 NFR + [ci-cd.md](ci-cd.md) 验证命令。
