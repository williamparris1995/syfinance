# Code Plan — F11 server 最小同步通路

> execute 分解。约束:TDD;go test/flutter test 全量不回归;wire 手改 4 处镜像;英文 slog。

## Tasks

- [x] **T1 server 写入链**:SyncEntityWriter port+8 实现+service 事务化(批次原子/版本事务内递增/DELETE 依赖序)+DI 4 处镜像+Tier-A 单测(upsert/删除/原子回滚)。验证:go test 定向+全量。
- [x] **T2 server 集成+契约**:PushChanges 集成测试(跨模块批次/重推幂等/tenant 隔离/枚举映射)+go test 全量+契约 README 登记。
- [x] **T3 client 接线**:exporter 行序列化抽取+GrpcOfflineSyncPort(deviceId fallback/错误→失败)+collector domain 实体化+孤儿分红合成头行(ADR-6)+DI 替换 noop+单测。验证:flutter test 全量+analyze。
- [x] **T4 全量门**:go test 全量+flutter test+client-e2e 基线(在线 guest 链路不回归;断网→回网→真 server 的完整 e2e 归 F13)+提交。

## 执行方式

T1→T2(server 侧)→T3(client)→T4 串行派发,每任务两轴 review,修复循环 ≤5。


## Ledger 记账

| task | 状态 | fix-rounds | 记事 |
|---|---|---|---|
| T1 server 写入链 | ✅ | 1(device 行租户谓词+payload-id 一致性 fail-closed+2 回归测) | UpsertForSync 全字段×8(软删复活/immutable create-only);批次原子 sqltx;DELETE purge 序;wire 4 处手改 |
| T2 集成+契约 | ✅ | 0(review 7/7) | wire 形态钉死(envelope 同构);跨租户同 id=物理 PK 冲突 fail-closed(发现记 ticket 16 评估) |
| T3 client 接线 | ✅ | 1(deviceId 措辞×3 处) | envelope_codec 单一事实源;S-1 孤儿台账收敛=合成头行锚定+台账上行留 ticket 16;collector 路径 (b) 变体(facts:exporter 事实源=drift 行) |
| T4 全量门 | ✅ | 0 | go 64 包/flutter 1397/e2e 全绿;spec FR-1 "camelCase" 口径实为 PascalCase(brief 已授权以实装为准,此行即勘误) |
