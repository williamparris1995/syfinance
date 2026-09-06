# Feature — F16 server 同步核心硬化(R10 sprint-1)

> 2026-09-03 R10 分解确认(sprint-1 首个 feature)。

## Description

多设备地基的 server 侧:①sync_log 版本并发序列化(F11 观察项:同租户并发 push 在 ReadCommitted 下交错,(tenant_id,version) 非唯一);②RegisterDevice 实现(device 表真身份,F11 时 fallback tenantID);③PullChanges 业务表实现(现只回放 sync_log——按 since_version 增量回放供第二设备拉取);④conflicts 检测基础(push 时版本比对填充 ConflictDTO,替换恒空);⑤跨租户同 id 复合 PK 评估(ent 单列 PK 的 fail-closed 现状→复合 PK 迁移裁决)。约束:F10-F13 单设备语义零回归;契约改动若破坏性→yucai-api vN 切片。

## Stories

- [ ] S1: 并发序列化(版本分配原子化+约束)
- [ ] S2: RegisterDevice 全链
- [ ] S3: PullChanges 业务表回放
- [ ] S4: conflicts 检测基础(版本比对+ConflictDTO)
- [ ] S5: 复合 PK 评估裁决(ADR,不一定实施)
- [ ] S6: server 测试(Tier-A+集成)+单设备回归门

## title

F16 server 同步核心硬化(序列化/设备/拉取/冲突/PK)

## keywords

sync-hardening, sync-log-serialization, register-device, pull-changes, conflict-detection, composite-pk, F16
