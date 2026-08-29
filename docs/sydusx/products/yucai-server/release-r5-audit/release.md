# Release — R5 御财审计整改

> Release Goal + sprint roster + done-criteria。由 `/sydusx-run` 分解(2026-08-01);2026-08-05 归位 yucai-server 产品(R5 scope 全 server-side)。
> 源自 [.scratch/yucai-audit/map.md](../../../../../.scratch/yucai-audit/map.md) 16 ticket 中已决策的 03-09。

## Release Goal

完成御财审计已决策 ticket 的实施,达到 [vision](../vision.md) 近期阶段标尺:**工程最佳实践 + 财务计算准确 + 备份可靠 + 基础安全**。

## Scope

### IN
| ticket | 状态 | 决策摘要 |
|---|---|---|
| **03** 事务一致性架构 | ✅ 已 done(2026-07-26,11 commits) | 共享 `*sql.DB` + TxContext;unblock 04 |
| **04** 备份恢复可靠性 | 待实施 | D5 快照 REPEATABLE READ / D6 restore 跨模块 tx + safety backup / D12 写冻结三件套 / D13 加密分层 |
| **05** DB 完整性约束 | 待实施 | ent edge FK + `field.Min(0)` + unique 4 项 + Immutable FK 列 |
| **06** 财务计算正确性 | 待实施 | portfolioCAGR 切 XIRR / XIRR 入口归一化 + Brent / TWR 零端值 sentinel + 真实样本 e2e |
| **08** 错误处理统一 | 待实施 | `shared/errors.ToGRPCStatus` 中央派发 + service DomainError |
| **09** DDD/port 边界 | 待实施(部分) | A1/A2/A5 已修;`.golangci.yml` depguard 锁边界(A4 intra-module defer) |

### OUT(留后续 release)
- **10-16 frontier**(wire 技债 / 部署 / 离线观测 / 数据 IO / 家庭多用户 / 提醒资产 / 多设备同步)— 未决,待 ticket 化决策。
- **功能对标模块** — vision 近期但不属审计整改线。
- **auth OIDC Task 13 联调** — blocked-on-user,独立。

## Sprint roster

> sprint 分组提案(可调)。03 已 done 作 prerequisite,不单列 sprint。

- [x] **sprint-1**:04 备份恢复(03 刚 unblock,首个实施)✅ done(2026-08-23,A/B/C/D 全 merged)
- [ ] **sprint-2**:05 DB 约束 + 06 财务计算(数据完整性 + 计算正确性)
- [ ] **sprint-3**:08 错误处理 + 09 DDD-port(架构 polish + depguard 落地)

## Done-criteria(release gate)

- 04/05/06/08/09 各 ticket 的 audit 决策项全部落地(见各 ticket `.scratch/yucai-audit/issues/`)。
- 各 feature 过 `sydusx-review` + `sydusx-test` gate(DoD:conventions + ai-harness invariants + acceptance + coverage)。
- `go test ./...` 全绿 + `flutter test` 基线不退化(≤ 3 fail/2 文件)。
- vision 近期标尺相关项达标(财务计算有 oracle 测试 / 备份恢复有跨模块 tx e2e / 跨租户 + port 边界有机械守卫)。

## status: in-progress(sprint-1 done[04];**sprint-2 ✅ done 2026-08-29**[05:E/F + 06:G/H——Brent-only XIRR+GIPS 三态 TWR+round+守卫+oracle+主指标 enum 进 wire];sprint-3[08/09]按 portfolio pivot 挂起待重开;04/05/06 落地,08/09 deferred)
