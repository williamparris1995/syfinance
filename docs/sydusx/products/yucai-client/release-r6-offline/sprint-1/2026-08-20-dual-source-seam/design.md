---
feature: 2026-08-20-dual-source-seam
status: drafted
---

# Design — repository 双源 seam + account 试点

> 消费 [spec.md](spec.md)(confirmed)。事实基础:`AccountRepositoryImpl` = remote ds 上的 thin `_guard`(5 方法);domain 枚举 index+1 = 契约 int(AccountType/Category/Ownership/Status 全部成立;server 枚举从 1 起);drift `Accounts` 表列 = 契约字段(A 落地)。

## Context

R6 sprint-1 收口:定型双源 seam 范式并以 account 试点打通「断网无账号记账」全链路(成功判据①首块)。

## Goals / NonGoals

- **Goals**:seam 形态定型(G2)+ account 游客全链路 + 范式接线清单(FR-5)。
- **NonGoals**:其余模块(sprint-2)/镜像写穿透(H)/绑定上传(G)/Offline 降级读(accepted 张力)。

## Decisions(ADRs)

### ADR-1 seam 形态 = 镜像 remote_ds 的 local ds + repository 逐调用路由(G2 定案)
- **Decision**:新建 `AccountLocalDataSource`(与 `AccountRemoteDataSource` 同方法面:list/create/getById/update/delete,drift-backed);`AccountRepositoryImpl` 构造注入两 ds,每次调用按会话模式路由:`isGuest ? local : remote`(远端路径逐字不动)。
- **Rationale**:remote_ds 本就是既有 seam 形态,同构加一路是最小范式;mapper 集中在 local ds;sprint-2 复制面 = 每模块「一个 local ds + repo 一行路由」。
- **Alternatives**:①repo 内直接调 DAO——映射逻辑散进 repo,复制面模糊;②独立 GuestXxxRepository + 上层切换——破坏 FR-4 bloc 无感;③双 repo 实现 + injectable 环境切换——静态绑定,会话中切换失效。

### ADR-2 会话态源 = core 层 `SessionModeTracker`,AuthBloc 驱动
- **Decision**:core 新增 `SessionModeTracker`(`ValueNotifier<bool>` 语义,`bool get isGuest`,默认 true);`AuthBloc` 注入并在 `onChange` 统一同步 `tracker.isGuest = state is Guest`;repositories 经构造注入消费。
- **Rationale**:分层不倒置的唯一解——data→core 合法、presentation→core 合法,状态源放 core 双向可达;`onChange` 单点同步免散落;测试直接设 tracker。
- **Alternatives**:①repo 直接读 AuthBloc——data→presentation 违反 NFR-1;②DI 环境键静态切换——同 ADR-1③;③每次路由时 getIt 解析——隐藏依赖,难测。

### ADR-3 映射层 = local ds 内聚;枚举映射规则 index+1
- **Decision**:drift 行 ↔ `Account` 实体的双向映射全部内聚在 `AccountLocalDataSource`;枚举映射统一规则 **domain `.index + 1` ↔ 契约 int**(逆向按 index 取成员);时间戳 drift 直接吃 DateTime(TEXT 存储,build.yaml)。
- **Rationale**:枚举序与 server iota 的 +1 关系已核实(4 个枚举全成立);集中一处便于 sprint-2 逐模块复制与审查。
- **风险记录**:server 若重排枚举成员,index+1 静默错位——映射单测钉死当前值;**sprint-2 注意 DebtType 从 0 起(例外,不加 1)**。

### ADR-4 游客写语义(local ds 内实现)
- **Decision**:
  - **create**:client 生成 UUID(`uuid` v4);`version=1`;`currentBalanceCents=initialBalanceCents`;`status=active`(契约 int 1);时间戳本地时钟(UTC);`sortOrder=0`;其余空默认。
  - **update**:patch 语义镜像远端——`UpdateAccountParams` 的非默认字段(非 ''/非 0/非 null)才写 companion;`version = params.version + 1`;返回更新后实体。
  - **delete**:先读行,`currentBalanceCents != 0` → `ServerFailure('账户余额非零，无法删除，请先清空余额或转账后再试')`(与远端同文案同语义);为 0 才删。
- **Rationale**:游客行为习惯与远端一致(FR-2);文案复用避免两套话术。

## HLD

