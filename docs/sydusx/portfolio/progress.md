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

**Status:** yucai-server `release-r5-audit` — **sprint-1 done**(2026-08-23,A/B/C/D 四 feature 全 merged——04 备份恢复可靠性收官:快照隔离+原子 restore+写冻结+加密分层[D19a v2 KDF header,v1 永久兼容])。

- Current product: **yucai-server**
- Current release: [release-r5-audit](../products/yucai-server/release-r5-audit/release.md)(R5 审计整改,scope 03-09,全 server-side)
- Current sprint: sprint-2 🔄 in-progress(feature E ent schema 完整性 + feature F delete-account-guard ✅ done 2026-08-23——E:8 edge FK+Cascade/18 Min(0)/UNIQUE+partial/清理脚本;F:六源引用拒绝 port+fail-closed;next:feature G xirr-twr-correctness)。
- **并行线**:yucai-client **[R6 offline-first](../products/yucai-client/release-r6-offline/release.md) 整体 done**(2026-08-23,十二 feature A-J 全 merged;人工清单真机执行待用户归档;defer 清单见 release.md——含 J codec 补 YC2E 解码[R5 D 的 contract drift]与 ticket 16 线)。

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
