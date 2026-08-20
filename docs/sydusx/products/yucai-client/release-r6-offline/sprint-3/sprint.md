# Sprint 3 — 绑定上传 + 镜像 + e2e 验收

> Sprint Goal + feature roster。`/sydusx-portfolio` sprint planning(2026-08-20)。

## Sprint Goal

打通**绑定链路**:游客登录 → 空账号 guard → 本地快照单向上传(RestoreBackup 路径)→ 回切在线;绑定后镜像写穿透 + 登出回本地(M2);最终以三条成功判据 e2e 收口整个 release。

## Feature roster(依赖排序)

- [ ] **feature G** 2026-08-20-bind-upload — 绑定上传:OIDC 登录 → 空账号预检 guard(M3)→ 本地快照转 backup 格式经 RestoreBackup 单向上传 → 回切 server 权威在线(零 server 改动)(依赖 sprint-2)
- [ ] **feature H** 2026-08-20-bound-mirror-logout — 绑定后镜像写穿透(在线写成功同步写 drift)+ 登出=回本地模式用最后镜像(M2)(依赖 G)
- [ ] **feature I** 2026-08-20-offline-e2e-acceptance — 三条成功判据 e2e 验收(断网安装记账 / 登录上云 / 不绑定永远本地)(依赖 G,H)

**defer**:绑定后离线续写(ticket 16);非空账号合并。

## status: pending
