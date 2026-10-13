# F59 code-ledger

> SDD 执行档案。注:T4/T5 实现与 T3+T2 修复轮两次被 5 小时使用限额击杀,残余(六表单实现+散项)由控制器直接接管完成;e2e 门在收口。

## 任务记录

| 任务 | 状态 | 实现 | 评审 | 修复轮 |
|---|---|---|---|---|
| T1 design_kit C' 升级(muted 组/分隔线/全圆/dimmedOpacity 缝) | ✅ | 21 测绿/analyze 0 | PASS(零必修;dimmedOpacity 0.55 接线+草稿清理转 T2) | — |
| T2 F58 三页回改 C' | ✅ | 152 页测+635 模块绿 | PASS-with-fixlist(I-1 e2e A3/M1M2N1 注释) | 并入 T3+T2 合并修复轮 |
| T3 四 detail 迁移 | ✅ | 74 页测+41 router 绿 | PASS-with-fixlist(I-1 txn!/M1M2 断言缺口/M4 注记) | 修复轮(被限额击杀,由控制器确认落地:txn! 零残留/error 态断言/full_audit A3) |
| T4 六表单接线 | ✅ | 红测试由前任写,实现被限额击杀;控制器接管补齐六页(2777 全量绿) | 待 holistic 评审补 | — |
| T5 工具页+面包屑覆盖 | ✅ | lib 四页+app_shell 覆盖/hideTopBar 退役由前任完成,测试收尾控制器 | 待 holistic 评审补 | — |
| T6 回归门 | 🔄 | 全量 2777 绿/analyze 461<463;e2e 在跑 | — | — |

## 关键裁决

- holding 操作集按代码真身迁移(买入/卖出/分红/拆分;无清仓/删除 handler,muted 空,不造无后端钮)——spec FR-4 措辞按 feature.md 处置注记订正。
- transaction「标记已对账/导出凭证」toast 占位桩随菜单退役(非实功能)。
- goal 底部 actionRow 保留(记一笔贡献无 dock 等价物;完成双入口冗余留用户走查项)。
- budget_form 编辑预填置 _prefilling 抑制窗;account_form 创建/编辑两路径分别接线(早退 return 前补);trade_sheet 恒「记录交易」注入串。
- 限额连续击杀后控制器接管 T4 残余(budget/receivable/goal/account/trade_sheet 五页实现,照 debt_form 前任参照模式)。

## holistic 评审 fixlist 处置(2026-10-13)

- F-1 已修:goal 关联账户/债务多选 toggle、account 币种/归属下拉共 4 处 _markDirty() 补齐 + 2 钉测(goal 30 绿/account 12 绿)。
- F-2 订正:spec Out of scope 加注记(account 表单无路由,面包屑经列表入口不显;守卫/注入已接线,路由票后补自动生效)。
- nit 留后续票:DirtyFormMixin 抽取候选(六表单 ~30 行胶水,rule-of-three 已过)/分隔线 20↔22 口径统一/secondary 内序钉死。

## 走查项(用户验收)

- goal 详情「标记完成」双入口(dock 金圆 + 底部 actionRow)冗余——留裁。
- 满配 6 钮(账户页)实机高度感受。
