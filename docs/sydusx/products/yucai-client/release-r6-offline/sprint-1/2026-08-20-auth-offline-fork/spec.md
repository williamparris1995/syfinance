---
feature: 2026-08-20-auth-offline-fork
status: confirmed
---

# Spec — 启动鉴权分流 + 游客模式

> R6 sprint-1 feature B。源:R6 release 决策(M1 缓解:分流对所有用户生效)+ feature.md stories。
> 现状根因:`auth_bloc.dart:26-33` fold `_` 一刀切——`_mapGrpcError` 已把 `unavailable` 映射为 `NetworkFailure`(失败类型可区分),但任何失败一律 `Unauthenticated` → 路由踢 `/login`;登录页仅 Google OIDC 一入口。
> 纯 behavior;状态机/守卫重构细节留 design.md。**游客的数据可用性来自 feature C 的 seam**——本 feature 验收以鉴权行为为准,不要求游客数据加载成功。

## ADDED Requirements

### Requirement: FR-1 AppStarted 失败分流(三分支)
- [ ] AppStarted SHALL 按失败原因与本地凭据分流:①有本地 token 且 GetProfile 因网络不可达失败(NetworkFailure)→ 进入**离线保留会话态**(不踢登录页);②token 无效/过期(AuthFailure,含在线场景)→ `Unauthenticated`(现状);③本地无 token → 进入 `Guest`(游客态)。

#### Scenario: 断网启动(已绑定用户)
- GIVEN 曾登录(token 在 keychain),网络不可用
- WHEN AppStarted → GetProfile 抛 NetworkFailure
- THEN 进入离线保留会话态,停留在业务路由(不被重定向 `/login`)

#### Scenario: token 失效(在线)
- GIVEN 有 token,网络可用,token 已过期且 refresh 失败
- WHEN AppStarted → GetProfile AuthFailure
- THEN `Unauthenticated` → 重定向 `/login`(现状不变)

#### Scenario: 全新安装无 token
- GIVEN 无任何 token
- WHEN AppStarted → GetProfile 无凭据失败
- THEN 进入 `Guest`,落在业务首屏(单机可用第一面)

### Requirement: FR-2 游客可达业务路由(守卫重定义)
- [ ] 路由守卫 SHALL 重定义为「绑定专属路由拦截」而非「全部业务路由拦截」:Guest/未登录用户可达 `/home` `/accounts` `/transactions` `/categories` `/debts` `/receivables` `/holdings` `/budgets` `/goals` `/reports` `/settings`;绑定/云端专属入口(如云备份设置)仅 Authenticated 可达。

#### Scenario: 游客进入业务路由
- GIVEN app 处于 Guest
- WHEN 导航至 `/accounts`(或任一业务路由)
- THEN 不被重定向 `/login`,页面可渲染(数据态依赖 feature C,允许错误/空态)

#### Scenario: 游客访问绑定专属入口
- GIVEN app 处于 Guest
- WHEN 导航至绑定专属路由(云备份设置)
- THEN 重定向 `/login`(守卫保留)

### Requirement: FR-3 登录入口双向可达
- [ ] LoginPage SHALL 保持现有 Google OIDC 登录能力(已绑定用户 token 失效后登录路径不变);GUEST 态 SHALL 有可达的登录入口(设置页/引导),登录页 SHALL 提供「先不登录,离线使用」入口(→ Guest)。

#### Scenario: 游客选择登录
- GIVEN Guest
- WHEN 用户从设置页进入登录页并完成 Google OIDC
- THEN 转为 Authenticated(绑定链路的 UI 面就绪;上传流程归 feature G)

#### Scenario: 登录页跳过
- GIVEN LoginPage 展示
- WHEN 点击「先不登录,离线使用」
- THEN 进入 Guest 业务首屏

### Requirement: FR-4 登出转游客(非登录页)
- [ ] 登出 SHALL 使 app 转入 `Guest`(清 token 现状保留),而非 `Unauthenticated` 踢登录页——「绑/不绑是用户自由选择」的状态机闭环(M2 的 B 侧基础;登出后本地数据可见性归 feature H 镜像)。

#### Scenario: 已绑定用户登出
- GIVEN Authenticated
- WHEN 登出(清 token)
- THEN 转入 Guest,业务路由继续可达(数据态依赖 H)

### Requirement: FR-5 在线/离线网关(connectivity_plus 转用)
- [ ] app SHALL 暴露可观察的在线/离线状态流(基于 connectivity_plus,含初始态与变化事件),供 UI 指示与 feature C seam 消费;状态流 SHALL 在桌面(Windows)平台可用。

#### Scenario: 网络恢复事件
- GIVEN app 运行中,当前离线
- WHEN 网络恢复
- THEN 状态流发射在线事件(订阅者可感知)

### Requirement: NFR-1 已绑定在线路径零回归
- [ ] Authenticated 用户的在线使用路径(登录/刷新/401 retry/页面行为)SHALL 与现状完全一致;`flutter test` 基线不退化(4 fail/3 文件内)+ `flutter analyze` 不新增。

### Requirement: NFR-2 零 server 改动
- [ ] 本 feature SHALL NOT 改动 yucai/server 任何代码;`go test ./...` 保持全绿。

## scope boundary

- **IN**:AuthBloc 状态机扩展(Guest/离线保留会话)+ AppStarted 三分支 + 路由守卫重定义 + 登录页双向入口 + 登出转 Guest + connectivity 网关。
- **OUT**:repository 双源/游客数据可用性(feature C)/绑定上传(feature G)/登出后本地镜像数据(feature H)/离线保留会话态下的数据降级 UI(现状错误态,改善归 C/F)。
- **已知张力(accepted,继承 R6 M1)**:B 落地后、C 落地前,游客/离线用户的业务页面数据将呈现网络错误/空态——sprint 内 B→C 相邻交付,窗口有限。
- **依赖**:无代码依赖 feature A(drift);connectivity_plus ^6.1.2 已在 pubspec(死依赖转用)。

## 可行性

- **technical**:可行——失败类型已可区分(`_mapGrpcError` 有 NetworkFailure),改造集中在 AuthBloc/-router/-login 三处;connectivity_plus 支持 Windows。
- **economic**:可行——纯 client 增量,无新依赖。
- **operational**:可行——单用户桌面/移动;离线态是纯本地判断,无服务端面。
