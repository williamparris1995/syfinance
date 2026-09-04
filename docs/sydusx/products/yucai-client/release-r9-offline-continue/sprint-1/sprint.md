# Sprint 1 — R9 离线续写

> Sprint Goal + feature roster。`/sydusx-portfolio`(2026-09-03)。

## Sprint Goal

**绑定后断网可完整记账,回网补同步不丢数据**:F10 查实写路径并落地离线缓冲 → F11 最小同步通路(server 窄幅+契约) → F12 状态指示与冲突规则 → F13 e2e 链路进回归门。

## Feature roster(依赖排序)

- [x] **feature F10** 2026-09-03-offline-write-buffer — 离线写语义与缓冲 ✅ done(2026-09-03,merge `39063da2`;三态路由+写降级+OfflineAuthenticated bug 修复+schema v3 pending/墓碑+镜像永不抹 pending[持仓 PK 冲突实证修复]+同步管线 port[对齐 sync proto,noop 待 F11];TDD 96 新测;四门 GREEN[e2e 11+UI 12+单测 1373];附带修 F9 漏网[债权页搜索栏推卡出屏])
- [ ] **feature F11** server-minimal-sync — server 最小同步通路(形态依赖 F10 design)(claimed: zcode-r9-f11 2026-09-03)
- [ ] **feature F12** sync-status-conflict — 同步状态指示与单设备冲突语义
- [ ] **feature F13** offline-e2e — 断网记账→回网补同步 e2e 链路

## defer

- ticket 16 其余(多设备 sync engine/非空账号合并/存档上云)

## status: pending(F10 ✅;F11-F13 待做)
