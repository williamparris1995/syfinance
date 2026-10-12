# Task Brief T2 — core 两 port:ShellDetailTitle + FormLeaveGate/FormLeaveGuard

## 位置与环境
- worktree(所有工作只在此):`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r19-f58`
- client:`<worktree>/yucai/client`(flutter_bloc + getIt injectable;core 层照既有组织,先看 `lib/core/` 结构再落位)
- 测试:`cd <worktree>/yucai/client && flutter test test/<相关文件>`
- 规格/设计(先读):`<worktree>/docs/sydusx/products/yucai-client/release-r19-shell-navigation/sprint-1/f58-shell-nav-foundation/{spec,design}.md`(ADR-1/ADR-3)

## 任务
1. **`ShellDetailTitle` port**(ADR-1):包装 `ValueNotifier<String?>` 的小 port 类(set/clear/dispose 语义;监听走 notifier)。getIt **lazySingleton** 注册(照 DataRefreshNotifier 注册先例,找 `injection.dart` 或 getIt 注册文件同款位置)。不绑路由实现、不 import 任何模块 bloc。
2. **`FormLeaveGate` port**(ADR-3):
   - `typedef LeaveVeto = Future<bool> Function();`
   - gate:`register(LeaveVeto)`/`unregister(LeaveVeto)`;`Future<bool> mayLeave()` = 逐个问询已注册 veto(任一 false 即 false,全 true/无注册 → true)。
   - getIt lazySingleton 注册。
3. **`FormLeaveGuard` widget**(`lib/core/widgets/` 照既有归位):
   - StatefulWidget,参数:`isDirty: bool Function()`(或 ValueListenable<bool>,选简)+ `child`。
   - 注册 veto:dirty 时返回「弹确认对话框 → 用户选放弃=true/留下=false」的 Future;非 dirty 直接 true。
   - `PopScope` 兜底:拦截 pop(CanPop 动态=非 dirty 或经确认),同样走确认对话框。
   - dispose 必须 unregister(防泄漏——spec FR-2/FR-7 的残留类风险)。
   - 对话框文案中文(「未保存的修改」「放弃修改/继续编辑」),照仓内既有 dialog 风格(找 AlertDialog 先例);**日志(如有)英文结构化,禁 CJK 进 log 串**。
4. 注释中文照仓内密度;不写实现之外的改动。

## TDD(硬性)
先红后绿,`test/` 下至少:
- ShellDetailTitle:set→值变更通知;clear→null;双监听不串。
- FormLeaveGate:无注册 mayLeave=true;单 veto false→false;多 veto 短路;unregister 后不再问询。
- FormLeaveGuard widget 测:非 dirty pop 直放;dirty pop 弹框,选「放弃」放行、选「继续编辑」留在页;dispose 后 gate 无残留注册。
- 注意坑:get_it 测试 reset 是 async(flutter widget 测试六坑之一);对话框断言勿提前 dispose 页面。

## 完成证据(报告必须含)
- 相关测试文件 `flutter test` 输出(0 failures)
- `flutter analyze` 无新增(基线为准)
- 改动文件清单
