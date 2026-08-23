# Portfolio Progress

> AI resume entry — current position only. No grouping/aggregation。
> Read this → current product → release → sprint → feature → stage。
> 2026-08-05 重构为多产品 roster(server/client 两产品),自原统一 progress 迁移。

## Product roster

| product | domain | vision | 当前 release | 说明 |
|---|---|---|---|---|
| [yucai-server](../products/yucai-server/) | software | [vision](../products/yucai-server/vision.md) | [R5 审计整改](../products/yucai-server/release-r5-audit/release.md)(🔄 active) | Go 后端;produces [yucai-api](contracts/yucai-api/README.md) |
| [yucai-client](../products/yucai-client/) | software | [vision](../products/yucai-client/vision.md) | [R6 offline-first 本地模式](../products/yucai-client/release-r6-offline/release.md)(🔄 active) | Flutter 客户端;consumes yucai-api |

## Current position

**Status:** yucai-server `release-r5-audit` sprint-1 — feature B(D6 restore atomic)**analysis done**(spec drafted)。

- Current product: **yucai-server**
- Current release: [release-r5-audit](../products/yucai-server/release-r5-audit/release.md)(R5 审计整改,scope 03-09,全 server-side)
- Current sprint: [sprint-1](../products/yucai-server/release-r5-audit/sprint-1/sprint.md)(04 备份恢复可靠性)
- Current feature: [2026-08-01-d6-restore-atomic](../products/yucai-server/release-r5-audit/sprint-1/2026-08-01-d6-restore-atomic/state.md)(feature B;current_stage: analysis / status: analysis-done)
- **Next**:feature B design(HLD/LLD:tx 包 purge+import 循环 + 各 repo DeleteByTenant/Save tx-aware 验证)或先 review spec。
- **并行线**:yucai-client [R6 offline-first](../products/yucai-client/release-r6-offline/release.md) sprint-1+2 done + sprint-3 G/H/I **done**(merged `bc0dbbd3`,2026-08-23;三判据自动化验收 4/4+人工清单待执行)。next:sprint-3 feature J(archive-export-import,存档导出导入——最后一个,R6 收官件)。

## Legacy milestones(pre-split,pre-sydusx,统一御财)

> 2026-08-05 拆分前的耦合里程碑(server+client 共同)。非 canonical release,仅追溯。

- **R1 架构重建** ✅ — Tauri+Rust+React → Go+Flutter 重写([ADR-001](adr/index.md#adr-001),2026-06-09)。
- **R2 holding 系统** ✅ — 资产管理 + 收益引擎(XIRR/TWR/Yahoo)+ 双写 + tag/template。
- **R3 备份/预算/目标/dashboard** ✅ — 本地备份 + budget + goal + dashboard。
- **R4 auth OIDC** ✅ — 自建密码→OIDC(Google,server+client;Task 13 联调 blocked-on-user)。

拆分后:server 继续 R5;client 无 active release,下一 release 待规划。

## baselines(repo-global,2026-08-01 建立 / 2026-08-05 迁 portfolio/)

`docs/sydusx/portfolio/` 下:
- [conventions](conventions.md) · [infrastructure](infrastructure.md) · [ci-cd](ci-cd.md) · [ai-harness](ai-harness.md) · [adr cross-cutting](adr/index.md)
- 产品层:yucai-server / yucai-client 各 [architecture](../products/yucai-server/architecture.md) + [tech-stack](../products/yucai-server/tech-stack.md) + [adr](../products/yucai-server/adr/index.md)。
- 契约:[contracts/yucai-api](contracts/yucai-api/README.md)(server produces / client consumes)。

**harness enforcement wall**(scaffold + e2e 验证 exit 0,2026-08-01):
- [.claude/hooks/verify-commit.ps1](../../../.claude/hooks/verify-commit.ps1) — PreToolUse(git commit)跑 `go test ./...`(全绿 block)+ `flutter test`(基线容忍:account_detail_page_test / receivable_detail_page_test drift 放行)。注册于 `.claude/settings.json`。
- **已 e2e 验证**:go test 全绿 + flutter 仅剩 baseline 2 文件 drift(容忍)→ exit 0。

## 备注

- 本地 main 与 origin 已同步(2026-08-01 push `ec7dcb2` 后;此前 memory 说"346+ 未 push"已过时)。
- 基线:go test 全绿 + flutter 3 fail/2 文件 drift(CLAUDE.md 记录值,2026-08-01 验证)。
- pre-commit 测试 gate hook 已生效 + 实测通过。

## 历史背景

- 现有 SDD 产物:`docs/superpowers/`(233 specs+plans,2026-05~07-26)。
- 御财审计:`.scratch/yucai-audit/`(16 ticket,9 已决策;01/02/07 已实施,03 事务架构 2026-07-26 落地 11 commits)。
