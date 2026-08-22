# Code Plan — feature B 启动鉴权分流 + 游客模式

> 消费 spec.md + design.md(均 confirmed)。inline 模式(改动集中 auth 链路 + router + 一处 settings + 新 gateway,无跨子系统扩散)。

## Tasks

- [x] **T1 域层端口+用例**:AuthRepository +`hasStoredCredentials()`;新增 HasStoredCredentialsUseCase;AuthRepositoryImpl 实现(经 TokenStorage)。
- [x] **T2 状态机**:auth_state +Guest +OfflineAuthenticated;auth_event +SkipLoginRequested;auth_bloc 四改(AppStarted 预检三分支/Skip→Guest/Logout→Guest/TokenRefreshFailed→Guest)。
- [x] **T3 守卫反转**:router redirect 重写(hasSession 两规则 + bindOnlyPrefixes 机制,初始空)。
- [x] **T4 入口 UI**:login_page +「先不登录,离线使用」(Skip 事件 + go /home);settings_page Guest 态「登录账号」入口(push /login)。
- [x] **T5 ConnectivityGateway**:core/connectivity 新服务(online distinct 流 + current)+ injection 注册。
- [x] **T6 测试**:auth_bloc_test 表驱动 8 转移 + 更新既有期望;router_test 新守卫规则;login_page_test skip 按钮;connectivity_gateway_test fake 流。全套基线内 + analyze 0 新增 → commit。

## 约定声明

- 既有 auth/login/router 测试期望更新随 T2/T3/T4 同步(登出→Guest 等为 spec 有意变更)。
- 注释英文,仅记约束。

## 执行记录(2026-08-22)

- 全套 +1015 -4(恰为基线 4:account_detail 1 + receivable_detail 2 + receivables_page 1,零新增);analyze 398 = main 基线(经 per-file+rule 去行号 diff 归因,修复唯一真新增 1 条 prefer_const)。
- 既有测试同步:auth_bloc_test 重写(4 参构造+8 转移)/router_test 守卫 5 用例新语义/home_page_test·app_shell_test 构造器补参/settings_page_test harness 补 AuthBloc stub + Guest 卡片用例/login_page_test 换 GoRouter harness + skip 用例。

## Review 修复轮(2026-08-22,首轮 reject:2 Critical)

- **C1 FR-1②**:Unauthenticated(坏会话)不再重定向 /login,用户会话内失去登录路径 → redirect 补第三规则 `auth is Unauthenticated && !goingToAuth → /login`;router_test 断言翻回 + Guest(漫游)与 Unauthenticated(登录墙)行为分叉钉死。
- **C2 FR-2②**:design「现无独立绑定路由」前提失实——/settings/backup(+/auto)是 main 既有服务端备份页 → 入 kDefaultBindOnlyPrefixes;新增真实路由守卫测试 + 保留注入机制测试。
- **Minor**:gateway 补 initial check(checkConnectivity 注入 seam,FR-5「含初始态」补全)/auth_retry 注释漂移修正/login_page_test 去重。
- 修复后:全套 +1017 -4(基线 4,零新增),analyze 398 = main 基线。

## Review + Test(2026-08-22,pass)

- 首轮 review reject(2 Critical:FR-1② Unauthenticated 失登录路径 / FR-2② /settings/backup 未守卫)→ 修复轮 → 复审 **pass**(修复验证 + 三规则无冲突,2 个无关紧要残留已随手清)。
- Test 裁决:**pass** — 全套 +1017 -4(=基线 4,零新增);analyze 398 = main 基线;requirement coverage:FR-1 三场景/FR-2 两场景/FR-3 双向/FR-4 登出+刷新失败/FR-5 网关(含初始态)/NFR-1 基线实测/NFR-2 diff 零 server,均有测试或 diff 证据。
