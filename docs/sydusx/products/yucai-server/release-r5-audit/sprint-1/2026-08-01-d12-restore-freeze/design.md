---
feature: 2026-08-01-d12-restore-freeze
status: drafted
---

# Design — D12 restore 期间写冻结(三件套)

> 消费 [spec.md](spec.md)(confirmed)。基建锚点:interceptor 链 `wire/providers.go:932`(Logging→Auth→RequireAdmin;Auth 注入 `userIDKey`/`tenantIDKey` ctx,`GetUserAndTenantIDFromContext` 可取);scheduler ×4(template/holding·debt·goal snapshot/backup)per-tenant fan-out;backup Service 是 restore+UploadExternal 的唯一入口(D6 的 purgeAndImport 已收敛)。

## Context

restore 期间用户写会被 purge 覆盖(静默丢失);scheduler tick 同理。三件套:mutex 串行化 restore 自身 / interceptor 拒用户写 / scheduler 跳过。全部进程内(audit 决策:单 server,无 DB 锁)。

## Goals / NonGoals

- **Goals**:RestoreFreeze 组件 + 写冻结 interceptor + 四 scheduler 插桩 + wire 接线。
- **NonGoals**:D13(feature D)/maintenance mode/跨进程锁。

## Decisions(ADRs)

### ADR-1 `RestoreFreeze` 组件 = backup 模块内 `application/freeze.go`
- **Decision**:`@thread-safe` 结构(mutex 保护的 `map[uuid.UUID]bool` + per-tenant `sync.Mutex`);API 三方法:
  - `Acquire(tenantID) (release func(), err error)`——per-tenant mutex Lock(阻塞等待先来者)+ 置 flag;返回的 release 为 defer 用(清 flag + Unlock);
  - `IsFrozen(tenantID) bool`——interceptor/scheduler 只读探测;
  - 进程单例(wire singleton)。
- **Rationale**:flag 与 mutex 同一结构保证生命周期一致(Acquire 置位/release 清除,不可能只做一半);backup 模块自有(不引新跨模块依赖)。
- **Alternatives**:①DB 级 advisory lock——audit 明确排除(单 server 不需要);②全局 flag——跨租户误伤。

### ADR-2 interceptor = `pkg/middleware/restore_freeze.go`,链位 Auth 之后
- **Decision**:新 `RestoreFreezeInterceptor`(pkg/middleware,对齐既有三件);`wire` 链改为 Logging→Auth→**RestoreFreeze**→RequireAdmin。逻辑:
  1. `GetUserAndTenantIDFromContext`——无 tenant(auth 公共方法/健康检查)→ 放行;
  2. `!freeze.IsFrozen(tenantID)` → 放行(热路径一次 map 读);
  3. 冻结中:**方法分类器**判定——写类前缀(Create/Update/Delete/Record/Buy/Sell/Save/Import/Restore/Upload/Add/Remove/Pause/Resume/Complete/Clone/Apply/Write/Mark/Set)→ `UNAVAILABLE` "正在恢复数据,请稍后";其余(读)放行。
- **方法分类器策略(spec FR-2 的落地)**:**写前缀黑名单**(显式枚举,新增 RPC 前缀需加名单)+ fallback **读白名单**(Get/List/Find/Search/Summary/Export/SyncPrices/GetOIDCConfig/健康)——**双保险:既不在写名单也不在读名单的未知 RPC 默认放行**(避免新读 RPC 被误杀;新写 RPC 漏拦的窗口由 purge+import 的幂等 restore 语义兜底——restore 本身就是全量替换)。middleware 经全局变量注入 freeze 实例(对齐 `TokenService`/`TokenBlacklist` 的既有全局注入模式,避免 wire 链签名扩散)。
- **Rationale**:pkg/middleware 不能 import backup 模块(依赖方向)——接口注入(`RestoreFreezeChecker` 一方法接口在 middleware 定义,backup 实现);前缀分类零 proto 依赖。
- **Alternatives**:①每 service 手工检查——散落且必漏;②proto annotation——工具链成本超收益。

### ADR-3 scheduler 插桩 = 各 scheduler 的 per-tenant tick 头部检查
- **Decision**:四个 scheduler(backup auto-backup/holding snapshot/debt snapshot/goal snapshot/template autoRecord)的 per-tenant 处理体头部加 `if freeze.IsFrozen(tenant) { skip+debug log }`。注入方式:各 scheduler 构造器加可选 `RestoreFreezeChecker`(nil-safe——测试不传则不检查)。
- **Rationale**:tick 头部检查粒度=per-tenant(不影响其他租户);nil-safe 保持既有测试零改动。

