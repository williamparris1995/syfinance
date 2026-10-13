# Task Brief T3 — app_shell 顶栏改造 + 主题注入 + 特例收敛

## 位置与环境
- worktree(只在此工作):`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r19-f58`
- client:`<worktree>/yucai/client`
- 前置:T1(design_kit FloatingActionDock/DesignTokens 新字段)与 T2(ShellDetailTitle/FormLeaveGate)已完成——先读它们的实现(接口以实际落码为准)。
- 规格/设计:`<feature>/spec.md`(FR-1/2/6)+ `design.md`(ADR-1/3/4,LLD)。`<feature>` = docs/sydusx/products/yucai-client/release-r19-shell-navigation/sprint-1/f58-shell-nav-foundation

## 任务
1. **`lib/core/theme/app_theme.dart`**:DesignTokens 构造点注入新字段(双主题同源推导,勿抄套件演示的绿):`accentGradient: [t.accent, t.accentDeep]`;`actionShadow: [BoxShadow(color: t.accent.withOpacity(0.35), blurRadius: 22, offset: const Offset(0, 8))]`(对应套件 --fab-bg 渐变/--fab-shadow 语义,两主题各自 accent 令牌自洽)。
2. **`lib/app/widgets/app_shell.dart`**:
   - `_BreadCrumb` 三段化:section 纯文本(muted);page 段 InkWell + `t.link`(或主题 link 色;无则 accent)色 + hover 下划线,onTap = `await formLeaveGate.mayLeave()` 通过后 `context.go(meta.rootPath)`;current 段加粗不可点。
   - current 段数据:监听 ShellDetailTitle(getIt);**location 任何变化先 clear**(安全网);detail 形态路由(location 匹配 `/debts/{id}`、`/receivables/{id}`、`/accounts/{id}`,排除 new/edit/数字外的段)且值 null 时显占位「…」;非 detail 形态不显第三段。
   - `_isReceivableDetail` 特例移除(hideTopBar 仅剩 `_isCategoryManagement`);债权详情回归全局 _TopBar。
   - compact 顶栏同样生效(面包屑本就显示,无断点特判)。
3. 测试(先红后绿):三段/两段/单级渲染;page 段 tap → go 列表 root(mock/go_router 测试先例找仓内既有 shell 测试);FormLeaveGate 注册 veto=false 时 tap 不导航;location 变化后标题清零;`_isReceivableDetail` 移除后债权 detail location 下 _TopBar 存在。

## 约束
- 日志英文;注释中文照密度;不动 proto;不顺手改无关代码。
- 若既有测试断言旧两段面包屑/hideTopBar 行为,同步更新并说明。

## 完成证据
- 相关测试 `flutter test` 输出(0 failures)+ `flutter analyze` 无新增 + 改动清单 + 偏离说明。
