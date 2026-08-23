---
feature: 2026-08-23-f1-ent-schema-integrity
current_stage: finish
status: done
---

# State — F1(ent) ent schema 完整性

## stages
- analysis: done(2026-08-23;output: spec.md;5 FR 确认)
- design: done(2026-08-23;output: design.md;4 ADR:edge 写法 / partial unique 注解 / 存量清理脚本 / codegen 流程)
- execute: done(2026-08-23;worktree r5-ent-integrity,branch feature/r5-ent-schema-integrity;8 commits:T1 edges 15 文件→T1b regen 109 文件+debt schedule edge→T2 Min(0) 18 字段→T3 UNIQUE+partial+regen 39 文件→T4/T4b Immutable 修正+测试种子→T5 UpdateTransaction TransactionID stamp+清理 SQL+schema 测试→T6 review fixes)
- review: done(2026-08-23;agent PASS-with-nits;1 MAJOR+3 MINOR+3 NIT 全部修复:users dedup identity 重分配+碰撞丢弃(冒烟测试钉死)/ 复合键 keep-policy 偏向已付与多数据 / email partial unique 测试 / 注释+ON_ERROR_STOP)
- test: done(2026-08-23;62 包全绿[新增 budget repo 测试包];build+vet 干净;7+1 schema 测试:Min(0) 拒/entry FK/复合 unique×2/partial unique×2/cascade×2/清理脚本冒烟)
- finish: done(2026-08-23;merge → main)

## notes
- 9 处 Immutable 合法回退:6 edge 持有 FK 列(ent 不允许)/ payment_schedule.transaction_id+template_record_log.transaction_id 补写路径 / transaction_template.destination_account_id 更新重写。
- 挖出存量 bug:UpdateTransaction 重建 entries 未 stamp TransactionID(uuid.Nil 落库,重载丢 entries)——FK 上线即暴露,已修+回归钉死。
- 升级步骤:停服→`scripts/clean-before-r5-e.sql`(幂等)→启动 auto-migrate;README 记录。
- WithDropIndex 默认 false:旧 budgetitem_budget_id/paymentschedule_debt_id 前缀冗余索引滞留 PG,无害(accepted)。
