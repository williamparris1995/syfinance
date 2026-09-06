# Feature — F16 server 同步核心硬化(R10 sprint-1)

> 2026-09-03 R10 分解确认(sprint-1 首个 feature)。

## Description

多设备地基的 server 侧:①sync_log 版本并发序列化(F11 观察项:同租户并发 push 在 ReadCommitted 下交错,(tenant_id,version) 非唯一);②RegisterDevice 实现(device 表真身份,F11 时 fallback tenantID);③PullChanges 业务表实现(现只回放 sync_log——按 since_version 增量回放供第二设备拉取);④conflicts 检测基础(push 时版本比对填充 ConflictDTO,替换恒空);⑤跨租户同 id 复合 PK 评估(ent 单列 PK 的 fail-closed 现状→复合 PK 迁移裁决)。约束:F10-F13 单设备语义零回归;契约改动若破坏性→yucai-api vN 切片。

## Stories

- [x] S1: 并发序列化(版本分配原子化+约束)
- [x] S2: RegisterDevice 全链
- [x] S3: PullChanges 业务表回放
- [x] S4: conflicts 检测基础(版本比对+ConflictDTO)
- [x] S5: 复合 PK 评估裁决(ADR,不一定实施)
- [x] S6: server 测试(Tier-A+集成)+单设备回归门

## title

F16 server 同步核心硬化(序列化/设备/拉取/冲突/PK)

## keywords

sync-hardening, sync-log-serialization, register-device, pull-changes, conflict-detection, composite-pk, F16


## ADR-5 复合 PK:不迁移(定稿)

**Decision**:8 模块 ent 保持单列 uuid PK,不迁 (tenant_id,id) 复合 PK。
**Rationale**:①uuid v4 单对碰撞概率 ~2^-61(122 随机位),家庭规模租户数下可忽略;真实风险仅来自 Nil/确定性种子/跨环境导入——由 RegisterDevice 真身份(F16)+sync_log 审计行兜底;②现状跨租户同 id 为 fail-closed(UpsertForSync 按 id+tenant 查 miss→Create 撞 PK→整批失败,F11 集成测试钉),无静默污染路径;③ent v0.14 复合 PK 需重写 8 模块+backup+sync 全部 ID 谓词(每一处 UpdateOneID/Where(ID)),成本/收益严重失衡。
**Alternatives**:复合 PK(拒,成本);前置租户号段化 id(拒,复杂化 client)。
**Consequences**:跨租户恶意 id 劫持尝试表现为整批失败(Aborted),非静默——可接受。

## Ledger 记账

| task | 状态 | fix-rounds | 记事 |
|---|---|---|---|
| T1 序列化+设备 | ✅ | 1(2 nit:测试注释矛盾/PG 测试名覆盖) | PG 并发测试实证修复前重复(96 版本仅 72 唯一);T1 review nit3(rawDesc 纠偏)nit4(EntityID parseUUID 残留)→T2 完成 |
| T2 拉取+冲突 | ✅ | 0(review 7/7,4 裁量全合理) | spec FR-4 "payload 不同"被 ADR-4 删——同 payload 重推记良性冲突,F18 短路回收;死代码 resolver 清理=F18;设备 bump 与冲突跳过的调和=F17/F18 |
