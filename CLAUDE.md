# CLAUDE.md

御财(YuCai)— 个人理财桌面应用。**Go 后端**(DDD + gRPC + ent)+ **Flutter 客户端**(flutter_bloc + injectable)。本地优先,Postgres(podman 容器 dev)。

## 项目结构

```
yucai/
  server/           # Go 后端(internal/ DDD 四层 + ent + wire)
  client/           # Flutter 客户端(lib/ DDD 四层 + flutter_bloc + getIt)
proto/              # proto3 定义(gen Go + Dart stub)
docs/superpowers/   # brainstorm / specs / plans(SDD 工作流)
design-output/      # OD 原型(holding + accounts-responsive)
```

## 命令

### server(Go, `yucai/server/`)
- `go test ./...` — 全量测
- `go build ./...` — build
- 单包:`go test ./internal/budget/... -count=1`
- rebuild exe:`go build -o bin/server.exe ./cmd/server`

### client(Flutter, `yucai/client/`)
- `flutter test` — 全量测(基线:**4 预存 fail / 3 文件** — account_detail_page_test(1)+ app_shell_test(1)+ receivable_detail_page_test(2),test drift out-of-scope)
- `flutter analyze` — 分析(基线 22 error 全 `*.pbserver.dart`,客户端未用)
- `flutter build windows --debug` — build
- `dart run build_runner build --delete-conflicting-outputs` — DI 注入重生成(injectable)

### proto 改后重生成 stub
- Go:`cd yucai/server && buf generate --template buf.gen.go.yaml`(无网 fallback:本地 protoc + protoc-gen-go/-grpc,手修 `package <name>v1`)
- Dart:`cd yucai && make gen-dart`(**protoc_plugin 必须 25.0.0**;21.x 生成 protobuf 4.x 旧 API → analyze 暴增)

### dev 运行(详见 memory `yucai-dev-env`)
- podman 容器 `yucai-pg`(DB 用户/密码/库名 = `yucai`,**非** `yucai_dev`)
- server(bash run_in_background,绝对路径 cd):`export DATABASE_URL='postgresql://yucai:yucai@localhost:5432/yucai?sslmode=disable' && export JWT_SECRET='...' && export GRPC_PORT=9090 && ./bin/server.exe`
- client:`flutter run -d windows`(JIT;release 卡 accessibility_bridge 循环,用 debug)

## 架构

### server(`yucai/server/internal/`)— DDD 四层
- `domain/` — aggregates + value objects + repository **interfaces**(account/transaction/debt/budget/goal/holding/currency/tag/template/sync/backup/...)
- `application/` — 业务服务 + DTO
- `infrastructure/`(adapter/driven)— ent repos + schedulers + 加密 + 同步
- `presentation/`(adapter/driving)— gRPC handlers

**跨模块 port 模式**:消费模块不 import 生产模块,走函数/接口注入(照 networth 3 port / D-goal AccountMarketValueSource / budget entryFunc 闭包)。
**account-as-category + 双账**:`TransactionType` Income/Expense/**Transfer**(asset→asset)。budget item = expense 账户(category);transfer 不涉 expense → 自动排除。

### client(`yucai/client/lib/`)— DDD 四层
- `domain/`(entities + repositories abstract)
- `data/`(remote_ds + repository_impl;GrpcClient + AuthRetryCaller `_retry`)
- `presentation/`(bloc + pages)
- `core/`(di injection + network grpc_client + error failures)

`flutter_bloc` + `injectable`(`@LazySingleton` / `@Injectable`)+ `getIt`。**中文 UI 直写**(非 i18next `t()`,与旧 Tauri 项目不同)。lucide icons。

## 关键约束(Mandatory)

1. **English 结构化日志** — slog(`slog.Error("op", "key", val)`)/ `console.error`,**无 CJK 在 log 串**
2. **wire 工具链坏** — `wire_gen.go` **手改**(镜像现有 provider 声明顺序,消费方在依赖方之后声明),不跑 wire CLI(详见 memory `yucai-wire-handmaintained`)
3. **复用第一** — 新模块照现有 holding/debt DDD 范式;先查 `lib/` + `hooks/` + `components/` 复用,不重复
4. **DDD 边界** — domain → application → infrastructure → presentation;跨模块走 port(不跨层 import)
5. **proto regen** — protoc_plugin **25.0.0**(Dart);改 proto 后 Go + Dart stub 都要 regen
6. **interface 加方法** — grep 全 implementer(**含 test fake**);implementer 跑**全量 suite** 非 scoped(否则跨包 fake 漏改致 build fail)
7. **路由优先级** — 静态子路由(`/new` `/edit`)必须在 `/:id` 前(否则 "new" 被当 :id)

## 测试
- server:Go 单测 + 集成测(enttest SQLite)+ e2e(grpcurl,需 auth token)
- client:widget test(mocktail `Mock`/`Fake`;pump 而非 pumpAndSettle 当有永不完成的 Future)
- 预存 fail:**4 测 / 3 文件**(test drift,断言过时非生产 bug,out-of-scope):account_detail_page_test(收支统计交易数 — 时间 scope 漂移,fixture txn 日期 vs `_txnCountInScope` 当前月)+ app_shell_test(topbar BackDropFilter)+ receivable_detail_page_test(StatRow "1 期" + 筛选日期 — redesign 漂移)。注:原 router_test 3 sidebar 导航 fail 已修 `5d3e8f0`(dashboard `68508b2` mock 回归,真 bug)

## 工作流(SDD)
- 创造性工作(新功能/模块)走 brainstorming → spec(`docs/superpowers/specs/`)→ plan(`docs/superpowers/plans/`)→ subagent-driven 实现
- UI 原型用 **Open Design**(MCP `open-design`),不手写 HTML 中间步骤(详见 memory `od-prototype-to-flutter`)
- progress ledger:`.superpowers/sdd/progress.md`(gitignored,本地)

## 相关 memory
`yucai-dev-env`(dev 环境)/ `yucai-wire-handmaintained`(wire 手改)/ `od-prototype-to-flutter`(OD→Flutter 工作流)/ `holding-asset-management-todo`(holding 系统状态)
