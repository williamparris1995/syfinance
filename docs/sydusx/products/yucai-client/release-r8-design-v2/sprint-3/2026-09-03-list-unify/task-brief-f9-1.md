# Task Brief F9-T1 — 共享设施:PagerBar 泛化 + PageCursorStack 提取 + 交易页迁移

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f9`,客户端 `yucai/client/`。**TDD,行为逐位不变。** F7(已合入 main)是基线:TxnPagerBar 在 `lib/transaction/presentation/pages/transactions_page.dart`(约 :1153-1240 区域,@visibleForTesting 公开),token 栈在 `lib/transaction/presentation/bloc/transaction_bloc.dart` `_pageTokens`。

## 先读(必读)

1. `docs/sydusx/products/yucai-client/release-r8-design-v2/sprint-3/2026-09-03-list-unify/{spec.md,design.md}`(FR-1 + ADR-1/2)
2. `lib/transaction/presentation/pages/transactions_page.dart` 的 TxnPagerBar/_PagerFooter/_showPager
3. `lib/transaction/presentation/bloc/transaction_bloc.dart` 的 _pageTokens/_onGoToPageRequested
4. `test/transaction/presentation/widgets/list_query_widgets_test.dart` 的 pager 3 测 + `test/transaction/presentation/pages/transactions_page_test.dart` 分页测

## 交付物

### 1. `lib/core/widgets/pager_bar.dart`(新)

通用 `PagerBar`:从 TxnPagerBar 提升泛化——参数 `pageIndex`(0 起)/`hasMore`/`loading`/`onPrev`/`onNext`(语义不变:第 1 页禁 prev/末页禁 next/loading 双禁+小 spinner/「第 N 页」);语义令牌 context.yucai;中文注释+dartdoc(注明 F9 从 TxnPagerBar 提升,各列表页复用)。附 widget 单测(照 F7 pager 3 测迁移+保绿)。

### 2. `PageCursorStack` 提取

从 transaction_bloc 的 `_pageTokens` 栈逻辑提取为可复用类(落点:presentation 共享层,如 `lib/core/widgets/page_cursor_stack.dart` 或按依赖方向更合适处——自行判断,注释理由):`push(pageIndex, token)`/`tokenFor(pageIndex)`/`clear()`,不变式注释照搬 F7(`stack[i]=第 i 页起始 token`;next 覆写同值幂等/prev 复用)。附单测(next→prev→next 序列不变式)。transaction_bloc 改用之,**行为逐位不变**。

### 3. 交易页迁移

TxnPagerBar 删除,transactions_page 与既有测试改用共享 PagerBar;F7 的 pager 相关测试(list_query_widgets_test 3 测 + transactions_page_test 分页测)迁移后保绿(改 import/引用,不改断言语义)。

## 验证(全部执行并贴证据)

1. 新增 pager_bar/page_cursor_stack 单测绿(先红后绿)
2. F7 既有测试迁移后全绿(list_query_widgets + transactions_page + transaction_bloc)
3. `flutter test` 全量不回归(≥1224)
4. `flutter analyze` 新文件 0 条

## 约束

行为逐位不变(NFR-1);中文注释;不动 DS/domain;不 commit。完成后报告。
