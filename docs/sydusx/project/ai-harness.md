# 御财 — AI Anti-Drift Harness

> 短契约/地图(~100 行),非手册。invariants + 如何 enforce + 配置在哪。深度留在 canonical files。
> 由 `/sydusx-harness` ESTABLISH(2026-08-01)。config 值**指向不复制**(single source)。

## §1 Invariants

御财 drift-critical 规则,elicit 自 [conventions.md](conventions.md) + [architecture.md](architecture.md) + [`CLAUDE.md`](../../../CLAUDE.md)。仅列 drift-critical(非 cosmetic):

1. **slog 无 CJK** — log 串禁中文(英文结构化 slog)。
2. **wire_gen.go 手改** — 不跑 wire CLI(工具链坏)。
3. **proto regen 双端** — Go+Dart stub 都 regen;Dart **protoc_plugin 25.0.0**。
4. **interface 加方法 → 全量 suite** — grep 全 implementer(含 test fake),跑全量非 scoped。
5. **money int64 cents 零浮点** — 全栈禁 float/double 于金额。
6. **DDD 跨模块 port 不 import** — 消费模块不直接 import 生产模块。
7. **tenant_id 隔离** — repo 强制 `WHERE tenant_id`(防 IDOR)。
8. **client 中文直写** — 不引 i18next(阶段二 ADR-006 才改)。
9. **测试基线不破坏** — client 3 fail/2 文件是 drift 非 bug,不新增 fail。

## §2 Enforcement map

| # | invariant | classification | enforcement + location |
|---|---|---|---|
| — | **测试 gate**(`go test ./...` 全绿 + flutter 基线容忍) | **enforced** ✅ | pre-commit hook [`verify-commit.ps1`](../../../.claude/hooks/verify-commit.ps1)(git commit 触发,2026-08-01 scaffold) |
| 6 | 跨模块 port 不 import | **enforced** ⏳ | Go `.golangci.yml` depguard(**audit 09 已计划**,待落地) |
| 7 | tenant_id 隔离 | **enforced** ⏳ | CI 跨租户拒绝矩阵(**audit 01 已计划**,待 CI 建后落地) |
| 1 | slog 无 CJK | advisory | 测试 gate 不守护 log 语言;靠纪律。反复 drift → promote grep wall(§5) |
| 5 | money 零浮点 | advisory | 测试 gate 间接守护(有测试覆盖处);纪律 + 未来 grep |
| 2 | wire 手改 | advisory | [CLAUDE.md #2](../../../CLAUDE.md);机器难挡(检测"跑了 CLI"不可行) |
| 3 | proto regen 双端 | advisory | [CLAUDE.md #5](../../../CLAUDE.md);diff 时间戳检测 ROI 低 |
| 4 | interface 全量 suite | advisory | [CLAUDE.md #6](../../../CLAUDE.md);测试 gate 已挡回归,全量纪律仍需 |
| 8 | 中文直写 | advisory | [ADR-006](adr/index.md#adr-006);阶段二要改 i18n,现在 enforce 会绊脚 |
| 9 | 测试基线 | advisory | [conventions.md](conventions.md);hook 已做基线容忍(2 文件 drift 放行) |

> ✅ = wall 已落地并触发;⏳ = enforced 已规划,wall 未落地(以 advisory 纪律执行至 audit 09/01 落地)。

## §3 Verification gate

agent 任何"done"声明前(syDusx-verify)必须过:
- **server**:`go test ./...` 全量绿 + `go build ./...`
- **client**:`flutter test` ≤ 基线(3 fail/2 文件,不新增)+ `flutter analyze` ≤ 22(.pbserver)
- **proto 改**:Go+Dart stub 都 regen 后 build 绿
- **enforced 项**(§2 ⏳ 落地后):pre-commit / CI 门

> 零证据不 claim done —— "verify before claiming done, show fresh output"。

## §4 Pointers(config canonical 位置)

| 什么 | 在哪 |
|---|---|
| 项目规则(7 条关键约束) | [`CLAUDE.md`](../../../CLAUDE.md)(single source) |
| conventions 索引 | [conventions.md](conventions.md) |
| 架构 + ADR | [architecture.md](architecture.md) + [adr/index.md](adr/index.md) |
| 栈 | [tech-stack.md](tech-stack.md) |
| CI 现状 + 命令 | [ci-cd.md](ci-cd.md) |
| proto 工具 | `yucai/server/buf.gen.go.yaml`(Go)+ `yucai/Makefile` gen-dart(Dart) |
| agent 工作流 | [`docs/agents/`](../../../docs/agents/) |
| hook(待建) | `.git/hooks/pre-commit` 或 `.claude/settings.json` |

## §5 Advisory → enforced upgrade

当 agent 在某 advisory 规则上**反复 drift** → promote 进代码(linter/hook)→ §2 行 advisory→enforced + 记录。
- 触发示例:若 AI 多次跑 wire CLI / 多次跑 scoped test 漏 fake → 沉淀为 hook/检查。
- audit 09 depguard 与 audit 01 tenant 矩阵即为 audit-driven promote(已规划)。

## §6 Drift GC

省略(单开发者私域,非持续 agent 作业)。需要时 `/sydusx-harness GC`。

## §7 Agent legibility

省略(本地优先 + DevTools/observability 已在 audit 12「离线观测」与 multi-session worktree 标识覆盖)。
