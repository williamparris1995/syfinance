# Task Brief T4 — 债务+债权详情迁移(AppBar 退役 + 悬浮簇)

## 位置与环境
- worktree(只在此工作):`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r19-f58`;client `<worktree>/yucai/client`
- 前置:T1/T2/T3 完成(FloatingActionDock / ShellDetailTitle 可用;顶栏已显三段面包屑)。以实际落码接口为准。
- 规格/设计:`<feature>/spec.md`(FR-2/3/4/5)+ design.md LLD 操作映射表。`<feature>` = docs/sydusx/products/yucai-client/release-r19-shell-navigation/sprint-1/f58-shell-nav-foundation

## 任务(两页同构,debt_detail_page.dart + receivable_detail_page.dart)
1. **AppBar 整条退役**(title 面包屑/actions/BackButton 全删;`_sem.detailTopCrumb` 相关退役)。
2. **body 改 Stack**:内容(既有滚动视图)+ `Positioned(right: 28, bottom: 28, child: FloatingActionDock(...))`;滚动容器 bottom padding ≥ 242(防遮挡,spec FR-3)。
3. **操作映射**(经 `_sem` 语义双态复用):
   - primary:债务=「立即记账」/债权=「收款」——打开既有下期 RecordPayment/确认收款 dialog(复用页内既有逻辑;若页内入口在侧栏/行内,抽出可复用方法,dock 与页内入口共存,行为一致)。
   - secondary:[编辑(push edit 路由)] + [更多(AnchoredMenu:删除=既有 _confirmDelete;destructive 红色)]。
4. **标题注入**:bloc 加载完成 → ShellDetailTitle.set(counterparty);dispose → clear()。加载失败不 set(顶栏占位「…」由 T3 逻辑兜)。
5. 页面顶部间距:hero 直升页顶(AppBar 的 64px 让位;若视觉过挤,顶部 8-16px 呼吸位即可,勿超 24)。
6. 测试(先红后绿):页面上无 AppBar/findAppBar 不存在;dock 存在且 primary/secondary 数量与映射一致;tap 编辑 → 路由 push;tap 更多 → 菜单开;标题注入/清理;既有引用旧 AppBar 的测试更新。

## 约束
- 零功能丢失(删除/编辑/记账全可达); AnchoredMenu 跨 Navigator 边界既有先例照用;日志英文;注释中文。

## 完成证据
- 测试输出(0 failures)+ analyze 无新增 + 改动清单 + 偏离说明。
