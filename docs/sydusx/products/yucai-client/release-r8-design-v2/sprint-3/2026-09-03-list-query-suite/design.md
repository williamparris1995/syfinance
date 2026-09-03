# Design — F7 列表查询四件套

> R8 sprint-3 · 2026-09-03。spec 三决策(描述搜索/四态排序/页码控件)驱动;全程内存管道,无新基建。

## Decisions (ADRs)

- **ADR-1 扩展既有参数对象**:`ListTransactionsParams` 增 `category`(AccountCategory?)/`searchText`(String?)/`sortKey`(date|amount,默认 date)/`sortDir`(asc|desc,默认 desc)——加法式扩展,不动既有调用方。备选:独立 Query 对象(过度设计,拒)。
- **ADR-2 过滤链顺序固定**:`_assembleAll` 全量 → 内存过滤(账户→日期窗→类型→**分类**→**搜索**)→ **排序**(键切换,tie-break 恒 `transactionDate DESC, id DESC` 保稳定序)→ offset 分页。搜索/分类过滤插在类型过滤后、排序前。
- **ADR-3 金额口径** = Σdebit entries(复式 invariant=Σcredit;转账/复合交易均为总额)。
- **ADR-4 UI 形态**:filter_bar 增搜索框(TextField,onChange 提交)+ 排序 PopupMenu(键×方向四态);列表底部分页条(上一页/下一页 + 「第 N 页」);bloc 状态增 pageIndex/pageToken/hasMore,**任一筛选/搜索/排序变化 → 重置第 1 页**;末页禁用下一页。
- **ADR-5 测试策略 TDD**:DS 单测(组合矩阵:分类×搜索×排序×分页)→ bloc 单测(映射/重置语义)→ widget 单测(filter_bar/分页条)→ e2e 断言扩展(级链⑥ + ui_list_filter)。

## HLD

改动面(全部 transaction 模块纵向切片):
- `lib/transaction/domain/value_objects.dart`:`ListTransactionsParams` +4 字段;`TxnSortKey/TxnSortDir` 枚举。
- `lib/transaction/data/transaction_local_ds.dart`:`list()` 过滤链插入分类/搜索 + 排序切换。
- `lib/transaction/presentation/bloc/transaction_bloc.dart`:`_params` 映射 category/searchText/sort;状态增分页三件;事件增 GoToTransactionsPageRequested(下一页/上一页)。
- `lib/transaction/presentation/widgets/filter_bar.dart`:搜索框 + 排序控件(TxnFilterState 增字段)。
- `lib/transaction/presentation/pages/transactions_page.dart`:分页条。
- e2e:`link_mutation_cascade_test.dart` 级链⑥ 扩展;`ui_list_filter_test.dart` 扩展。

## LLD 要点

- 分类过滤口径:交易任一 entry 的账户 `category == 参数分类`(与账户筛选的"任一 entry 涉及"对齐)。
- 搜索:`row.description.toLowerCase().contains(q.toLowerCase())`,null description 视空串。
- 金额排序:预计算每笔 `entries.fold(Σdebit)`,排序比较;tie-break ADR-2。
- 分页:沿用 `pageToken`=数字 offset 字符串;`hasMore = end < length`;UI 页码 = pageIndex+1。
- 重置语义:bloc 收到带新 filter 的 Load 事件 → token 清空 pageIndex=0;GoToTransactionsPageRequested 事件携带 filter 不变仅换 token。

## Risks

| 风险 | 缓解 |
|---|---|
| 默认序回归 | NFR-1:无参数时比较路径与现状逐位一致;F6 默认序断言不动 |
| 既有调用方破坏 | 参数全可选默认现行为;全量单测+e2e 门 |
| 内存全量扫描性能 | 个人量级(千级),现状既如此,YAGNI |
| filter_bar 布局拥挤 | 搜索框独立一行或折叠,实现时按现有布局样式调整,widget 测试断言可达 |

## Migration

无 schema/契约变更;纯客户端。merge 后 CLAUDE.md 无需改(命令不变)。

## Open Questions

无(spec 三决策已定;金额口径 ADR-3 实现时如遇复合交易歧义以 Σdebit 为准并注释)。
