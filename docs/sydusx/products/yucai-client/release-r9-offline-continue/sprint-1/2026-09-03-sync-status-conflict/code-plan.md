# Code Plan — F12 同步状态 UI

> execute 分解。约束:TDD;F10 协调器语义零破坏;guest 链路零回归。

## Tasks

- [ ] **T1 计数+补扫**:PendingCountWatcher+bloc 计数全态携带+构造补扫+墓碑 watch 流;TDD 单测(聚合/补扫两分支/guest/泄漏)。验证:定向+全量。
- [ ] **T2 badge+挂载**:SyncStatusBadge 四态+app_shell 挂载(仅绑定态)+手动重试;widget 单测;guest e2e 零回归验证(make client-e2e+client-e2e-ui 抽样)。
- [ ] **T3 全量门**:flutter test/analyze/make client-e2e+client-e2e-ui 全量+提交。

## 执行方式

T1→T2→T3 串行派发,T1/T2 两轴 review,修复循环 ≤5。
