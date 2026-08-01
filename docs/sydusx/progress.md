# Progress

> AI resume entry — current position only. No grouping/aggregation.
> Read this → current feature path → `<feature>/state.md` → stage.

## Current position

**Status:** `release-r5-audit` — Release 1(R5 御财审计整改)已分解,sprint planning 进行中。

- Current release: [release-r5-audit](release-r5-audit/release.md)(R5 审计整改,scope 03-09)
- Current sprint: _(sprint-1 规划中:04 备份恢复)_
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

## 备注

- 本地 main 与 origin 已同步(2026-08-01 push `ec7dcb2` 后;此前 memory 说"346+ 未 push"已过时)。
- 基线确认:go test 全绿 + flutter 3 fail/2 文件 drift(CLAUDE.md 记录值,2026-08-01 验证)。
- pre-commit 测试 gate hook 已生效 + 实测通过(真实 Claude Code 环境)。

## 历史背景

- 现有 SDD 产物:`docs/superpowers/`(233 specs+plans,2026-05~07-26)。
- 御财审计:`.scratch/yucai-audit/`(16 ticket,9 已决策;01/02/07 已实施,03 事务架构 2026-07-26 落地 11 commits)。
- 已完成里程碑:R1 架构重建 / R2 holding 系统 / R3 备份预算目标dashboard / R4 auth OIDC(联调 blocked-on-user)。
