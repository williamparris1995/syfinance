---
feature: 2026-08-20-bound-mirror-logout
status: confirmed
---

# Design — 绑定后镜像写穿透 + 登出回本地

> 消费 [spec.md](spec.md)(confirmed)。机制选型:模块级刷新镜像(spec 头部)。写路径零改动(镜像在 repo 外挂触发);刷新面 = 现有 repo list(绑定态自动远端)+ 整表替换 + 实体→行 mapper(8 个,与 D/E local ds 的行→实体逆向)。

## Context

M2 完全体:登出即本地,镜像始终在位。G 的向导触发点(设置页 listener)升级为持久标记判断。

## Goals / NonGoals

- **Goals**:BoundMirror 服务/8 mapper/写后+登入+登出三触发点/bound_tenant 持久标记。
- **NonGoals**:离线续写(T16)/绑定态读镜像(M1 维持)/镜像失败 UI/冲突解决。

## Decisions(ADRs)

### ADR-1 镜像服务 = `BoundMirror`(@LazySingleton,core/session_mode 旁或 binding/data)
- **Decision**:`BoundMirror` 持 8 模块 repo 引用 + AppDatabase;公开 `refreshModule(MirrorModule m)` 与 `refreshAll()`——内部:远端 list(经 repo,绑定态自动远端)→ `replaceXxx` 整表替换(单 drift 事务:删该模块表→插映射行)。**触发点三处**(见 ADR-2/3);刷新 fire-and-forget(`unawaited`,异常 catch 记 debugPrint——静默重试语义=下次触发再刷)。同模块刷新去抖:进行中标志(串行同模块,防并发写竞争)。
- **Rationale**:整表替换天然幂等且捕获全部 server 副作用;个人数据量(百级行)整表替换毫秒级。
- **Alternatives**:①逐点写穿透——副作用抓不全(spec 头部已否);②增量 diff——无必要复杂度。

### ADR-2 写后触发 = repo 层后置钩子(不动写路径签名)
- **Decision**:各 dual-source repo 的**写方法**在 `_guard(() => _useLocal ? ... : _remote.X())` 成功(Right)且 `!_useLocal` 时,`unawaited(_mirror.refreshModule(m))`。实现在 repo impl 内加一行(每写方法),不改方法签名/返回。**只钩写方法**(list/get 不触发)。
- **覆盖面**:account(create/update/delete)·transaction(record×4/update/delete)·tag(create/update/delete/add/remove)·template(create/update/delete/pause/resume/record)·budget(create/update/delete/addItem/removeItem)·goal(create/update/delete/complete/recordContribution/clone)·debt(create/update/delete/recordPayment)·holding(buy/sell/dividend/split/createSecurity/updateSecurityPrice)。
- **Rationale**:repo 是写成败的单一判定点;fire-and-forget 不阻塞。
- **Alternatives**:remote ds 层钩——无会话语境(不知道绑定态),reject。

### ADR-3 登入/登出触发 = AuthBloc onChange 挂钩 + 登出终刷
- **Decision**:
  - **登入**(state→Authenticated):AuthBloc 已注入 SessionModeTracker——再注入 `BoundMirror?` 可选参(测试不传),onChange 里 `unawaited(_mirror?.refreshAll())`。**登入即镜像**(FR-1 场景 2)。
  - **登出**(state→Guest 之前):LogoutRequested handler 在 `_logout.call()` **前** `_mirror?.refreshAll()`(await,best-effort try/catch——此时仍 Authenticated,list 走远端;断网时 catch 直接登出,用现有镜像)。TokenRefreshFailed 同(登出前终刷可能无凭据,仅 best-effort)。
- **Rationale**:登出终刷抓住最后漏网;离线登出 catch 降级。放在 `_logout` 前保证 list 仍有有效 token。

### ADR-4 再登录标记 = `BoundMarker`(secure storage `yucai.bound_tenant`)
- **Decision**:新 `core/session_mode/bound_marker.dart`(FlutterSecureStorage 注入,`markBound(tenant)`/`isBound()`/`clear()`);**写点**:G 的 BindingBloc success 态时 markBound;**读点**:设置页 listener 的向导触发条件改为 `!await _boundMarker.isBound()`(替换进程 static);登出**不清除**标记(再登录跳向导靠它;「解绑」语义=换账号时 marker 被新绑定覆盖)。G 的 static flag 移除。
- **Rationale**:持久化跨重启;secure storage 与 token 同库惯例。

