# Task Brief F11-T2 — server 集成测试 + 契约登记

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r9-f11`。T1(f7b8762c)已就绪。本任务较小:tests/ 目录的 gRPC 级集成 + 契约 README。

## 先读(必读)

1. spec FR-6 + design LLD
2. `yucai/server/tests/` 既有 19 个集成测试的组织(package tests;Tier-A 内存 sqlite 样板 `account_integration_test.go:19-43`)
3. `docs/sydusx/portfolio/contracts/yucai-api/README.md`(变更记录格式样例)
4. T1 的 `internal/sync/` 全链(已交付)

## 交付物

### 1. gRPC 级集成测试(`yucai/server/tests/sync_push_integration_test.go` 新)

经 handler 层(非直接调 service)验证端到端:
- **多模块混合批次**:account+transaction+tag 一次 PushChanges→三表落库+log 版本连续;PushResponse.synced_version 正确。
- **真实 payload 形态**:payload bytes 用 backup envelope 同构 JSON(domain struct 序列化,camelCase/PascalCase 按其 json tag——以 account domain 的 json tag 实际形态为准构造,验证 T3 client 编码契约的 server 侧接受面);枚举 string 形态。
- **完整回滚**(handler 级:非法 payload 混入→gRPC error+零落库)。
- **tenant 隔离**(双租户同 id 各自落库/互不可见)。
- **DELETE→再 upsert 同 id**(复活语义端到端)。
- slog 断言不做(输出不可捕获则免,注释说明)。

### 2. 契约登记(`docs/sydusx/portfolio/contracts/yucai-api/README.md`)

「变更记录」追加 bullet(照尾部队既有格式,含日期/向后兼容声明):
- 2026-09-03(R9 F11,向后兼容):sync/v1 PushChanges 首次实装——payload bytes=各模块 domain JSON(envelope 行同构),entity_type∈8 模块名,CREATE/UPDATE=upsert 单设备语义(信任 client version),DELETE=硬删;批次原子;零 proto 改动。消费方 yucai-client F10 OfflineSyncPort 对接(T3)。

## 验证

1. `cd yucai/server && go test ./tests/ -run TestSyncPush -count=1 -v` 新测绿(先红后绿)
2. `go test ./... -count=1` 全量
3. go build/vet

## 约束

不改 lib 代码(T1 已定;集成测试暴露的 bug 若有→报告,小修可做+注释);英文注释;不 commit。完成后报告。
