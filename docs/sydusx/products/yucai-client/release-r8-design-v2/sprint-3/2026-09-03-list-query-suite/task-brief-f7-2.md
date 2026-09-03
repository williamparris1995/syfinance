# Task Brief F7-T2 — bloc+UI 层:筛选条扩展/排序控件/分页条

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f7`,客户端 `yucai/client/`。**TDD:bloc 单测与 widget 单测先红后绿。** T1(DS 层,commit a6738eba)已就绪:`ListTransactionsParams` 已有 category/searchText/sortKey/sortDir。

## 先读(必读)

1. `docs/.../2026-09-03-list-query-suite/spec.md` 的 FR-1/2/3/4 + design.md 的 ADR-4/5 + LLD
2. `yucai/client/lib/transaction/presentation/bloc/transaction_bloc.dart`(`_params` 映射 :222 附近、状态类、事件类、分页现状)
3. `yucai/client/lib/transaction/presentation/widgets/filter_bar.dart`(TxnFilterState :8 + 筛选条布局)
4. `yucai/client/lib/transaction/presentation/pages/transactions_page.dart`(列表装配 + _requestSummary)
5. `yucai/client/lib/transaction/domain/value_objects.dart`(T1 新枚举)
6. UI 风格基线:`lib/core/theme/app_design.dart` 语义令牌(context.yucai,R8 双主题,禁 v1 硬编码色)

## 交付物

### 1. `TxnFilterState` 扩展(filter_bar.dart)

- 增 `searchText`(String?,默认 null)、`sortKey`(TxnSortKey.date)、`sortDir`(TxnSortDir.desc)——copyWith 齐全。
- **category 字段已在**(type/accountId/category/month)——UI 下拉已存在,T2 只需让它经 bloc 真正生效(见 2)。

### 2. bloc(transaction_bloc.dart)

- `_params` 补映射:filter.category → params.category;searchText → params.searchText;sortKey/sortDir → params。
- 分页状态:状态类增 `pageIndex`(int,0 起)/`pageToken`(String?)/`hasMore`(bool)(命名随库内惯例);`ListTransactionsResult` 若已带 nextToken 则用之。
- 事件:增 `TransactionsPageChanged`(方向 prev/next 或直接页码,内部换 token 重发查询,**filter 不变**);既有 Load 事件语义 = **重置第 1 页**(任一筛选/搜索/排序变化触发,token 清空 pageIndex=0)。
- summary 联动:_requestSummary 只随 filter 变化,不随翻页重算(翻页只是切片)。

### 3. UI

- **filter_bar**:搜索框(TextField,前缀图标,suffix 清除钮;onChanged 提交或 onSubmitted——选实现简单且可测的;输入不 trim 空时不视为过滤,DS 层已容错)+ 排序控件(PopupMenu 或 SegmentedButton:键=日期/金额,方向=升/降;当前态显示)。布局按现有筛选条风格扩展,拥挤则换行/折叠,禁硬编码色。
- **transactions_page**:列表底部分页条——上一页/下一页 IconButton + 「第 N 页」文本;第 1 页禁用上一页、末页禁用下一页;仅 hasMore==false 且 pageIndex==0 时整个分页条隐藏(单页无需控件);翻页滚回列表顶部可选。
- **category 下拉**:确认其 onChanged 已走 Load 事件(现在会带 category 进 DS)——若下拉当前只是本地 UI 态没触发重载,接线之。

### 4. TDD 测试

- bloc 单测(`test/transaction/presentation/bloc/`,照既有 bloc 测试模式):映射正确性(category/search/sort 四态)、筛选变化重置第 1 页、翻页 token 前进/回退、末页 hasMore=false、summary 不随翻页重发。
- widget 单测(filter_bar/分页条):搜索输入→回调带 searchText;排序点选→回调四态;分页条按钮禁用态/回调。照既有 widget 测试模式(找 test/transaction/presentation/ 现有文件参考;需要 ThemeSettings fake 的照 R8 基线注入)。

## 验证(全部执行并贴证据)

1. 新增 bloc/widget 单测绿(先红后绿)
2. `flutter test` 全量不回归
3. `flutter analyze` 净(新文件 0 条)

## 约束

中文注释;不改 DS/domain(T1 已定);不动 e2e(T3);禁 v1 硬编码色(语义令牌);不 commit。完成后报告同 T1 格式。
