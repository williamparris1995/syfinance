# Task Brief T3 — 四 detail 迁移(budget/goal/transaction/holding)

## 位置与环境
- worktree(只在此):`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r19-f59`;client `<worktree>/yucai/client`
- 前置:T1 已落(C' API 以实际落码为准);范式参照 debt_detail_page(F58 版,回改前形态亦可比对)。
- 规格:`<feature>/spec.md` FR-4/FR-7 + design.md ADR-2 处置表/LLD 速查。`<feature>` = docs/sydusx/products/yucai-client/release-r19-shell-navigation/sprint-1/f59-shell-nav-sweep

## 任务(四页)
1. **budget_detail**:AppBar 退役;dock=编辑(primary)+muted=[删除];标题注入=预算名(DetailTitleSync);恒渲染禁用。
2. **goal_detail**:AppBar 退役;dock=完成(primary,checkCircle;已完成态禁用)+secondary=[编辑]+muted=[复制/删除];标题注入=目标名。
3. **transaction_detail**:page-head「返回」链接退役(FR-7;若 T5 已处理核实即可);页面头编辑金色主钮迁为 dock primary=编辑+muted=[删除·复制(按现状操作集)];标题注入=交易名。
4. **holding_detail**:AppBar 退役;**底部 sticky 操作条(_actionBar)退役**;dock=加仓(primary)+secondary=[减仓/清仓]+muted=[删除(若有)]——操作语义照操作条既有 handler 原样迁移,零丢失;标题注入=持仓名。
5. 各页:Stack 挂载(right/bottom 28)+滚动 bottom padding 按钮数算+顶部 8-16 呼吸位+loading/error 恒渲染全禁用。
6. 测试(先红后绿,每页):AppBar/返回链接/操作条零残留;dock 三段映射+tap 行为;禁用态(goal 已完成/holding 无仓?);标题注入;既有断言更新。

## 约束
零功能丢失(加仓/减仓/清仓/完成/复制等全直达);不碰 form/工具页/F58 三页(并行);日志英文;注释中文。

## 完成证据
测试输出(0 failures)+ analyze 无新增 + 改动清单 + 偏离说明。
