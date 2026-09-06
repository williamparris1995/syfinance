# Design — F16 server 同步核心硬化

> R10 sprint-1 · 2026-09-03。查证事实为输入;spec 六决策内嵌推荐。

## ADRs

- **ADR-1 序列化=唯一约束+受限重试**:`(tenant_id, version)` 加 Unique 索引(schema+migration);事务内 Append 撞唯一约束→整个批次事务重试(重新取 LatestVersion,≤3 次,仍撞→Aborted 错误);不选锁定读(无 tenant 行可锁)/不选 per-tenant 序列(SQLite 测试环境无序列,双 DB 兼容优先)。LatestVersion 吞错修复(仅 NotFound→0,其余原样上抛)。
- **ADR-2 RegisterDevice 幂等注册**:`(tenant_id, device_id)` 唯一索引;Register 重复→查既有行返回(幂等);deviceId fallback 退役:空 deviceId→InvalidArgument(单设备 client 现发 'bound' 字面量→parseUUID 得 Nil 落 log 列——**Nil 仍容忍**(F17 接入前的过渡,注释),畸形非空串→错误);GetSyncStatus proto 加 device_id(optional,缺省 tenant 聚合视角——兼容)。
- **ADR-3 Pull=sync_log 回放**:FindSince `ORDER BY version ASC LIMIT n+1`(n=page_size,默认 500 上限 1000);has_more=多取到 1 条;handler 接 proto page_size;响应 latest_version 不变语义。墓碑行(payload 空)原样下发——client 按序应用(upsert/delete)即可。
- **ADR-4 冲突检测=版本比对跳过制**:writer port 扩 `CurrentVersion(ctx, tenantID, entityID) (int64, bool)`(8 实现:find 现行 version,软删行算存在);PushChanges 对 update 路径:server 存在且 `payload.version <= server.version` → 跳过该 change+写 sync_conflicts(conflict_type=version_conflict,双 payload)+响应 conflicts 填充;**批次其余照常**(不整批回滚——多设备下他设备的冲突不应阻断本设备无冲突变更,注释与单设备批次原子语义的边界:原子性指"落库的要么全落",冲突是显式跳过非失败)。proto ConflictDTO 加 conflict_type(enum string,非破坏)。
- **ADR-5 复合 PK:不迁移(ADR 定稿)**:理由——uuid v4 单对碰撞 2^-61;现状 fail-closed(撞 PK 整批失败)安全;ent 复合 PK 重写全库谓词成本 vs 收益失衡;兜底=RegisterDevice 真身份+sync_log 审计。记 ADR 于 feature ledger。
- **ADR-6 mapError 保真**:NotFound→NotFound / 乐观锁与序列化重试耗尽→Aborted / 校验→InvalidArgument / 其余→Internal(照 backup_handler 映射惯例,查实现时对照)。

## HLD 改动面

`internal/sync/`(schema 两处 Unique+migration、service[重试循环/检测/拉取分页]、repo[吞错/ORDER+LIMIT/Resolve 修缮/幂等 Register/CurrentVersion port 实现]、handler[page_size/deviceId 硬化/mapError]、conflict.go[真检测接入])+ writer port + 8 writer CurrentVersion + proto(sync.proto 加 2 字段,buf paths 加 sync regen)+ 契约 README。

## Risks

| 风险 | 缓解 |
|---|---|
| 单设备回归(client 现发 'bound'→Nil deviceId) | ADR-2 Nil 过渡容忍;F13 契约 e2e+全量守门 |
| proto 改动 regen(工具链坑) | buf paths 手工加 sync(F11 查证惯例);gen-dart 全量 |
| 冲突跳过破坏既有测试(批次原子断言) | 检测仅在"server 存在且版本不落后"触发,单设备 push 永远是最新版→不触发;测试钉 |
| PG 并发测试环境依赖 | 门控 skip(无 PG 环境不红) |

## Open Questions

无(实现自由度已授权)。
