# Portfolio Progress

> AI resume entry — current position only. No grouping/aggregation。
> Read this → current product → release → sprint → feature → stage。
> 2026-08-05 重构为多产品 roster(server/client 两产品),自原统一 progress 迁移。

## Product roster

| product | domain | vision | 当前 release | 说明 |
|---|---|---|---|---|
| [yucai-server](../products/yucai-server/) | software | [vision](../products/yucai-server/vision.md) | [R5 审计整改](../products/yucai-server/release-r5-audit/release.md)(🔄 active) | Go 后端;produces [yucai-api](contracts/yucai-api/README.md) |
| [yucai-client](../products/yucai-client/) | software | [vision](../products/yucai-client/vision.md) | [R7 windows-usable](../products/yucai-client/release-r7-windows-usable/release.md)(🔄 active) | Flutter 客户端;consumes yucai-api |

## Current position

**Status:** yucai-client **[R8 design-v2 立项 2026-08-30](../products/yucai-client/release-r8-design-v2/release.md)**(A+B 亮暗双主题设计系统:用户从 A墨鎏金/B晨白/C琥珀 三方向打样中裁定 A+B 合并;[design-v2.md](../products/yucai-client/design-v2.md) 为视觉事实源,原型 12 页 `design-output-v2/ab/`)。**F1 令牌+双主题地基 ✅ done**(merge `6c48ed8c`:YucaiTheme ThemeExtension + AppTheme.dark + ThemeSettings 持久化 + 设置页主题切换 + app_shell 主题感知)。**F2 页面缺陷修复 ✅ done**(merge `cd887194`:/debts 切页 Bad state 根治[单例被 provider close]+ v1 残留色清理 + **drift 基线清零:全量 1178 tests 历史首次全绿**)。**F3 设计一致性 pass ✅ done**(merge `5b6a8f11`:16 模块页 49 处 v1 一-off 色值→语义令牌,页面间色调统一;有意保留项与 F4 待办见 release.md)。**F4 暗色感知迁移 ✅ done**(merge `cf5f92ce`:1532 处静态色 → context.yucai/46 文件,双主题全应用生效;~306 回退点为 F4-P2 backlog)。R7 windows-usable 已收官(2026-08-29)。yucai-server R5 sprint-2 ✅ done(2026-08-29),server 线按 pivot 暂停(sprint-3 挂起)。

- Current product: **yucai-client**(R8 design-v2)
- Current release: [release-r8-design-v2](../products/yucai-client/release-r8-design-v2/release.md)(F1-F4 done,双主题全应用生效;next:F4-P2 回退点穿线/hero 重设计/占位文案清理待 ticket 化)
- Current sprint: R8 sprint-1(F1 ✅ + F2 ✅ + F3 ✅ + F4 ✅)done;F4-P2(辅助方法 context 穿线等 ~306 处)与后续 sprint 未规划。
- **2026-08-29 优先级 pivot(用户拍板方案 A)**:client 可用优先 → R7 四 feature 全落地收官后转入 R6 人工验收(待用户)与 R8 UI 线(已立项)。AI 语音助手=后续 feature 待 ticket 化。
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
