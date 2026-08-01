# Progress

> AI resume entry — current position only. No grouping/aggregation.
> Read this → current feature path → `<feature>/state.md` → stage.

## Current position

**Status:** `baselines-established` — sydusx 项目基线已建立,首个 release 分解**待定**(用户 2026-08-01 选择先处理本地积压/基线确认,release 推迟)。

- Current release: _(none yet — 用户选择推迟分解)_
- Current sprint: —
- Current feature: —

## baselines(已建立,2026-08-01)

`docs/sydusx/project/` 下:
- [vision.md](project/vision.md) — 个人专业理财(终态商业级),分阶段(近期功能对标保豁免 / 阶段二 i18n+合规+安全审计)
- [architecture.md](project/architecture.md) — DDD 四层 + Hexagonal port + CQRS;记录 Tauri→Go+Flutter 重写 + 实施偏差
- [tech-stack.md](project/tech-stack.md) — server(Go)/ client(Flutter)分 context
- [conventions.md](project/conventions.md) — 索引 CLAUDE.md 7 条关键约束 + 测试基线
- [ci-cd.md](project/ci-cd.md) — 无 CI 现状 + 命令 + 待建 wall
- [ai-harness.md](project/ai-harness.md) — 9 invariants;测试 gate enforced ✅ + depguard/tenant ⏳ + 5 advisory
- [adr/index.md](project/adr/index.md) — ADR-001..007

**harness enforcement wall(已 scaffold + e2e 验证 exit 0,2026-08-01)**:
- [.claude/hooks/verify-commit.ps1](../../.claude/hooks/verify-commit.ps1) — PreToolUse(git commit)跑 `go test ./...`(全绿 block)+ `flutter test`(基线容忍:account_detail_page_test / receivable_detail_page_test drift 放行,新 fail block)。注册于 `.claude/settings.json`(保留 graphify hook)。
- **已 e2e 验证**:go test 全绿 + flutter 仅剩 baseline 2 文件 drift(容忍)→ exit 0。修了 2 个 2026-08-01 日历 drift(debt_detail StatRow `findsWidgets` + report_page `find.descendant`)→ 基线干净回 3 fail/2 文件(CLAUDE.md 记录值)。

## 下一步(用户选择)

用户 2026-08-01 选「先不定 release」,优先:
1. 处理本地 main 积压(holding 346+ commit / auth OIDC / 审计 03 等**未 push origin**)。
2. 基线确认(go test 全绿 / flutter test 3 fail drift)。
3. release 分解留后(候选:R5 审计 04 备份恢复,03 刚 unblock)。

## 历史背景

- 现有 SDD 产物:`docs/superpowers/`(233 specs+plans,2026-05~07-26)。
- 御财审计:`.scratch/yucai-audit/`(16 ticket,9 已决策;01/02/07 已实施,03 事务架构 2026-07-26 落地 11 commits)。
- 已完成里程碑:R1 架构重建 / R2 holding 系统 / R3 备份预算目标dashboard / R4 auth OIDC(联调 blocked-on-user)。
