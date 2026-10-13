# Task Brief T5 — 账户详情迁移(操作最丰 + 归档降级)

## 位置与环境
- worktree(只在此工作):`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r19-f58`;client `<worktree>/yucai/client`
- 前置:T1/T2/T3 完成。以实际落码接口为准。
- 规格/设计:`<feature>/spec.md`(FR-2/3/4/5)+ design.md LLD 操作映射表。`<feature>` = docs/sydusx/products/yucai-client/release-r19-shell-navigation/sprint-1/f58-shell-nav-foundation

## 任务(`lib/account/presentation/pages/account_detail_page.dart`)
1. **AppBar 整条退役**(BackButton/标题「账户详情」/actions 全删)。
2. **body 改 Stack**:内容 + `Positioned(right: 28, bottom: 28, child: FloatingActionDock(...))`;滚动容器 bottom padding ≥ 242。
3. **操作映射(两态,FR-4 场景)**:
   - 活跃:primary=「记一笔」(`_recordTxn` 既有);secondary=[编辑(`_edit`)、转账(信用卡→「还款」/储值→「充值」/其余→「转账」,`_transfer` 既有,标签逻辑复用)、更多(AnchoredMenu:复制账户/关闭账户/删除——既有 _copy/_close/_confirmDelete 或同义方法)]。
   - **归档:仅「更多」可用**(复制账户/重新激活账户/删除;primary 在场禁用(onTap null 半透明降权,FR-4「每页必有主 FAB」不缺席)、编辑/转账隐藏,照旧 `!archived` 语义,spec「归档降级」场景;归档金圆禁用态视觉留用户走查)。
   - tablet(≤900)旧布局的 icon-only/TextButton 分支随 AppBar 一起退役——dock 本身就是响应式同构。
4. **标题注入**:账户加载完成 → ShellDetailTitle.set(账户名);dispose → clear()。
5. 顶部间距同 T4(hero 直升,8-16px 呼吸位)。
6. 测试(先红后绿):无 AppBar;活跃态 dock=primary+3 secondary,各 tap 行为;归档态=仅更多(菜单含 重新激活);标题注入/清理;既有旧 AppBar 断言测试更新。

## 约束
零功能丢失(复制/关闭/重新激活/删除/还款/充值/记一笔全可达);日志英文;注释中文。

## 完成证据
- 测试输出(0 failures)+ analyze 无新增 + 改动清单 + 偏离说明。
