---
feature: 2026-08-01-d12-restore-freeze
status: confirmed
---

# Spec — D12 restore 期间写冻结(三件套)

> R5 sprint-1 feature C(audit 04 决策点 3,原文照抄)。现状:restore 进行中时 scheduler(autoRecord/snapshot/auto-backup)与用户写 RPC 可并发竞争 destructive purge+import——D6 的 tx 原子性保证**外部读**只看到 restore 前/后一致状态,但**restore 期间的用户写会被 purge 覆盖**(静默丢失)。
> 基建事实:interceptor 链在 `wire/providers.go:932`(Logging→Auth→RequireAdmin,Auth 注入 tenant_id);backup scheduler per-tenant fan-out;holding snapshot/goal/template scheduler 各自 tick。

## ADDED Requirements

### Requirement: FR-1 per-tenant restore mutex(串行化同租户并发 restore)
- [ ] 同一 tenant 的并发 restore(含 UploadExternal)SHALL 被串行化:第二个 restore 等待或被拒绝(明确 `UNAVAILABLE`+"正在恢复数据,请稍后");不同 tenant 互不阻塞。

### Requirement: FR-2 写 RPC 冻结(middleware interceptor)
- [ ] restore 进行中(持有 flag)的 tenant,其**写 RPC**(方法名 Create*/Update*/Delete*/Record*/Buy*/Sell*/Save*/Import*/Restore*/Upload*/Add*/Remove*)SHALL 返回 `UNAVAILABLE` + "正在恢复数据,请稍后";**读 RPC 放行**(List*/Get*/Find*/Search*/Summary*/Export*——D6 原子 tx 保证读只见到一致前后态)。拦截点 SHALL 位于 AuthInterceptor 之后(需 tenant_id);backup 自身的 Restore/Upload 入口**不豁免**(mutex 已串行化它们)。
- [ ] 白名单机制:被冻结判定排除的 RPC(如健康检查/认证自身)SHALL 显式清单化,不靠命名猜测。

### Requirement: FR-3 scheduler 跳过
- [ ] autoRecord(template)/snapshot(holding·debt·goal)/auto-backup(backup)各 scheduler 的 per-tenant tick SHALL 检查同 flag,命中即跳过该 tenant 该 tick(记 debug 日志,不算错误;下一 tick 重试)。

### Requirement: FR-4 flag 生命周期
- [ ] flag SHALL 在 restore(含 UploadExternal)开始时置位、结束时(defer)清除——panic 路径同样清除;flag 为进程内内存态(单 server,audit 决策:无需 DB 级锁)。

### Requirement: NFR-1 质量基线
- [ ] `go test ./...` 全绿;新组件单测(mutex 并发/interceptor 白名单黑名单/scheduler 跳过);零 client 改动。

### Requirement: NFR-2 scope 排除项
- [ ] 本 feature SHALL NOT 做:D13 加密分层(feature D)/maintenance mode(全租户冻结,误伤——audit 明确排除)/DB 级锁/跨进程锁(单 server 假设)。

## scope boundary

- **IN**:RestoreFreeze 组件(per-tenant flag+mutex)/写冻结 interceptor + 方法名分类器/四个 scheduler 的跳过检查/wire 接线。
- **OUT**:D13(feature D)/pg_dump/maintenance mode/多进程协调。
- **依赖**:03 sqltx(done)/D6 restore 原子(done——读一致性由它背书)。

## 可行性

- **technical**:可行——三件套全部进程内组件;interceptor 链已有先例(AuthInterceptor);scheduler 加一个检查调用。
- **economic**:小——一个组件+一个 interceptor+四处 scheduler 插桩。
- **operational**:单 server 内存态,无运维面。
