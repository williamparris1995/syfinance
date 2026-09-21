# Task Brief — F42-T1 server 侧:TDD(proto+feedback 模块+匿名端点+限流)

## 既有设施(全部已存在,复用第一)

- **proto 生成**:`make proto`(Go+Dart)/ `make gen-dart`(yucai/proto/gen-dart.sh,protoc+WKT 已就位);proto 源在 `yucai/proto/`;**sync.pbjson.dart 尾部 F13 手工补丁 regen 后必须重套**(AGENTS.md 明示)。
- **模块范式**:`internal/backup/`(hexagonal:domain/application/adapter/driven/repository/adapter/driving/grpc/ent/schema/scheduler)——照抄结构。
- **拦截链**:`wire/providers.go:1029` `ChainUnaryInterceptor(UnaryLogging, AuthInterceptor, RestoreFreeze, RequireAdmin)`;AuthInterceptor 在 middleware 包(从 providers.go import 找到定义),**auth RPC 自身免认证 → 既有匿名放行机制已存在**(侦察其形态:方法 allowlist/前缀判断),把 feedback 方法加入同机制。
- **ent**:每模块自带 `ent/schema` + `internal/ent/generate.go`(`go generate`);migrate 自动。
- **日志**:stdlib `log/slog`,English 结构化(backup/application/service.go 先例:`slog.Info("encrypted backup created", "backup_id", ...)` )。
- **集成测形态**:`tests/authz_matrix_integration_test.go` 等(tests/ 目录);backup 集成测参考。
- **限流**:`golang.org/x/time/rate` 不在 go.mod → **手写 per-IP token bucket(~30 行,map+mutex+时间窗),零新依赖**。
- **wire**:`wire_gen.go` 手改(工具链坏,不跑 CLI);providers.go 是接线点。

## 任务

1. **proto 新增** `yucai/proto/feedback/v1/feedback.proto`(照既有 proto 文件头风格):
   - `enum FeedbackType { FEEDBACK_TYPE_UNSPECIFIED=0; ISSUE=1; IDEA=2; OTHER=3; }`
   - `message FeedbackDiagnostics { string app_version; string platform; string account_mode; string theme_mode; }`
   - `message SubmitFeedbackRequest { FeedbackType type; string body; string contact; FeedbackDiagnostics diagnostics; }`
   - `message SubmitFeedbackResponse { int64 id; }`
   - `service FeedbackService { rpc SubmitFeedback(SubmitFeedbackRequest) returns (SubmitFeedbackResponse); }`
   - 生成:`make proto`;**核验**:client 侧 `make gen-dart` 后 sync.pbjson.dart F13 补丁重套;全量 pb diff —— 预期仅新增 feedback 文件+sync.pbjson.dart 尾部,其余零漂移(异常即停并报告)。
2. **ent schema** `internal/feedback/ent/schema/feedback.go`:`Feedback{id(auto), type(string 8), body(string), contact(string default ""), app_version/platform/account_mode/theme_mode(string), created_at(time, default now)}`;全局表**无 tenant_id**;`go generate` 后确认生成物落位(该模块 ent 目录形态照 backup)。
3. **domain**:`SubmitFeedback(cmd)` 校验:type ∈ {issue,idea,other}/body 1..1000 rune 非空/contact ≤100 rune;返回实体。错误哨兵(InvalidArgument 语义)。
4. **application service**:校验→落库→`slog.Info("feedback submitted", "id", id, "type", t)`;port 接口(repository 最小:Create)。
5. **adapter/driven/repository**:ent 实现 Create。
6. **adapter/driving/grpc**:handler 映射(InvalidArgument/RESOURCE_EXHAUSTED);**注册进 server**(侦察既有 service 注册点,照 backup 注册)。
7. **匿名放行**:AuthInterceptor 既有放行机制加 `/feedback.v1.FeedbackService/SubmitFeedback`(唯一成员/或并入既有匿名集合)。
8. **限流**:`FeedbackRateLimiter`(per-IP=grpc peer ip;5 次/分钟,具名常量 `feedbackRatePerMin=5`+窗口 1min;map[string]*bucket+mutex,惰性清理可免);超限返回 RESOURCE_EXHAUSTED(English 错误信息 "feedback rate limit exceeded, retry later")。
9. **DI**:`wire_gen.go` 手改+providers.go 加 provider(照 backup 接线;注意依赖:ent client/sqltx 既有 port 模式)。

## TDD(先 RED 后 GREEN)

`server/tests/feedback_integration_test.go`(或照 tests/ 惯例位置;RED=服务未注册编译失败/调用 NotFound 亦可作 RED 证据):
1. 提交成功落库:type=issue/body 中等/diagnostics 4 字段 → response.id>0;DB 查行字段齐(**无租户列**)。
2. 校验拒绝:type=UNSPECIFIED→InvalidArgument;body 空→InvalidArgument;body 1001 rune→InvalidArgument;contact 101 rune→InvalidArgument。
3. 限流:同 IP 连续 6 次(前 5 过)→ 第 6 次 RESOURCE_EXHAUSTED;换 IP 不受影响。
4. **匿名可达**:不带任何认证 metadata 直调 SubmitFeedback → 成功(**其余任一业务 RPC 不带凭证仍 Unauthenticated** —— 放行面回归,选一个既有 RPC 断言)。

GREEN 后:`go test ./...` 全绿(67+ 包基线)。

## 约束

**禁止 git stash/checkout/restore/commit**;只动:proto 新文件+生成物+internal/feedback/**+middleware 放行处+wire/providers.go+wire_gen.go+tests/feedback_*;English 注释与日志;错误串 English;零新依赖(限流手写)。工具链:server 目录下 go 命令;`make proto`/`make gen-dart` 在 yucai/ 下。
工作目录:`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r15-f42`(worktree,分支 feature/r15-f42-feedback-dual-channel)。
完成后报告:改动文件清单、pb diff 核验结论(仅新增+sync 尾部?)、F13 补丁重套证据、RED→GREEN 证据、go test 数字、匿名放行机制形态说明、BLOCKED 即停。
