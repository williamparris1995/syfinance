# Task Brief F18-T1 — server 触达修复 + 解决落库 + 修缮

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r10-f18`,server 在 `yucai/server/`,proto `yucai/proto/`。**TDD。**

## 先读(必读)
1. `docs/.../2026-09-06-conflict-resolution/{spec.md FR-1/3/6/7,design.md ADR-1/3/7}`
2. 查证锚点:`internal/sync/application/service.go:328-331`(UPDATE-only 检测)/`:255-262`(注释)/`:534-542`(ResolveConflict 纯标记)/`conflict.go:20-46`(死代码)/`sync_repo.go:249-295`(FindPending 无 ORDER BY+IDGTE 重复)/`:311-332`(Resolve repo)/`sync_handler.go:222-238`(不读 merged_payload)/`entitywriter/`(9 writer+CurrentState port)
3. 既有测试:`application/service_conflict_test.go`(10 测——**语义更新对象**)、`tests/sync_pull_conflict_integration_test.go`、F11 的 `service_push_test.go`(幂等重推断言=log 追加——**F18 短路语义后需更新**)

## 交付物
### 1. 检测统一(ADR-1, FR-1)
PushChanges 循环重写检测段:
- 任意 operation(CREATE/UPDATE)且实体在 server 存在(CurrentState.exists):
  - **payload 逐字节相同** → 静默跳过(不记冲突/不耗版本/**不写 log**)——幂等重推语义收紧;
  - **不同且 probe.Version <= server.version** → 冲突(跳过+sync_conflicts 记录[client_payload+server_payload+version_conflict]+响应携带);
  - **不同且 probe.Version > server.version** → 正常落库(Upsert+log)。
- 不存在 → 落库(无论 CREATE/UPDATE)。
- DELETE 不检测(照旧)。
- **测试语义更新**:F11 幂等重推测试(重推 log 追加断言)→ 改为重推零新增 log(短路);F16 冲突 10 测中 CREATE 不查测→改 CREATE 同 id 存在才查;新增:同 payload 短路/CREATE-CREATE 不同 payload 冲突/版本超前落库。

### 2. ResolveConflict 落库(ADR-3, FR-3)
- service 签名扩 `payload []byte`(handler 读 req.MergedPayload 透传——client 分支忽略 merged 参数用 conflict 行 client_payload;merged 分支空 payload→InvalidArgument)。
- `client`/`merged` 分支:sqltx{writer.Upsert(对应 payload)+ logRepo.Append(entity_type/entity_id from conflict 行,version=payload 内 probe.Version,operation=UPDATE)};`server` 分支:仅标记。
- handler:merged_payload 读取+透传;响应仍 Empty。
- TDD:client-wins 落库+log 可 pull/merged 落库/server-wins 零动作/空 merged 拒绝。

### 3. FindPending 修缮(ADR-7, FR-6)
- `ORDER BY created_at DESC, id DESC`;keyset(cursor=(created_at,id) 元组,`OR(created_at<? , AND created_at=? AND id<?)`——SQLite/PG 兼容写法实现时验证);边界重复修复测试。
- proto ConflictDTO 加 `google.protobuf.Timestamp created_at = 8`(非破坏);domain 有 CreatedAt(查证)→ DTO/proto 映射补;buf regen Go(paths 已含 sync);Dart regen(protoc_plugin 已装,gen-dart 流程照 F17——**F13 手补丁重套警示**)。

### 4. 死代码删除(FR-7)
`conflict.go` 全文件删(Resolver/DetectConflict 零引用查证过);service 构造注入清理(wire/providers 相应——若 ConflictResolver 仅此处用则一并删 provider;查证后最小清理)。

## 验证
1. `go build/vet`
2. `go test ./internal/sync/... -count=1`(新测+语义更新后既有全绿)
3. `go test ./tests/ -run TestSync -count=1`
4. `go test ./... -count=1` 全量
5. Dart regen diff 面(仅 sync 两 message)+client `flutter test` 抽验(proto 变化零客户端破坏)

## 约束
英文注释/slog;F16/F17 已交付语义零回归(除授权的幂等重推语义收紧);wire 手改惯例;不 commit。完成后报告(含:检测矩阵测试清单/语义更新 diff 摘要/Dart regen diff 面)。
