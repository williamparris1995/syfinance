# Task Brief F9-T3 — 持仓/债务债权/账户三模块查询能力

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f9`,客户端 `yucai/client/`。**TDD。** 共享件已就绪:`core/widgets/pager_bar.dart`(PagerBar)+ `page_cursor_stack.dart`(PageCursorStack)。

## 先读(必读)

1. `docs/.../2026-09-03-list-unify/spec.md` 的 FR-3/4/5 + NFR-2/3;design.md ADR-3 + LLD 要点
2. `lib/holding/presentation/pages/holdings_page.dart`(全量 ListView)+ `security_page.dart`(标的列表形态确认)
3. `lib/debt/presentation/pages/debts_page.dart` + `receivables_page.dart` + 对应 bloc/debt 数据获取路径(list 或 watch)
4. `lib/account/presentation/pages/accounts_page.dart`(全量卡片列表)
5. 各模块本地 DS:`holding/data/holding_local_ds.dart`、`debt/data/debt_local_ds.dart`、`account/data/account_local_ds.dart` 的 list 方法形态
6. F7 范式:`transaction_local_ds.list()` 的 in-memory 过滤/排序/分页管道 + `transaction_bloc` 的状态机

## 交付物(按矩阵:持仓=分页+搜索;债务债权=搜索+排序无分页;账户=搜索)

### 1. 持仓列表(holdings_page)

- DS:`HoldingLocalDataSource` 增可选查询参数 `searchText`(匹配标的 symbol/name contains 忽略大小写)+ `pageSize`/`pageToken`(offset,照 F7 语义含 nextToken 返回)——**in-memory,默认路径零变化**。若现有 list 返回形态不便带 token,可加 `listPaged()` 新方法保留旧 list 不动(选一,注释理由)。
- UI:列表头部搜索框(可复用/仿 TxnSearchField 提交制——注意它依赖 transaction domain;这里要么在本页写轻量提交制 TextField,要么把一个**无 domain 依赖**的通用搜索框提到 core/widgets 供各页复用——选后者更好,命名如 `SearchField`,注释来源)+ 底部 `PagerBar`(PageCursorStack 状态;页面 Stateful 管理即可,不必 bloc 化——按页面现有结构定,注释理由)。
- 标的页(security_page):若为列表形态,至少加 `SearchField`(symbol/name)。

### 2. 债务/债权列表(debts_page/receivables_page)

- DS:`DebtLocalDataSource` 增 `searchText`(counterparty contains)+ `sortKey`(amount/dueDate)+ `sortDir`,in-memory,默认零变化。
- UI:头部 `SearchField` + 排序控件(轻量 PopupMenu,键=金额/到期日,方向升降;无分页条)。两页共用实现(债务/债权列表结构相似——抽共享 widget 或 helper,复用第一)。

### 3. 账户管理(accounts_page)

- DS:`AccountLocalDataSource` 增 `searchText`(name contains)或 bloc 层过滤(数据量小,选实现简单者,注释理由)。
- UI:头部 `SearchField`(无排序无分页)。

### TDD 测试

- DS 层:各模块查询参数单测(命中/忽略大小写/排序四态[债务]/分页 token[持仓]/默认路径不变)。
- Widget 层:各页搜索输入→列表变化;持仓翻页(小 pageSize 夹具);债务排序切换。照各模块既有测试模式(找 test/holding/presentation、test/debt/presentation 基线;缺则建)。

## 验证(全部执行并贴证据)

1. 新单测绿(先红后绿)
2. `flutter test` 全量不回归(≥1236)
3. `flutter analyze` 新文件 0 条

## 约束

NFR-2 默认行为不变;矩阵外页面零改动(预算/目标/分类/标签/模板);不动 transaction 模块;语义令牌;中文注释;不 commit。完成后报告。
