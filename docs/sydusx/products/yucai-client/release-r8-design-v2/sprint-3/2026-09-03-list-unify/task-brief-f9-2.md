# Task Brief F9-T2 — 账户详情内嵌交易标准套件

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f9`,客户端 `yucai/client/`。**TDD。** T1(1f126506)已就绪:共享 `PagerBar`(core/widgets/pager_bar.dart)与 `PageCursorStack`(core/widgets/page_cursor_stack.dart)。

## 先读(必读)

1. `docs/.../2026-09-03-list-unify/spec.md` 的 FR-2 + NFR-1/2;design.md ADR-4
2. `yucai/client/lib/account/presentation/pages/account_detail_page.dart`(**近期交易区现状**:约 :55 注释「近期交易客户端分页(Task 6)。pageSize=5;当前页 0-based」——找到该分页实现与数据获取方式;full_audit A3 对本页的断言:更多操作菜单打开,**不动它**)
3. `yucai/client/integration_test/full_audit_test.dart` A3(account_detail 相关断言)
4. `yucai/client/lib/transaction/` F7 套件(查询管道已支持 accountId 作用域+search/sort/分页;`lib/core/widgets/pager_bar.dart`)

## 交付物

账户详情页「近期交易」区升级为标准查询套件:

1. **数据**:经 `TransactionRepository.list`(accountId 作用域)复用 F7 管道——搜索(searchText)/排序(四态)/分页(pageSize 100,PagerBar)。原 Task 6 的 5 条/页客户端迷你分页逻辑删除(注释标注 F9 替换)。
2. **状态**:账户详情页现有 bloc 结构(读文件确认是页面级 Stateful 还是独立 bloc)——加轻量分页/搜索/排序状态,**复用 PageCursorStack**;任一筛选变化重置第 1 页(照 F7 语义)。
3. **UI**:交易区头部加搜索框+排序控件(轻量版,可复用 F7 的 TxnSearchField/TxnSortControl——若它们可提升为共享件则提升,落点 core/widgets,注释来源;否则页面内组合);底部挂共享 `PagerBar`(单页隐藏,照 F7 `_showPager` 语义)。
4. **首屏语义不变**(NFR-2):默认打开=该账户近期交易(日期降序第 1 页);A3 的 full_audit 断言不红(e2e 由 T4 验证,你只需保证 widget 层测试通过)。

### TDD 测试

- 账户详情近期交易区的 widget/状态测试(照 account_detail 既有测试模式,test/account/presentation/pages/ 找基线):默认首屏=近期交易降序;搜索过滤;排序切换;翻页 token 前进/回退;单页隐藏分页条。
- 若 F7 widget(TxnSearchField/TxnSortControl)提升共享:其测试随迁保绿。

## 验证(全部执行并贴证据)

1. 新增/迁移单测绿(先红后绿)
2. `flutter test` 全量不回归(≥1230)
3. `flutter analyze` 新文件 0 条;full_audit 不在本任务跑(e2e T4)

## 约束

NFR-1:A3 断言与「更多操作菜单」功能零改动;中文注释;不动 transaction DS/domain;不 commit。完成后报告。
