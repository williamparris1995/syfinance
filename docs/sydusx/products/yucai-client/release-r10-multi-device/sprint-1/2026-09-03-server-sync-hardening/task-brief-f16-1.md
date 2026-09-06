# Task Brief F16-T1 — 版本序列化 + RegisterDevice 全链

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r10-f16`,server 在 `yucai/server/`。**TDD(Go)。**

## 先读(必读)
1. `docs/.../2026-09-03-server-sync-hardening/{spec.md FR-1/2,design.md ADR-1/2}`
2. 查证锚点:`internal/sync/ent/schema/sync_log.go:43-48`(非唯一索引)、`sync_device.go:27-42`(无唯一约束)、`application/service.go:145-209`(RC 事务+读→+1→Append)、`adapter/driven/repository/sync_repo.go:82-92`(LatestVersion 非锁定读+**:86-90 吞错**)、`:114-123`(Register 纯 Create)、`adapter/driving/grpc/sync_handler.go:76-81/232-235`(fallback+parseUUID 吞错)、`tests/holding_pg_rollback_integration_test.go:46-63`(PG 门控范式)
3. proto:`yucai/proto/sync/v1/sync.proto:50`(GetSyncStatusRequest 空——加 device_id)+ `buf.gen.go.yaml`(paths 需手工加 sync 定向 regen——F11 查证惯例;Dart 侧 `make gen-dart` 全量,**本任务只 regen Go**——client 未改字段不用,但生成物保持双端同步更稳,自行判断并注释)
4. F11 交付的既有测试(`internal/sync/application/service_push_test.go` 8 测+`tests/sync_push_integration_test.go` 5 集成)——零回归守门

## 交付物
### S1 序列化(ADR-1)
1. sync_log schema:`(tenant_id, version)` 索引加 `.Unique()`;sync schema migration(ent 自动建表环境直接新约束;**既有部署库的迁移**——server 侧有无生产迁移机制?查证:provider 启动 Schema.Create 自动迁移,ent 会处理加索引;注释说明)。若现代c sqlite 建唯一索引与既有脏数据冲突——测试库全新无脏数据,注释即可。
2. `LatestVersion` 吞错修复:仅 ent NotFound→(0,nil);其余错误原样上抛。
3. service.PushChanges 重试循环:撞唯一约束(pgcode/sqlite 1555/2067 族,或 ent 错误串判定——按双 DB 兼容写 helper 判定,注释)→**整个 sqltx 重开**(重新 LatestVersion+重放 writes+logs),≤3 次,仍撞→Aborted。注意重试不改 push 语义(幂等 upsert 保证重放安全——注释论证)。
4. **PG 门控并发测试**(`tests/sync_concurrency_pg_test.go` 新,照 holding_pg_rollback 范式:YUCAI_PG_E2E_URL 门控 skip+沙箱建库):两 goroutine 并发 PushChanges 同租户(各 N 条)→全部成功或可数失败,`COUNT(DISTINCT version)=COUNT(version)` 且无空洞>1(连续性尽力断言,注释放宽理由);**修复前该测试应红**(并发重复版本)——PG 环境不可用时 t.Skip,注释说明该测试的验证价值。
5. Tier-A 单连接测试:重试路径的单元可测性(SQLite 单连接撞号场景构造:预插 log 行制造冲突→重试成功)——设计可测缝(如内部重试计数暴露或错误注入),实现者定,注释。

### S2 RegisterDevice(ADR-2)
1. sync_devices schema 加 `(tenant_id, device_id)` Unique(device_id 即表主键 id?——**schema 主键就是 id=device uuid**,所以唯一约束应为 `(tenant_id)` 内 id 天然唯一……重新查证:device 表主键 id 就是 deviceId,tenant+id 唯一性由 PK 保证;**重复注册幂等**的实现=Register 前 Find(id)存在且 tenant 匹配→返回既有行。schema 无需新索引(PK 即约束)——按此实现并注释;若查证发现 device_name 才是用户键则另行裁决)。幂等 Register:存在→返回既有(带现 last_sync_version);不存在→create。
2. handler deviceId 硬化:PushChanges/GetSyncStatus 的 deviceId 解析——空串→InvalidArgument("device_id required");**uuid.Nil 显式容忍**(单设备 client 'bound' 字面量过渡,注释 F17 退役);畸形非空串→InvalidArgument。fallback tenantID 退役。
3. `GetSyncStatusRequest` 加 `string device_id = 1`(optional 语义——proto3 无 optional 也行,空串=聚合视角走 tenant);handler 按设备过滤(空=tenant 聚合,保持兼容);`RegisterDeviceRequest` 现状核对(device_name)。
4. proto regen:buf.gen.go.yaml paths 加 sync/v1/sync.proto→`make -C yucai proto`(或直接 buf 命令,照 Makefile 惯例)——**regen 后 diff 检查生成物只增不改**;Dart 侧若跑 gen-dart 全量,生成物 diff 应只有 sync 两 message——纳入提交。
5. TDD:RegisterDevice 幂等(重复注册同 id 返回同行)/空 deviceId 报错/Nil 容忍/畸形报错;GetSyncStatus 设备过滤;既有测试的 deviceId 用例适配(fallback 退役后,既有测试若依赖 fallback——改为显式 device uuid,单设备语义断言不变,注释)。

## 验证
1. `go build ./... && go vet ./...`
2. `go test ./internal/sync/... -count=1`(新测绿+既有 27 不回归)
3. `go test ./tests/ -run TestSync -count=1`(集成 5+新并发[skip 无 PG])
4. `go test ./... -count=1` 全量
5. **client 侧零回归确认**:server deviceId 硬化后,client 'bound'→Nil 仍容忍(集成测试用真实 'bound' 字面量路径补一例,或注释论证 Nil 分支覆盖)

## 约束
英文注释/slog;F10-F13 语义零回归;wire 不动(无新依赖);不 commit。完成后报告。
