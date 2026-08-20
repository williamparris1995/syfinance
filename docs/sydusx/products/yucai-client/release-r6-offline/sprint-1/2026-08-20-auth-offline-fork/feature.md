# Feature — 启动鉴权分流 + 游客模式

> R6 sprint-1 feature B(依赖 A 不强,可与 A 并行)。
> 现状根因:`auth_bloc.dart:26-33` fold 一刀切,任何失败(含断网)→ `Unauthenticated` → 路由踢 `/login`;登录页仅 Google OIDC 一入口,无游客路径。

## Description

App 启动 `AppStarted` 区分失败原因:**有本地 token + NetworkFailure → 进入离线态(保留会话,不被踢)**;AuthFailure(token 失效/无 token)→ 现状踢登录页。新增**游客模式**:未登录即可进入业务路由(数据源=本地库,衔接 feature C 的 seam);登录页增加「先不登录,离线使用」入口。分流对**所有用户**生效(M1 缓解:绑定用户离线至少不丢会话)。

AuthBloc 状态机扩展(如 `Guest`/`OfflineAuthenticated`)+ router 守卫改造(游客可达业务路由,绑定专属入口如云备份页守卫保留)。connectivity_plus 从死依赖转为实际网关检测。

## Stories

1. `AppStarted` 失败分流:NetworkFailure(有 token)→ 离线保留会话;AuthFailure → Unauthenticated(现状)
2. AuthBloc 状态扩展(Guest / Authenticated / Unauthenticated / 离线态)+ 游客进入业务路由
3. 登录页「离线使用」入口 + 首次启动引导(未绑定 → 游客态)
4. router 守卫重定义:游客可达路由 vs 绑定专属路由(云备份/绑定入口)
5. connectivity_plus 接入网关检测(在线/离线态可观察,供 seam 与 UI 使用)
6. bloc 测试:断网启动/无 token 启动/游客进入/离线保留会话四路径

## title

启动鉴权分流(NetworkFailure≠Unauthenticated)+ 游客模式路由放开

## keywords

auth, offline, guest mode, network failure, router guard, AppStarted, R6, M1
