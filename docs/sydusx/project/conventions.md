# 御财 — Conventions

> **强制开发规则**。本文是**索引**,指向 single source —— 不复制内容(one source of truth 原则)。
> 项目规则 single source = [`CLAUDE.md`](../../../CLAUDE.md)(repo root)。本文仅补充 sydusx 工作流特有规则。

## 项目 mandatory 约束(single source → CLAUDE.md「关键约束」)

| # | 约束 | 摘要 |
|---|---|---|
| 1 | English 结构化日志 | slog / console.error,**无 CJK 在 log 串** |
| 2 | wire 工具链坏 | `wire_gen.go` 手改(镜像 provider 顺序),不跑 wire CLI |
| 3 | 复用第一 | 新模块照 holding/debt 范式;先查 `lib/`+`hooks/`+`components/` |
| 4 | DDD 边界 | domain→application→infra→presentation;跨模块走 port |
| 5 | proto regen | 改 proto 后 Go+Dart stub 都 regen(Dart **protoc_plugin 25.0.0**) |
| 6 | interface 加方法 | grep 全 implementer(含 test fake)→ 跑**全量 suite**(非 scoped) |
| 7 | 路由优先级 | 静态子路由(`/new` `/edit`)必须在 `/:id` 前 |

> 详见 [`CLAUDE.md` 关键约束](../../../CLAUDE.md)。**这些约束 OVERRIDE 默认行为,必须严格遵守。**

## 测试基线(不可破坏)

- **server**:`go test ./...` 全量绿 + `go build ./...`。
- **client**:`flutter test` 基线 = **3 fail / 2 文件**(account_detail_page_test 1 + receivable_detail_page_test 2,test drift,断言过时非生产 bug)。`flutter analyze` 基线 = 22 error 全 `*.pbserver.dart`(客户端未用)。
- 改动**不得**新增 fail / error。

## sydusx 通用原则(与项目约束的映射)

| sydusx 原则 | 御财落地 |
|---|---|
| interface-first | 见 CLAUDE.md #4 DDD 边界 + #6 interface grep |
| reuse(不重复造) | 见 CLAUDE.md #3 复用第一 |
| no duplicate code/data-structures | 同上 + one source(本文即体现:索引不复制) |
| no hardcoded strings | log 见 #1;client UI 中文直写是 ADR-006 既定取舍(非"硬编码"违例) |
| one source of truth | **文档 references,never copies**;本 conventions 不重复 CLAUDE.md 内容 |

## agent 工作流(single source → docs/agents/)

| 文档 | 用途 |
|---|---|
| [issue-tracker.md](../../../docs/agents/issue-tracker.md) | issue 以 markdown 存 `.scratch/<feature-slug>/` |
| [triage-labels.md](../../../docs/agents/triage-labels.md) | 五标签:needs-triage / needs-info / ready-for-agent / ready-for-human / wontfix |
| [domain.md](../../../docs/agents/domain.md) | 单上下文 CONTEXT.md + docs/adr/(_待建_) |

## sydusx 工作流规则(本工作流特有)

- **worktree 生命周期**:每个 feature 在 `feature/<id>` 分支的独立 worktree;feature docs 编辑于 worktree,shared docs(progress/release/project)在 merge 时更新到 main。Windows 上 prompt 清理 worktree。
- **grade(S/M/L)**:analysis 入口按 complexity × risk × uncertainty 的 max 评级,决定 analysis/design/review 深度;**code+test 永不跳过**。
- **Definition of Done**:满足 conventions + 持 ai-harness invariants + 过 review gate + 过 test gate(acceptance + coverage)。
- **快车道**:shared docs(conventions/architecture/ADR)走小 PR 直达 main,不捆长生命 feature 分支;worktree 定期 `rebase main`。
