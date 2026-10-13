# Task Brief T5 — 工具页返回退役 + 面包屑 location 覆盖 + hideTopBar 全退役

## 位置与环境
- worktree(只在此):`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r19-f59`;client `<worktree>/yucai/client`
- 规格:`<feature>/spec.md` FR-6/FR-7 + design.md ADR-2 处置表。`<feature>` = docs/sydusx/products/yucai-client/release-r19-shell-navigation/sprint-1/f59-shell-nav-sweep
- 前置读:`app_shell.dart` 的 `_branchMetaOf`(已有 `_isSubscriptionManagement` location 覆盖先例)与 `hideTopBar`。

## 任务
1. **app_shell**:
   - `_branchMetaOf` 增 location 覆盖条目:`/categories` →「交易 › 分类管理」;`/tags`(或实际路由,先核实 tag_page 路由)→「交易 › 标签」;templates 周期模板页路由 →「交易 › 周期模板」(若 `_isSubscriptionManagement` 已覆盖部分,合并口径);backup 页路由(核实 branch 归属,settings?)→ 对应 section › page 覆盖。
   - `hideTopBar`/`_isCategoryManagement` **全退役**(变量与函数删除)。
2. **categories 页**(`category_management_page.dart`):专属 topbar 的 crumb 部分退役(全局顶栏已显「交易 › 分类管理」);页面头(h1/sub/导入模板/新建分类)保留为内容头;mobile 紧凑态同步调整。
3. **template_page(周期模板)/tag_page/backup_page**:自带 topbar 的**返回箭头退役**(面包屑 page 级回退);标题/操作钮(新建/立即备份)保留为内容头;注意 backup 页在哪个 branch(面包屑覆盖正确 section)。
4. transaction_detail 的 page-head「返回」链接退役(FR-7,一行级——若 T3 未处理则此处顺手;先 grep 确认不与 T3 交叠,**若 T3 并行在改该文件则跳过并在报告注明交由 T3**)。
5. 测试(先红后绿):各覆盖页面包屑串断言;返回箭头零残留;hideTopBar 逻辑删除后 categories 路由下 _TopBar 存在;既有断言更新。

## 约束
不碰 detail 页/form 页/design_kit(他任务并行);日志英文;注释中文。

## 完成证据
测试输出(0 failures)+ analyze 无新增 + 改动清单 + 各页路由/branch 归属核实表 + 偏离说明。
