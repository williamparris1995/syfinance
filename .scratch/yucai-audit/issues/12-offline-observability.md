# 12 · offline 与可观测(纯在线 + health check + 崩溃上报 + 列表虚拟化 + release)

Type: grilling
Status: open
Blocked by: —

## Question

"伪离线":Drift/connectivity_plus 是死依赖,纯 gRPC 在线,server 宕机 → 用户被踢登录页无提示(详见 `findings.md` U3/U6/U7/U8/U9/U10/U12/U14):

- **[U3 P0]** 纯在线:`AppStarted→GetProfile` 失败 → `Unauthenticated` → `/login`;写失败即丢失无 outbox;home LAN server 重启全家设备同时被踢,且 OIDC 登录也走 server → 双重不可用。
- **[U6 P1]** Windows release 卡 accessibility_bridge 循环,全家只能 debug JIT(release 包产不出)。
- **[U7 P1]** 列表无虚拟化(`transactions_page:1532` 等 eager ListView),大数据卡顿;无 server 分页。
- **[U8 P1]** 无 gRPC health check + compose 无 healthcheck,server 挂死不可观测。
- **[U9 P1]** 客户端零崩溃上报,家人遇错只能截图口述。
- **[U10 P1]** AuthRetryCaller 只捕 unauthenticated,瞬态错误直抛无重试无进度。
- **[U12 P1]** 客户端版本硬编码 `'1.0.0'`,server 只 log 不 enforce。
- **[U14 P2]** 无 `FlutterError.onError` 兜底 + 无首启 wizard。

**决策点:**
1. offline 策略:接受"server 死 = 全家不可用"现状(标尺私域)/ 最小补(读路径 Drift 缓存 + 写 outbox)/ 真 offline-first?(深度关联 16)
2. server 宕机 UX:加 offline banner + retry + "无法连接"明确提示(而非踢登录页)?
3. release 卡点:升 Flutter stable 复测 / `--disable-accessibility` 绕 / 接受 debug-only 分发?
4. 可观测性:注册 `grpc_health_v1` + compose healthcheck + 崩溃上报(Sentry/GlitchTip/本地环形日志)?
5. 列表虚拟化 + server cursor 分页;AuthRetryCaller 扩为通用 RetryPolicy;`package_info_plus` 真版本号?
