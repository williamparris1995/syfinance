# Design — F9 列表能力统一

> R8 sprint-3 · 2026-09-03。F7 模式推广,共享设施先行。

## Decisions (ADRs)

- **ADR-1 共享 PagerBar**:`TxnPagerBar` 从 transactions_page 提升为 `core/widgets/pager_bar.dart` 通用 `PagerBar`(参数:pageIndex/hasMore/loading/onPrev/onNext/语义令牌),交易页改用;F7 的 widget 测试随迁移保绿。
- **ADR-2 PageCursorStack 助手**:transaction_bloc 内 `_pageTokens` 栈逻辑提取为 `core/widgets/`(或 transaction/domain?实现时按依赖方向定,倾向 presentation 层共享)`PageCursorStack`(push/peek/clear),各 bloc 复用;行为注释照搬 F7 不变式。
- **ADR-3 各模块 DS 查询参数照 F7 模式**:holdings/debt/account 本地 DS 增可选参数(searchText/sortKey/sortDir/pageSize/pageToken 按需),in-memory 过滤/排序/offset;默认路径零行为变化。
- **ADR-4 账户详情复用交易管道**:`TransactionRepository.list(accountId: ...)` + PagerBar + 搜索/排序控件(轻量版,复用 F7 widget);替换 Task 6 迷你分页;首屏语义=近期交易(默认日期降序第 1 页)。
- **ADR-5 低增长页零改动**(矩阵定案)。

## HLD 改动面

- `core/widgets/pager_bar.dart`(新)+ transaction 页迁移
- `account/presentation/pages/account_detail_page.dart`(内嵌交易区)
- `holding/`(DS list 参数 + holdings_page/security_page 控件)
- `debt/`(DS list 参数 + debts_page/receivables_page 搜索/排序)
- `account/presentation/pages/accounts_page.dart`(搜索框)
- e2e:级链或新文件补断言

## LLD 要点

- 持仓搜索匹配:security symbol/name contains 忽略大小写;排序键(到期日/金额)口径在实现处注释。
- 债务排序:totalPrincipalCents / dueDate;搜索:counterparty contains。
- 账户搜索:name contains(备注/notes 不搜,保守)。
- 各 DS 参数命名对齐 F7(searchText/sortKey/sortDir/pageSize/pageToken)。

## Risks

| 风险 | 缓解 |
|---|---|
| F6/F7 断言回归 | NFR-1:full_audit A3 不改不红;全量门 |
| 账户详情首屏语义变化 | NFR-2:默认页语义等价;A3 断言守住 |
| 泛化迁移引入漂移 | ADR-1 迁移后 F7 widget 测试保绿为准 |

## Open Questions

- PageCursorStack 落点(core vs 模块)——实现时按依赖方向定,倾向 presentation 共享层。