### ADR-4 backup Service 接线 = RestoreBackup/UploadExternal 包 Acquire
- **Decision**:backup Service 构造器加 `freeze` 参数;`RestoreBackup` 与 `UploadExternal` 开头 `release, err := s.freeze.Acquire(tenantID)`(err=同租户已在 restore → 直接返回 UNAVAILABLE 语义错误)+ `defer release()`。**flag 由 Acquire 置位**——写 RPC 冻结窗口 = restore 全程(含 safety backup 与文件下载,不仅 tx 段)。
- **Rationale**:冻结窗口覆盖全程比只覆盖 tx 段保守正确(下载大备份文件期间的新写同样会被 purge 覆盖)。

## HLD

```
新增:internal/backup/application/freeze.go(RestoreFreeze + ReleaseFunc)
     pkg/middleware/restore_freeze.go(RestoreFreezeInterceptor + 方法分类器 + RestoreFreezeChecker 接口)
改:  wire/providers.go(interceptor 链插入 + freeze singleton + middleware 全局注入 + 四 scheduler 构造传参)
     internal/backup/application/service.go(RestoreBackup/UploadExternal Acquire 包裹;构造器+freeze)
     四个 scheduler 文件(tick 头部检查;构造器+可选 checker)
```

## LLD 要点

### RestoreFreeze 骨架

```go
type RestoreFreeze struct {
    mu     sync.Mutex
    frozen map[uuid.UUID]bool
    locks  map[uuid.UUID]*sync.Mutex
}
func (f *RestoreFreeze) Acquire(t uuid.UUID) (func(), error) {
    f.mu.Lock(); lk := f.locks[t] (lazy create); f.mu.Unlock()
    lk.Lock()                       // 串行化:阻塞等先来者
    f.mu.Lock(); f.frozen[t] = true; f.mu.Unlock()
    return func() { f.mu.Lock(); delete(f.frozen, t); f.mu.Unlock(); lk.Unlock() }, nil
}
```
(spec FR-1 说"等待或被拒绝"——Go mutex 阻塞等待即实现"等待"分支;若要"拒绝"可改 TryLock,但 audit 原文是"串行化"→ 阻塞等待即可,拒绝语义留给写 RPC。**裁定:阻塞等待**,记录于 design。)

### interceptor 分类器

```go
writePrefixes = []string{"Create","Update","Delete","Record","Buy","Sell","Save","Import","Restore","Upload","Add","Remove","Pause","Resume","Complete","Clone","Apply","Write","Mark","Set"}
// RPC 方法名取 info.FullMethod 末段("/svc/Method" → "Method")
readAllow = []string{"Get","List","Find","Search","Summary","Export","Sync","GetOIDCConfig","Health"}
// 判定顺序:命中 write → 拒;命中 read → 放;未知 → 放(记录)
```

### scheduler 插桩形态(四处同款)

```go
if s.freeze != nil && s.freeze.IsFrozen(tenantID) {
    s.log.Debug("skip: restore in progress", "tenant", tenantID, "op", "autoBackup")
    continue
}
```

### 测试计划

- freeze 单测:Acquire/IsFrozen 生命周期;同租户串行(goroutine 竞争验证第二个 Acquire 阻塞至 release);跨租户并行;release 幂等性。
- interceptor 单测:写前缀拒(UNAVAILABLE+文案)/读放行/未知放行/无 tenant 放行/未冻结放行(mock checker)。
- Service 集成:RestoreBackup 期间 IsFrozen=true(注入检查点)/结束 false;UploadExternal 同。
- scheduler:mock checker frozen → tick 跳过(计数断言);nil checker → 不检查(既有行为)。
- 全套 go test 回归。

## Risks

- **R1 未知新写 RPC 漏拦**(分类器未知放行)——restore 本身全量替换幂等,漏拦写最多丢失该次写(与现状同);新 RPC 上线 checklist 加"写前缀登记"。
- **R2 middleware 全局注入时序**(wire 初始化前请求到达)——nil checker → 放行(与 TokenService nil 同语义,启动窗口可忽略)。
- **R3 scheduler 构造签名变更波及 wire**——四个 provider 函数集中一处改。

## Migration

无 schema/无数据迁移;行为增强。

## Open Questions

1. `SyncPrices`(holding 价格拉取)按读处理(放行)——它写 security 价格表但不在租户业务数据面(全局 reference);若 audit 意图是冻结一切写,execute 时改名单即可(一行)。
