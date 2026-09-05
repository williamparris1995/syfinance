# Code Plan — F8 标签维度

## Tasks

- [ ] **T1 管道层**:TagDao 反查+ListTransactionsParams.tagId+DS list/summary 过滤+repo summary 透传;TDD 单测(命中/空集/叠加/summary 口径/默认不变)。
- [ ] **T2 UI 层**:filter_bar 标签下拉+bloc 映射+标签页跳转+报表页筛选;widget/bloc 单测。
- **T3 门(controller)**:e2e 扩展(管道 tagId 断言+UI 三断言)+三门全绿+提交。

## 执行方式

T1→T2 派发(各两轴 review),T3 controller 执行。
