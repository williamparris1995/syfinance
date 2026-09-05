# Code Plan — F12 同步状态 UI

> execute 分解。约束:TDD;F10 协调器语义零破坏;guest 链路零回归。

## Tasks

- [x] **T1 计数+补扫**:PendingCountWatcher+bloc 计数全态携带+构造补扫+墓碑 watch 流;TDD 单测(聚合/补扫两分支/guest/泄漏)。验证:定向+全量。
- [x] **T2 badge+挂载**:SyncStatusBadge 四态+app_shell 挂载(仅绑定态)+手动重试;widget 单测;guest e2e 零回归验证(make client-e2e+client-e2e-ui 抽样)。
- [x] **T3 全量门**:flutter test/analyze/make client-e2e+client-e2e-ui 全量+提交。

## 执行方式

T1→T2→T3 串行派发,T1/T2 两轴 review,修复循环 ≤5。


## Ledger 记账

| task | 状态 | fix-rounds | 记事 |
|---|---|---|---|
| T1 计数+补扫 | ✅ | 0(review 7/7) | TDD 逼出两真问题:bloc 8.1.4 子类型派发陷阱(计数事件绕闸)/补扫陈旧计数覆盖(_watcherCounted 同步段旗标) |
| T2 badge+挂载 | ✅ | 1(条件注入根治 guest 构造推翻 T1 前提→登录后补扫恢复+翻转测试直证;A/C 注释精化) | failed 优先级定案:失败原因+重试是唯一可行动信号 |
| T3 全量门 | ✅ | 0 | 管道 11+UI 12+1422 全绿(UI 门全量——F9 教训执行) |
