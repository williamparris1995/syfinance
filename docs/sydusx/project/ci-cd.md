# 御财 — CI / CD

> 现状 + 待建。由 `/sydusx-run` init 建立(2026-08-01)。enforcement wall(pre-commit/CI/branch protection)在 `/sydusx-harness` 阶段与用户确认后补建。

## 现状:**无 CI pipeline**(手动验证驱动)

御财当前**没有 GitHub Actions / 其他 CI**(无 `.github/`)。质量防护靠:

1. **手动测试**(命令见下)+ 测试基线(见 [conventions.md](conventions.md))。
2. **人工 code review**(SDD workflow 的 reviewer dispatch + 全分支 final review)。
3. **审计 e2e 套件**(grpcurl + Postgres Testcontainers,手动跑)。

> ⚠️ **已知缺口**:无自动化 CI 门、无 pre-commit hook、无 branch protection。audit 01 决策曾提"建全量跨租户拒绝矩阵作 CI 回归门"但 CI 本身未建。**这是 harness 阶段的首批 enforcement 候选**。

## 验证命令(本地)

### server(`yucai/server/`)
```
go test ./...                                    # 全量测
go build ./...                                   # build
go build -o bin/server.exe ./cmd/server          # rebuild exe
go test ./internal/<pkg>/... -count=1            # 单包
```

### client(`yucai/client/`)
```
flutter test                                     # 全量测(基线 3 fail/2 文件)
flutter analyze                                  # 分析(基线 22 *.pbserver.dart)
flutter build windows --debug                    # build(JIT;release 卡 accessibility_bridge)
dart run build_runner build --delete-conflicting-outputs  # DI 重生成
```

### proto regen
```
# Go
cd yucai/server && buf generate --template buf.gen.go.yaml
# Dart(protoc_plugin 必须 25.0.0)
cd yucai && make gen-dart
```

### dev 运行
- DB:podman 容器 `yucai-pg`(见 memory `yucai-dev-env`)。
- server:`DATABASE_URL=... JWT_SECRET=... GRPC_PORT=9090 ./bin/server.exe`
- client:`flutter run -d windows`

## 部署

- **Docker Compose**:[`yucai/deploy/`](../../../yucai/deploy/) `docker-compose.yml`(api + postgres + redis + adminer)+ `docker-compose.dev.yml`。
- **无生产部署**:私域/自用,本地运行。vision 阶段二(可分发)才需正式部署管线。

## 待建(harness 阶段决定)

`/sydusx-harness` 会从 [architecture.md](architecture.md) + [conventions.md](conventions.md) 提炼 drift-critical invariants,与用户确认后 scaffold enforcement wall:

| 候选 wall | 守护的 invariant | 现状 |
|---|---|---|
| pre-commit hook | slog 无 CJK / wire 不跑 CLI / proto regen 提示 | 无 |
| CI 回归门 | `go test ./...` + `flutter test` 基线 + 跨租户拒绝矩阵(audit 01) | 无 |
| branch protection | main 不直推 / PR 过 review | 无(单开发者,可低优先) |

> 原则:_skills reduce laziness; infrastructure eliminates it_。哪些 enforce、哪些 advisory,由 harness + 用户定。
