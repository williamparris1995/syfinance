# 11 · 部署通路(Dockerfile + server URL + OIDC cache + 自动更新)

Type: grilling
Status: open
Blocked by: —

## Question

四大 P0 形成连环:家人照文档部署直接失败、即使成功客户端连不上、server 掉线全家不可用、版本漂移(详见 `findings.md` U1/U2/U4/U5):

- **[U1 P0]** `docker-compose` 引用不存在的 `server/Dockerfile`(`deploy/docker-compose.yml:5`),家人照 README 跑直接挂。
- **[U2 P0]** server 地址 = `--dart-define` 编译期常量(`localhost:9090` 兜底),换服务器必须重新 `flutter build`(`settings_page` 无 server URL 输入)。
- **[U4 P0]** OIDC discovery 是 server 启动硬依赖:Google well-known 不可达 → `InitializeApp` 失败 → `os.Exit(1)`,无 cache 无重试,air-gapped 家庭 LAN 永远启不来。
- **[U5 P0]** 无自动更新机制(`in_app_update`/`sparkle`/`package_info_plus` 均无),客户端靠手动重装,家人设备一多即版本漂移。

**决策点:**
1. 补 `server/Dockerfile`(多阶段 Go build → distroless)/ 改 compose 直拉预编译镜像?
2. server 地址运行时配置:首启 onboarding 输入(持久化 secure storage)/ 发家族专用打包脚本?
3. OIDC discovery JSON 本地 cache(boot 优先读 cache,后台异步刷新)/ fallback IdP?
4. 自动更新:Windows Sparkle / 自检版本号 + 下载链接 / Android Play/Sideload / 接受手动重装?
5. (关联 U12)client/server 版本协商:server enforce 最低客户端版本?
