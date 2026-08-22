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
