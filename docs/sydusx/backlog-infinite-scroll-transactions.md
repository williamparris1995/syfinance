# Task Brief — 交易列表无限滚动改版(反馈#2-B,用户拍板)

**工作目录**:`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance`(分支 main),代码 `yucai/client/`。**前置:必须等拖选/右键菜单票(同页改造)提交后再开工**(读 git log 确认其 commit 在)。

## 目标(YNAB/MoneyWiz 式桌面主流形态)

交易记录页 `transactions_page.dart` 从「页条分页(10/页)」改「**按月分组 + 滚动到底自动加载**」:

1. **bloc**(`transaction_bloc.dart`):首页 50 条(pageSize 50 复用既有 ListTransactionsParams);滚到底(ScrollController 距底 <400px)自动加载下一页(pageIndex+1)追加模式;防抖(加载中不重入);hasMore=false 终止并页脚显示「已全部加载 · 共 N 条」(N=累计)。筛选/汇总重算路径改为重置到第一页。
2. **分组 UI**:ListView.builder(虚拟化,数据=分组展开模型)——月份组头(「2026 年 9 月」+当月收入/支出小计,样式照 design-v2 卡片分隔条先例,零裸色);**移除 PagerBar 及其调用**(core 的 PagerBar 组件保留,别处还在用)。
3. **首屏体验**:加载态骨架沿用;空态/错误态不变;汇总条不动。
4. **测试(TDD)**:bloc(首页加载/滚动触发追加/重入防抖/hasMore 终止/筛选重置)+widget(组头+小计渲染/滚到底触发/「已全部加载」出现);既有交易页测试同步迁移(页条断言→新形态);全量绿+analyze 零新增。

## 边界

不动账户详情页近期交易、不动 DAO 分页参数形态(pageIndex 复用)、不动 server。旧「分页页脚」注释块清理。

commit(main):`feat(transaction): 列表无限滚动改版 —— 按月分组+滚动加载+月小计(反馈#2-B)`。回报:交互决定/测试数/commit hash。
