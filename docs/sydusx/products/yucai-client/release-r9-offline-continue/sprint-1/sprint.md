# Sprint 1 — R9 离线续写

> Sprint Goal + feature roster。`/sydusx-portfolio`(2026-09-03)。

## Sprint Goal

**绑定后断网可完整记账,回网补同步不丢数据**:F10 查实写路径并落地离线缓冲 → F11 最小同步通路(server 窄幅+契约) → F12 状态指示与冲突规则 → F13 e2e 链路进回归门。

## Feature roster(依赖排序)

- [x] **feature F10** 2026-09-03-offline-write-buffer — 离线写语义与缓冲 ✅ done(2026-09-03,merge `39063da2`;三态路由+写降级+OfflineAuthenticated bug 修复+schema v3 pending/墓碑+镜像永不抹 pending[持仓 PK 冲突实证修复]+同步管线 port[对齐 sync proto,noop 待 F11];TDD 96 新测;四门 GREEN[e2e 11+UI 12+单测 1373];附带修 F9 漏网[债权页搜索栏推卡出屏])
- [x] **feature F11** server-minimal-sync — server 最小同步通路 ✅ done(2026-09-03,merge `745a4aa1`;PushChanges 落 8 业务表[批次原子/全字段 upsert/墓碑硬删依赖序/租户防注入+payload-id fail-closed]+client GrpcOfflineSyncPort[wire 双侧钉死,envelope_codec 单一事实源]+孤儿分红合成头行+契约登记;server TDD 27+5 集成,client 23;三门 GREEN[go 64 包/flutter 1397/e2e];ticket 16 增 4 项在案)
- [x] **feature F12** sync-status-conflict — 同步状态指示 ✅ done(2026-09-03,merge `a1f015f7`;顶栏四态徽标[待同步N含墓碑/同步中/失败重试/干净隐藏,仅绑定态]+9 流实时计数+构造期补扫[条件注入恢复前提];TDD 25 新测+三门 GREEN[管道11+UI12+1422 单测];review 根治 bloc 子类型派发陷阱/陈旧计数覆盖/guest 构造前提)
- [x] **feature F13** offline-e2e — 断网记账→回网补同步 e2e 链路 ✅ done(2026-09-03,merge `7f2345c2`;消费方契约测试 CDC[进程内假 SyncService+真 gRPC 线协议,wire 断言与 server 提供方测试逐字段一致,失败重试/重推幂等];REJECT 轮修复 pbjson 误改字节;E2E_FILES 12 文件)

## defer

- ticket 16 其余(多设备 sync engine/非空账号合并/存档上云)

## status: done(F10 ✅ F11 ✅ F12 ✅ F13 ✅,2026-09-03——R9 sprint-1 收官)
