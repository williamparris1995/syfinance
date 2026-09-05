# Task Brief F11-T1 — server 写入链:SyncEntityWriter×8 + 事务化 PushChanges

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r9-f11`,server 在 `yucai/server/`。**TDD(Go)。**

## 先读(必读)

1. `docs/sydusx/products/yucai-client/release-r9-offline-continue/sprint-1/2026-09-03-server-minimal-sync/{spec.md,design.md}`(FR-1/2/3 + ADR-1/3/4)
2. `yucai/server/internal/sync/` 现状全链:`adapter/driving/grpc/sync_handler.go`(PushChanges 入口/getTenantID/deviceId fallback)、`application/service.go`(L67-101 现版逐条 append 循环)、`adapter/driven/repository/sync_repo.go`(LatestVersion L42-43)、`domain/`、`ent/schema/`(sync_logs 三表)
3. **backup 范式样板**(ADR-1/2/3 的来源):`internal/backup/application/service.go`(purgeAndImport L225-245/orderedPortsForPurge L300-315/orderedPortsForImport L317-332/sqltx.WithTx 用法)、`internal/backup/adapter/driven/exporter/account.go`(Import=json.Unmarshal→repo.Save)、`internal/backup/domain/`(TenantDataPort 形态)
4. **8 模块 repo Save 范式**:`internal/account/adapter/driven/repository/account_repo.go` L38-96(SetID 显式 client uuid);其余模块同构路径自寻
5. `internal/sqltx/sqltx.go`(WithTx/clientFor)
6. **wire 手改 4 处**:`wire/providers.go`(provideBackupExporters L666-668 与 provideSyncService L710-740 为参照)+ `wire/wire.go` + `wire/wire_gen.go`(L69 syncClient 声明区) + `wire/app.go`——**不跑 wire CLI**(工具链坏,CLAUDE.md L61 约定),手改镜像,消费方在依赖方之后声明
7. 测试基线:`tests/account_integration_test.go` L19-43(Tier-A 内存 sqlite 手写 harness 样板);`make test`=cd server && go test ./... -v -count=1

## 交付物

### 1. SyncEntityWriter port + 8 实现(ADR-1)

- `internal/sync/domain/entity_writer.go`(或 application,按 backup TenantDataPort 落点惯例):`type SyncEntityWriter interface { Name() string; Upsert(ctx context.Context, tenantID uuid.UUID, payload []byte) error; Delete(ctx context.Context, tenantID uuid.UUID, entityID string) error }`——中文注释?**否,server 侧注释英文(库内惯例)**,但 dartdoc 风格 go doc 简洁。
- `internal/sync/adapter/driven/entitywriter/{account,transaction,debt,budget,goal,holding,tag,template}.go`:Upsert=`json.Unmarshal(payload, &domain.X)`(tenantID 覆盖,防注入照 backup service.go L212-214 模式)→ find(by id+tenant)→有则全字段 update+SetVersion(client 版)→无则 create(SetID client uuid);Delete=find→硬删(模块内级联照 repo 既有 delete 或补)。
- providers:`provideSyncEntityWriters` 聚合 map[string]SyncEntityWriter(key=entity_type=client SyncModule 名:account/transaction/debt/budget/goal/holding/tag/template,与 MirrorModule 逐字一致)。

### 2. service.PushChanges 事务化(ADR-3/4)

- 重构:整个批次在 `sqltx.WithTx` 内——①按序分发:先处理 DELETE(依赖序=backup orderedPortsForPurge 序,引用方先删)再处理 upsert(依赖序=orderedPortsForImport 序,account 先)?**或按 op 混排保持 client 批次序但删除先于同实体 upsert**——设计自由度给你,注释理由,测试钉死核心场景(删 A+建 B 混合批次)。
- ②事务内取 LatestVersion+1 逐条递增 append sync_log(entity_type/entity_id/version/device_id/operation)。
- ③任一失败→整体回滚(返回 gRPC 错误)。
- slog 英文键值:operation="sync_push" tenant_id entity_type count error。
- conflicts 恒空维持+注释(ticket 16)。

### 3. wire 4 处镜像

- providers.go 新 provide*;wire.go wire.Build 增;wire_gen.go 手改声明(依赖序);app.go 若需。`go build ./...` + `go vet` 过。

### 4. TDD 测试(Tier-A 内存 sqlite,照样板)

- 每模块 writer upsert(create 路径/update 路径/tenant 隔离/未知字段容忍)——至少 account/transaction/debt/holding 四深测,其余 4 模块轻测(create+delete 各 1)。
- service 批次:跨模块混合批次落库+log 版本递增;**原子回滚**(第 N 条失败→前 N-1 条不落);删除依赖序(删 transaction 后删 account 不炸 FK);重推幂等(同 payload 二推→业务表不重复,log 追加可接受)。

## 验证(全部执行并贴证据)

1. `cd yucai/server && go build ./... && go vet ./...`
2. `go test ./internal/sync/... -count=1`(新测绿,先红后绿)
3. `go test ./... -count=1` 全量不回归
4. `make -C yucai test`(若与上同则免)

## 约束

不改 proto/client(T3);不改既有 backup/auth 行为;英文注释与 slog(无 CJK);wire 手改不跑 CLI;不 commit。完成后报告(改动文件+测试输出摘要+wire 镜像点清单)。
