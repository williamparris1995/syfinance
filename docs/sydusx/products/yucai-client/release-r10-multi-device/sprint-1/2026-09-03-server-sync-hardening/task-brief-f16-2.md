# Task Brief F16-T2 — PullChanges 分页 + 冲突检测跳过制 + mapError 保真

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r10-f16`,server 在 `yucai/server/`。**TDD。** T1 已就绪(序列化/设备)。

## 先读(必读)
1. `docs/.../2026-09-03-server-sync-hardening/{spec.md FR-3/4/6,design.md ADR-3/4/6}`
2. 查证锚点:`application/service.go:276-293`(PullChanges 现状)+`sync_repo.go:53-77`(FindSince 无 ORDER/LIMIT)+`sync_handler.go:112-140`(page_size 不读/HasMore 硬编码 false)+`:237-239`(mapError 塌缩 Internal)+`application/conflict.go:11-46`(resolver 死代码+DetectConflict 启发式)+`sync_repo.go:230-238`(Resolve 三缺陷:无租户谓词/resolved_at 不写/resolution 不校验)+`domain/entity_writer.go`(port 扩点)
3. F11 的 writer 实现(`adapter/driven/entitywriter/`×8)——CurrentVersion 扩展落点
4. proto `sync.proto`(ConflictDTO 加 conflict_type;PullChangesRequest page_size 已有)
5. 既有 33 测(sync 模块+集成)零回归守门;单设备语义:冲突检测在"server 存在且 client.version<=server.version"触发——单设备 push 永远最新→不触发(注释论证+测试钉)

## 交付物
### S3 PullChanges(ADR-3)
1. FindSince:`ORDER BY version ASC` + `LIMIT n+1`(n=page_size;default 500/max 1000,handler 夹紧);has_more=多取 1 条;entity_types 过滤保留;latest_version 语义不变。
2. handler 接 page_size;响应契约注释(客户端按 version 序应用,upsert/delete 幂等重放)。
3. TDD:排序(乱插 version 序断言)/分页边界(n/n+1/entity_types)/page_size 夹紧/空集。

### S4 冲突检测跳过制(ADR-4)
1. writer port 扩 `CurrentVersion(ctx, tenantID, entityID) (int64, bool)`;8 实现(find 现行 version;软删行=存在[其 version];miss=false)。
2. service.PushChanges 循环内:UPDATE 型 change → CurrentVersion;`存在 && payload.version <= server.version` → 跳过落库+写 sync_conflicts(conflict_type=version_conflict/server_payload=server 现行实体 JSON——**需读回 server 实体**(writer port 再扩读口或经业务 repo?**最小**:CurrentVersion 扩成 `CurrentState(ctx,tenant,id) (version int64, payload []byte, exists bool)`——payload=server 实体 JSON(经 domain 序列化,与 push payload 同形态[envelope PascalCase];实现:writer 内 find→domain 实体→json.Marshal,与 exporter Import 的反序列化对偶)/client_payload=原 change payload)+计入响应 conflicts;批次其余照常(原子性边界注释)。
3. proto ConflictDTO 加 `string conflict_type = 7`(非破坏);conflictToProto 不再丢 ConflictType。proto regen(Go;Dart 推迟 F17 照 T1)。
4. Resolve 修缮:租户谓词+SetResolvedAt+resolution 白名单校验(server_wins/client_wins/merged——值域定案注释)。
5. **顺带硬化(T1 review nit 4)**:EntityID/conflictID 的 parseUUID 不吞错(畸形→InvalidArgument)。
6. TDD:冲突触发(双设备 A push v2→B push 旧 base v1→跳过+conflicts 填充+server_payload 正确)/不触发(新实体/版本更新)/**单设备不触发**(push 最新版→零冲突)/批次混合(1 冲突+2 正常→2 落库+1 conflict)/Resolve 修缮三缺陷/ListConflicts 填充。

### S6=FR-6 mapError 保真(ADR-6)
NotFound→codes.NotFound/ErrVersionConflict→Aborted(已有)/校验→InvalidArgument/其余→Internal;照库内其他 handler 惯例(查 backup/debt handler 的 mapError 形态对齐)。TDD:错误码断言。

## 验证
1. `go build/vet`
2. `go test ./internal/sync/... -count=1`(新测+既有零回归)
3. `go test ./tests/ -run TestSync -count=1`(集成+PG)
4. `go test ./... -count=1` 全量
5. **单设备 e2e 抽验**:client 侧零改动确认——F13 契约 e2e 文件跑一遍(`cd ../client && flutter test integration_test/link_offline_sync_e2e_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`,杀残留)绿=单设备语义守门

## 约束
英文注释/slog;F10-F13 零回归;wire 仅在必要处手改(CurrentState 若需注入——writer 已聚合,大概率零 wire 改动);不 commit。完成后报告。
