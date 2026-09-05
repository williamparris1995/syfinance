# Spec — F12 同步状态 UI

> R9 sprint-1 · 2026-09-03 · analysis 产出(F10/T3 review 已枚举决策点;本轮查证 UI 挂载点)。

## 查证事实基线

- `SyncCoordinatorBloc` 状态流就绪(`SyncStatus{idle,clean,syncing,failed}`+pendingCount 仅 syncing/failed 携带——**idle 态待同步数未暴露**,F10 review S-2);lazySingleton **生产无人 resolve**(F12 接线后才实例化)。
- 8 头表 DAO `watchPending*` 流存在(F10 T2 交付,仅 account 被测)。
- TODO-F12 锚点:迟构造不补发构造前回网边沿——需构造期补扫。
- 顶栏 `OfflineBadge`(app_shell.dart:494)为天然挂载邻居。

## Requirements

- **FR-1 同步状态指示**:顶栏 OfflineBadge 旁挂 `SyncStatusBadge`(仅绑定态渲染,guest 隐藏):待同步 N 笔(N>0 且非 syncing)/同步中(spinner)/失败(原因 chip,点击=手动重试)/clean(N=0 且无失败=隐藏)。R8 语义令牌。
- **FR-2 idle 态待同步计数**:bloc 订阅 8 模块 `watchPending*` 聚合流(墓碑计入:N=实体+墓碑数;去抖不必,drift 流本就按事务发射)——任何 `SyncStatus` 态都携带实时 pendingCount;guest 态计数归零不订阅。
- **FR-3 构造期补扫**(闭环 TODO-F12):bloc 构造时(仅 bound)collect 一次——有 pending 且 online → 直接触发一次同步;offline → 状态=待同步 N。迟构造错过边沿的场景由此兜底。
- **FR-4 失败重试**:failed 态点击 badge → `SyncRetryRequested`;重试中防重入(bloc 幂等已就绪)。
- **FR-5 测试与门**:bloc 单测(计数聚合/构造补扫/guest 不订阅)+widget 单测(badge 四态/点击回调/令牌);`make client-e2e`+`client-e2e-ui`+flutter test 全绿(guest 全链路零回归——badge 仅绑定态渲染,e2e guest 模式不出现)。

## NFR

- 状态流语义零破坏(F10 协调器行为/pending 语义不动,只增计数暴露与补扫)。
- R8 双主题语义令牌,禁 v1 硬编码色。

## Scope boundary

| 排除 | 理由 |
|---|---|
| 冲突解决 UI(ConflictDTO 列表/ ResolveConflict) | 单设备 conflicts 恒空,ticket 16 |
| PullChanges 拉取指示 | 同期无拉取,镜像走既有路径 |
| 同步历史/日志页 | YAGNI |

## Grill record

| 决策 | 定案 |
|---|---|
| 指示形态 | 顶栏 badge 紧邻 OfflineBadge(控件内聚、与离线语义并置)——技术推荐,零争议 |
| idle 计数来源 | watchPending 聚合流(S-2 落地)——review 既定方向 |
| 构造补扫 | 是(闭环 TODO-F12)——review 既定方向 |
| 墓碑计入计数 | 是(用户视角"有 N 条变更待同步",删除也是变更)——技术推荐 |

## Feasibility

technical ✓(bloc/DAO 流全在,纯 UI+接线);economic ✓;operational ✓(回归门)。