```
新增/改动(全 client):
core/session_mode/session_mode_tracker.dart   新增(ADR-2)
account/data/account_local_ds.dart            新增(ADR-1/3/4:映射+写语义)
account/data/account_repository_impl.dart     改:构造 +local +tracker;每方法一行路由
auth/presentation/bloc/auth_bloc.dart         改:注入 tracker + onChange 同步
core/di/injection.dart                        改:手动注册 SessionModeTracker
(零改动:domain 接口/remote_ds/usecases/bloc/pages —— FR-3/FR-4)
```

依赖方向:`local_ds → core/localdb(DAO) + domain(params/entity)`;`repo_impl → 两 ds + core tracker`;`auth_bloc → core tracker`。无新跨模块 import。

## LLD

### 路由伪码(repo_impl 每方法)

```
Future<Either<Failure, List<Account>>> list() =>
    _guard(() => _tracker.isGuest ? _local.list() : _remote.list());
```

### SessionModeTracker 契约

```dart
class SessionModeTracker {
  bool get isGuest;            // 默认 true(AppStarted 前安全侧:本地)
  set isGuest(bool value);     // AuthBloc.onChange 同步;测试直设
}
```

### 映射表(字段级)

- **直映射**(同名同义):id/name/currencyCode/initialBalanceCents/currentBalanceCents/icon/color/parentId(注意:domain parentId '' = 一级 ↔ drift NULL——双向特例)/institution/creditLimitCents/cardNumberTail/notes/openingDate/interestRate/creditBillingDay/creditRepaymentDay/creditAnnualFeeCents/invest*/fixed*/gold*/estate*/loan* 共 40+ 字段,camelCase↔snake_case。
- **枚举(index+1)**:accountType/category/ownership/status。
- **仅 drift 侧**:chartCode('')/isSystem(false)/sortOrder(0)/version/createdAt/updatedAt——domain 实体无这些列,行侧由 local ds 填默认。
- **domain 实体缺的契约字段**(chartCode/isSystem/sortOrder):本地行有列但实体不暴露——v1 接受(读模型是 proto 面),绑定导出时 drift 行自带真实值。

### create/update/delete 流程

1. create:params → companion(id=uuid.v4, version=1, currentBalance=initial, status=1, 时间戳 now UTC, 空默认)→ insert → 重读行 → 映射实体返回。
2. update:读行(不存在→`ServerFailure('账户不存在')`);按非默认字段构造 AccountsCompanion(仅设 Value 的字段 + id + version+1 + updatedAt)→ write → 重读返回。
3. delete:读行 → 余额非零→失败;否则 delete。

### FR-5 模块接入双源步骤清单(sprint-2 复制)

1. 新建 `<module>/data/<module>_local_ds.dart`:行↔实体映射(枚举 index+1,核对 server iota 起点)+ 写语义默认值/patch/校验。
2. `<module>_repository_impl.dart` 构造 +local +tracker,每方法 `isGuest ? local : remote`。
3. local ds 单测(内存库:CRUD+映射+写语义)+ repo 路由测试(fake 两 ds + tracker 两态)。
4. 既有模块测试零改动回归(FR-4 同款验收)。

### 测试计划

- `account_local_ds_test`:内存库——create 默认值/UUID/映射回环/patch 更新/余额删除校验/parentId ''↔NULL。
- `account_repository_impl_test`:fake remote/local + tracker——Guest 走 local(零 remote 调用)/非 Guest 走 remote/切换后新调用生效。
- `session_mode_tracker_test`:默认 true/可设。
- 既有 account 测试(bloc/page/usecase)零改动全绿(FR-3/FR-4 验收)。

## Risks

- **R1 枚举重排静默错位**(ADR-3)——映射单测钉死 + sprint-2 DebtType 例外注记。
- **R2 tracker 同步时序**:AuthBloc onChange 同步赋值,repo 调用读同一内存值——无异步窗口;AppStarted 前默认 guest(本地)与「无凭据→Guest」一致。
- **R3 OfflineAuthenticated 走远端必失败**——spec accepted 张力,H 镜像后重估。

## Migration

纯新增+repo 构造扩展;无数据迁移。injectable 重新生成(AuthBloc 构造 +1 参数)。

## Open Questions

1. sprint-2 各模块 local ds 的 parentId 类「''↔NULL」特例逐模块核对(transaction 无此型;debt 的 collectionAccountId 可空直映)。
2. 引用数据 seed(currency/security)仍 open(feature C/E 边界不变)。
