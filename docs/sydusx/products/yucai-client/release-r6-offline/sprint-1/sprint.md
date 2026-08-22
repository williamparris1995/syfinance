# Sprint 1 — 本地模式地基

> Sprint Goal + feature roster。`/sydusx-portfolio` sprint planning(2026-08-20)。

## Sprint Goal

打通 offline-first 三块地基:**drift 本地库**(全实体 schema)+ **启动鉴权分流**(NetworkFailure≠Unauthenticated + 游客模式)+ **repository 双源 seam**(以 account 模块试点定型范式)。unblock sprint-2 全模块复制。

## Feature roster(依赖排序)

- [x] **feature A** 2026-08-20-drift-local-db — drift 本地库落地(全业务实体 schema + DI 注册 + proto DTO 契约对齐,零 server 改动)✅ done(merged `fa2203f`,2026-08-21;24 表+10 DAO,20 测试,DAO 逻辑覆盖 88.2%)
- [ ] **feature B** 2026-08-20-auth-offline-fork — AppStarted 失败分流 + 游客模式(路由守卫放开,离线不踢登录页,对所有用户生效) `claimed: zcode-main 2026-08-22`
- [ ] **feature C** 2026-08-20-dual-source-seam — repository 双源 seam + account 模块试点(未绑定读写本地 / 已绑定走远端;定型 G2 seam 范式供 sprint-2 复制)(依赖 A,B)

**defer**:绑定后离线续写(ticket 16);非空账号合并(defer)。

## status: pending