### ADR-5 实体→行 mapper = `MirrorMappers`(纯函数集,binding/data/)
- **Decision**:每模块 `db.XxxsCompanion.insert(...)` 构造函数(实体→行):实体缺的 drift 专属列(chartCode/isSystem/sortOrder/createdAt 审计列)取默认或实体值;goal links 数组→联结表行;transaction entries 嵌套→子表行;holding 需 holding 行 + transactions 行 + securities 行三面;budget 需 head+items(budget refresh = listBudgets + per-budget getBudget detail);debt = list + per-debt get(schedule)。
- **Rationale**:与 D/E local ds 的行→实体逆向同文件生态;纯函数易测。

## HLD

```
新增:binding/data/bound_mirror.dart(BoundMirror + MirrorModule 枚举)
     binding/data/mirror_mappers.dart(8 mapper 纯函数)
     core/session_mode/bound_marker.dart(持久标记)
改:  7 个 dual-source repo impl(写方法成功+远端态→unawaited refreshModule;约 30 个钩子行)
     auth_bloc(注入 mirror 可选参;登入 refreshAll;登出终刷)
     binding_bloc(success→markBound)
     settings_page(向导触发条件改 isBound();删 static)
```

## LLD 要点

### BoundMirror.refreshModule 骨架

```
Future<void> refreshModule(MirrorModule m) async {
  if (_inFlight.contains(m)) return; _inFlight.add(m);
  try {
    switch (m) {
      case MirrorModule.account:
        final r = await _accounts.list();
        r.fold((_) {}, (list) => _db.transaction(() async {
          await _dao.deleteAllAccounts();
          for (final e in list) await _dao.insertAccount(mappers.accountToRow(e));
        }));
      ... (transaction: list(pageSize: 大) + entries 嵌套; budget: list + per-get; debt: list + per-get; holding: 三面; goal: list+links; tag/template: list)
    }
  } catch (e) { debugPrint('[mirror] refresh $m failed: $e'); }
  finally { _inFlight.remove(m); }
}
```

DAO 需补 deleteAll 系列方法(8 模块,drift 一行式)。transaction 刷新的整表替换注意 FK 顺序(先 entries 后 heads 删,插反序)。

### 触发行形态(每写方法一行)

```
Future<Either<Failure, Account>> create(params) async {
  final r = await _guard(() => _useLocal ? _local.create(...) : _remote.create(...));
  if (r.isRight() && !_useLocal) unawaited(_mirror.refreshModule(MirrorModule.account));
  return r;
}
```
(实现为 repo 内 `_mirrored(m, body)` 小 helper 减重复。)

### 映射特例

- Account 实体缺 chartCode('')/isSystem(false)/sortOrder(0)——镜像行取默认(与 G 导出器同款处理)。
- Transaction.createdAt 可空(实体默认 null)→镜像行取 now(审计列非业务语义)。
- Debt: list 返回 Debt(无 schedule)→per-debt `get(id)` 拉 DebtDetail(schedule 嵌套)。
- Budget: listBudgets 无 items→per-budget getBudget。
- Holding: listHoldings + listHoldingTransactions + listSecurities 三面同事务替换。
- Goal: listGoals 实体带 linkedAccountIds/linkedDebtIds→head+两联结表。

### 测试计划

- MirrorMappers 单测 ×8(实体→行往返:行→实体[D/E mapper]→行 field 抽查)。
- BoundMirror 集成测:fake repos 返回样例列表→refreshModule→drift 表断言;inFlight 去抖;失败静默。
- repo 钩子测试:抽查 account/transaction 写成功(远端态)触发 mirror(mock mirror verify);guest 态不触发。
- AuthBloc 登入 refreshAll/登出终刷(mock mirror)。
- BoundMarker:mark/isBound/clear roundtrip(fake secure storage)。
- 设置页触发:isBound→不 push(已有测试改造)。
- 回归:全套基线。

## Risks

- **R1 整表替换期间登出竞刻**(刷新事务中途 Guest 切换):drift 事务原子,读到旧或新均完整——accepted。
- **R2 大账号首刷时延**:个人量级毫秒;fire-and-forget 无感知。
- **R3 per-budget/per-debt N+1**:量级小(月度预算/个位数债);accepted。

## Migration

无 schema 变更;BoundMarker 新 secure storage key。

## Open Questions

1. securities 镜像放 holding 模块刷新内(现设计)——currency 引用表镜像 defer(静态种子已兜底,远端 currency list 差异小)。
