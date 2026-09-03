# Sprint 3 — R8 列表查询与标签维度补全

> Sprint Goal + feature roster。`/sydusx-portfolio`(2026-09-03)。来源:F6 holistic 测试暴露的功能缺口(sprint-2 defer 区,用户拍板补齐)。

## Sprint Goal

**补齐 F6 测试确认缺失的查询功能**:交易列表的筛选(含 category 接线)/搜索/排序/分页 UI 全量落地;标签反查与报表标签维度补全——使"每个模块和关联性都测"从照实排除变为全覆盖。

## Feature roster(依赖排序)

- [x] **feature F7** 2026-09-03-list-query-suite — 列表查询四件套 ✅ done(2026-09-03,merge `9eee8de5`;category 接线全链路+描述搜索[提交制]+日期/金额四态排序+页码分页;TDD 54 新单测+e2e 级链⑦/UI 筛③④⑤;三门 GREEN[client-e2e 10 文件/client-e2e-ui/1224 单测];review 抓修 desktop 搜索焦点缺陷)
- [ ] **feature F8** 2026-09-03-tag-dimension — 标签维度:按标签反查交易 + 报表标签口径
- [ ] **feature F9** 2026-09-03-list-unify — 列表能力统一:分页/搜索/排序按实体增长特性适配推广 F7 模式(账户详情/持仓/债务/债权/账户等)(claimed: zcode-r8-f9 2026-09-03)

> F7 先行(用户点名重点);F8 无依赖可并行认领(注意 worktree 占用互斥)。

## defer

- 需活服务器的缺口(服务器备份/OIDC/绑定镜像)——环境定义,不属本 sprint
- F6 生产疑点 6 处(订阅管理路由 bug 等)——另行 ticket 化,不混入本 sprint

## status: pending
