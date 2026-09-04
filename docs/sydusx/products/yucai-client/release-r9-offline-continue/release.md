# R9 · 离线续写(offline-continue)

> 立项 2026-09-03。来源:R6 defer ticket 16 线之①(用户拍板"只做离线续写"起步);解 M1 时代接受的"绑定后离线=降级"矛盾。
> 与 R8 design-v2 并行(R8 的 F8 标签维度仍待认领,并行线有先例);server 线仅为最小同步通路窄幅复线,不重开 R5 sprint-3。

## Goal

绑定服务器账号后断网仍可完整记账(本地续写,复用 R6 本地管道),回网自动补同步;单设备语义下不丢数据、冲突规则明确。多设备同步(完整 sync engine)仍留 ticket 16,不在本 release。

## Scope

### IN
- **F10 离线写语义与缓冲**(client):绑定态断网本地续写 + 未同步写集合跟踪 + 回网触发。
- **F11 server 最小同步通路**(server 窄幅):离线批次补同步 RPC(复用/扩展 UploadBackup 或 op-log,由 F10 查实写路径后定)+ yucai-api 契约版本化。
- **F12 同步状态与冲突语义**(client):同步状态指示(待同步 N 笔/同步中/已同步)+ 单设备冲突规则。
- **F13 E2E 离线链路**(client):断网记账→回网补同步→两端一致 e2e 进回归门。

### OUT / Defer
- 多设备同步 / sync engine / server sync 8 硬伤修复(ticket 16 全量)
- 非空账号绑定合并、存档上云(ticket 16 线其余项)
- 实时行情离线化(Yahoo 天然在线,离线展示最后快照——R6 语义不变)

## 硬约束

- 离线写必须走 R6 已建立的真实本地 DS 管道(与 guest 模式同管道,e2e 链路天然可测)。
- server 改动收窄在同步通路 RPC + 契约;DDD 四层与跨模块 port 约束照旧。
- 回归门:make client-e2e / client-e2e-ui / flutter test 全绿不回归。

## Sprint roster

- [x] sprint-1:F10 ✅(2026-09-03,merge `39063da2`)→ F11 → F12 → F13(依赖序;F11 形态已定:激活休眠 sync proto 增量 RPC+孤儿台账 ticket)

## done-criteria

四 feature 全 done + 断网续写 e2e 链路绿 + 契约 CURRENT 版本化 + server go test 全绿。

## status: pending
