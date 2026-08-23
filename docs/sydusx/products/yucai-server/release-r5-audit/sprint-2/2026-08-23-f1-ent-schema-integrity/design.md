---
feature: 2026-08-23-f1-ent-schema-integrity
status: confirmed
---

# Design — ent schema 完整性

> 消费 [spec.md](spec.md)(confirmed;两决策点均裁定推荐项)。设计极简:清单式落点+首例注解写法+codegen 流程。

## Decisions(ADRs)

### ADR-1 edge 写法(首例 OnDelete)
- 父:`edge.To("items", BudgetItem.Type).Annotations(entsql.OnDelete(entsql.Cascade))`;子:`edge.From("budget").Ref("items").Field("budget_id").Required().Unique()`(O2M)。8 对同款。snapshot/price_history/record_log 的 Unique 按实际基数(均 1:N → 父侧 To,子侧 From+Field+Required,不 Unique——多子)。
- Edges() 方法从 `return nil` 改实 edges;生成物 migrate schema 会落 FK+OnDelete:Cascade。
- 冲突注意:既有 repo 的 DeleteByTenant/DeleteXxx 手删子行逻辑保留(Cascade 是 DB 兜底,双删无害)。

### ADR-2 partial unique 写法(首例 Where)
- `index.Fields("tenant_id","month").Unique().Annotations(&entsql.IndexAnnotation{Where: "deleted_at IS NULL"})`;User.email 同款 `Where: "email <> ''"`。
- SQLite 兼容:SQLite **支持** partial index(3.8+ WHERE 语法)——测试库可行;若 codegen/migrate 出问题,测试 fallback PG-only skip 记 ledger。

### ADR-3 存量清理脚本
- `scripts/clean-before-r5-e.sql`(纯 SQL,幂等):删 email<>'' 重复(保留最新 id)、旧 filename 重复(保最新)、复合键重复(budget_item 保首、schedule 保首)、孤儿子行删(edge FK 加之前必须清——否则 ADD CONSTRAINT 失败)。附 README 一段:升级步骤=停服→跑脚本→启动(auto-migrate 生效)。

### ADR-4 codegen 流程
- 逐模块 `go generate ./internal/<m>/ent/...`(12 模块);diff 检查生成物 migrate schema 含新 FK/索引;`go build ./...` + 全测试回归。
- Immutable 加列后:跑全测试暴露改写 FK 列的路径(如有失败逐个复议该列——spec FR-5 已授权)。

## 测试计划
- schema 单测(每模块选代表):负金额 builder 拒 / 复合 unique 重复拒(DB 级)/ partial unique 行为(sqlite:软删行不占额度,同月重建成功)/ Cascade 硬删父行级联
- 全套 61 包回归(Immutable 改写路径暴露)

## Risks
- R1 首例注解与 ent v0.14.4 兼容——doc 核对;不兼容则注解换 struct tag 形态
- R2 生成物冲突(既有索引名)——security_price_history 前车之鉴;复合 unique 替换前缀冗余单列索引,避免重复
- R3 测试库 sqlite 对 partial/FK 行为差异——Cascade 在 sqlite=foreign_pragma 开(testDB 已开 D6 时 _pragma)
