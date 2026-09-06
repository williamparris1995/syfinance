# Code Plan — F16 server 同步核心硬化

## Tasks

- [ ] **T1 序列化+设备**:唯一约束迁移+重试循环+吞错修复(S1)+RegisterDevice 幂等/deviceId 硬化/GetSyncStatus 字段(S2)+proto regen;TDD(Tier-A+PG 门控并发测试)。
- [ ] **T2 拉取+冲突**:PullChanges 分页排序(S3)+冲突检测跳过制/CurrentVersion port/ConflictDTO 字段/Resolve 修缮(S4)+mapError(S6=FR-6);TDD 含双设备场景。
- [ ] **T3 ADR+门**:复合 PK ADR 定稿(S5)+契约 README+go test 全量+client 门(go test server 不影响 client,跑 flutter test+F13 契约 e2e 单文件抽验)+提交。

## 执行方式

T1→T2→T3 串行派发,每任务两轴 review,修复循环 ≤5。
