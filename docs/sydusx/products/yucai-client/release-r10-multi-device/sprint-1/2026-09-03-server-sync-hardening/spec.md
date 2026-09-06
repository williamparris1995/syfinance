# Spec — F16 server 同步核心硬化

> R10 sprint-1 · 2026-09-03 · analysis 产出(代码级查证:8 硬伤对照现状 #3#8 已修/#1#2#4#5#6 在修/#7 字段在未用)。

## Requirements

- **FR-1 版本序列化**(硬伤 #2):`(tenant_id, version)` 唯一约束 + 事务内 Append 撞号重试(限定次数);**前置必修**:LatestVersion 吞错缺陷(所有查询错误→0,真实故障会被当空日志从 v1 重分配);并发验证走 PG 门控范式(`YUCAI_PG_E2E_URL`,SQLite 单连接测不出)。
- **FR-2 RegisterDevice 全链**(硬伤 #4):deviceId 真实化——handler fallback 退役为"空 deviceId=错误"(fail-closed;client F17 接入后不再发空);parseUUID 硬化(畸形非空→错误而非静默 Nil);`GetSyncStatusRequest` 加 `device_id` 字段(非破坏);sync_devices 加 `(tenant_id, device_id)` 唯一裁决(重复注册幂等返回既有行 vs 报错——设计定,推荐幂等);UpdateSyncVersion 沿用 F11 租户谓词。
- **FR-3 PullChanges 业务表回放**:经 sync_log 回放(payload 已存完整实体 JSON,可重建性查证在案)——FindSince 加 `ORDER BY version ASC` + `LIMIT page_size+1`;handler 接 page_size、算 has_more;默认 page_size(500?)与上限;entity_types 过滤保留;**排序契约注释钉死**(client 按序应用)。墓碑保留期/GC 不做(YAGNI,注释)。
- **FR-4 conflicts 检测基础**(硬伤 #1):PushChanges 循环内,对 update 型 change 比对 server 现行版本(writer port 扩读口 `CurrentVersion(ctx,tenant,entityID)` 或经业务 repo——设计定);`client.version <= server.version 且 payload 不同` → 记 sync_conflicts 行(server/client payload 双存)+该 change 跳过不落库+计入响应 conflicts(批次其余照常,不整批回滚——多设备语义注释);create(新实体)不检测;DELETE 不检测。proto ConflictDTO 加 `conflict_type` 字段(非破坏)。**顺带必修**:repo Resolve 补租户谓词+resolved_at 写入+resolution 合法值校验(存量缺陷)。检测规则细化/解决流=F18。
- **FR-5 复合 PK ADR**(S5):产出 ADR 记录裁决(倾向:不迁移——uuid v4 碰撞概率 2^-61 可忽略,现状 fail-closed 安全,ent 复合 PK 改造成本全库谓词重写;靠 RegisterDevice 真身份+审计兜底)——design 阶段定稿。
- **FR-6 mapError 修复**(硬伤 #5):错误码保真(NotFound→NotFound/Validation→InvalidArgument/冲突→Aborted 等,照库内其他 handler 的映射惯例)。
- **FR-7 测试与门**:PullChanges/RegisterDevice/conflicts 零测试→补齐(Tier-A+集成,双设备语义:两 deviceID 交替 push/pull 一致性);**PG 门控并发测试**(两 goroutine 并发 push 同租户→版本无重复无丢失);F10-F13 单设备语义零回归(既有 32 测+全量);契约 README 登记(新增字段向后兼容)。

## NFR

单设备零回归(F13 契约 e2e 与 client 单测不红——client 未改,server 行为对单设备等价);英文 slog;DDD/port 约束。

## Scope boundary

| 排除 | 理由 |
|---|---|
| 冲突解决流(ResolveConflict 实现/UI/server-wins 之外的规则) | F18 |
| 墓碑 GC/保留期 | YAGNI |
| 复合 PK 实施(若 ADR 裁决不做) | 成本/收益 |
| client 侧任何改动 | F17 |

## Grill record

| 决策 | 定案 |
|---|---|
| R10 分解 | 用户确认(两 sprint 五 feature) |
| 序列化机制/拉取源/冲突基础规则/幂等注册 | 技术推荐(spec 内嵌,用户可推翻) |

## Feasibility

technical ✓(查证:全链骨架在,payload 可重建性成立,PG 并发范式现成);economic ✓;operational ✓(PG 门控测试可跳过无 PG 环境)。
