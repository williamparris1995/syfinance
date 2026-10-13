# Task Brief T4 — 表单页接线(六表单:三级面包屑 + 守卫 + AppBar 退役 + 无簇)

## 位置与环境
- worktree(只在此):`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r19-f59`;client `<worktree>/yucai/client`
- 前置(F58 已落,先读实际接口):`lib/core/shell_detail_title.dart`、`lib/core/widgets/detail_title_sync.dart`(TickerMode 守卫)、`lib/core/widgets/form_leave_guard.dart`(isDirty bool Function())、app_shell `_isDetailShapedLocation`(面包屑第三段显示条件——表单路由 `/debts/new`、`/debts/:id/edit` 目前被排除,**需先在 app_shell 扩表单形态判定**:T5 负责 location 覆盖,但表单形态判定(new/edit 路由)属本任务消费面——**若发现 shell 侧需增「表单形态」识别(占位/注入消费),在本任务内一并改 app_shell 并在报告注明**,与 T5 协调风险:T5 也改 app_shell(location 覆盖),改动区块不同(breadcrumb 判定 vs _branchMetaOf 覆盖),git 文本级冲突低,但请只动必要行)。
- 规格:`<feature>/spec.md` FR-5 + design.md ADR-3/LLD。`<feature>` = docs/sydusx/products/yucai-client/release-r19-shell-navigation/sprint-1/f59-shell-nav-sweep

## 任务(六页:debt_form/receivable_form/account_form/budget_form/goal_form + trade_sheet_page)
1. **自带 AppBar 导航退役**:BackButton/返回条删除(表单底部已有 取消/保存 或等价提交钮;若无取消钮的表单不加——守卫+面包屑承担离开)。
2. **三级面包屑注入**(DetailTitleSync):新增态=`「新增{名词}」`(照各表单 mobile AppBar 标题既有串,如「新建债务」按仓内实际文案);编辑态=实体加载完成后 `「编辑 · {实体名}」`,加载中 `「编辑{名词}」`;dispose clear 保留语义(组件内建)。
3. **FormLeaveGuard 接线**:包表单 body;`isDirty` = 首改即脏粗粒度(任一字段 onChanged 首次触发置位;提交成功/重置后复净由页面置回 false;各表单已有字段变更追踪则复用)。
4. **无悬浮簇**;页面顶部间距照 F58(hero 直升,8-16px 呼吸位)。
5. trade_sheet 注意:提交流程既有 pop 不受守卫影响(净态直放);仅拦脏态离开。
6. 测试(先红后绿,每页至少):脏态下面包屑/返回离开弹确认、净态直走;注入串两态;AppBar 零残留;既有 AppBar 断言更新。

## 约束
零功能丢失;日志英文;注释中文;不碰 detail 页/工具页/design_kit(他任务并行)。

## 完成证据
测试输出(0 failures)+ analyze 无新增 + 改动清单 + 偏离说明(含 app_shell 表单形态判定改动若有)。
