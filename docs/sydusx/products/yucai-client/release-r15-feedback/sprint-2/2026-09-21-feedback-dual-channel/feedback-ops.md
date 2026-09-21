# Feedback Ops — F42 双通道反馈运维面

> 面向:需要查反馈数据 / 调限流 / 审计匿名放行面的运维与后续任务。
> 代码事实源:server `internal/feedback/**`、`pkg/middleware/auth.go`;client `lib/core/feedback/**`。

## 1. 数据面:feedbacks 表查询

- 表:`feedbacks`(**全局表,无 tenant_id** —— 匿名提交按设计无租户归属;ent schema 见
  `yucai/server/internal/feedback/ent/schema/feedback.go`)。
- 字段:`id`(自增)/`type`(issue|idea|other,≤8 字符)/`body`/`contact`(可空)/
  `app_version`/`platform`/`account_mode`/`theme_mode`/`created_at`。

```sql
-- 最新 50 条
SELECT id, type, left(body, 200) AS body_head, contact,
       app_version, platform, account_mode, theme_mode, created_at
FROM feedbacks
ORDER BY created_at DESC
LIMIT 50;

-- 按类型过滤(示例:仅问题)
SELECT id, body, contact, app_version, platform, created_at
FROM feedbacks
WHERE type = 'issue'
ORDER BY created_at DESC
LIMIT 100;

-- 按版本聚合定位某版本问题密度
SELECT app_version, count(*) AS total,
       count(*) FILTER (WHERE type = 'issue') AS issues
FROM feedbacks
GROUP BY app_version
ORDER BY total DESC;
```

(Windows 桌面形态下若走本地 sqlite,同语句可直接用;PostgreSQL 生产同构。)

## 2. 限流:常量位置与调整

- 位置:`yucai/server/internal/feedback/adapter/driving/grpc/ratelimit.go`
- 常量:`feedbackRatePerMin = 5`(每源 IP 每分钟;token bucket 容量=5,窗口
  `feedbackWindow = time.Minute` 连续补充);map+mutex 手写,**零外部依赖**。
- 调整:改 `feedbackRatePerMin` / `feedbackWindow` 后重编重启即生效(无配置项,
  改代码常量是唯一入口;bucket 惰性建、无清理,条目按源 IP 数量有界)。
- 超限表现:client 收 `RESOURCE_EXHAUSTED`,表单变体提示「提交过于频繁,请稍后再试」
  + 重试/改用邮件双动作。

## 3. 匿名端点豁免面

- 机制:`yucai/server/pkg/middleware/auth.go` 的包级
  `anonymousMethods = map[string]struct{}{...}`(**exact-match,当前唯一成员**
  `/yucai.feedback.v1.FeedbackService/SubmitFeedback`),`AuthInterceptor` 入口查表放行。
- 语义:该 RPC 不带 authorization 也能达 handler(client 侧 `AuthInterceptor`
  对无 token 本就放行 —— guest 无 token 时不附 header;server 放行面靠这张表)。
- 审计要点:**新增匿名 RPC 必须同时具备 handler 侧自限流**(先例:SubmitFeedback
  在 handler 内先过 rate limiter 再校验);登录态调用同样走限流(per-IP)。
- 回归钉子:server 集成测 `tests/feedback_integration_test.go`
  `TestFeedback_AnonymousReachability_And_AuthSurfaceRegression`(其余业务 RPC
  无凭证仍 Unauthenticated)。

## 4. client 侧通道行为速查

- 路由:`lib/core/feedback/feedback_submit_service.dart` —— connectivity 快照
  online→gRPC(10s deadline;ResourceExhausted→rateLimited;其余→failed);
  offline→mailto(F41 降级链);`--dart-define=FEEDBACK_EMAIL` 缺省+离线→emailMissing。
- mailto 超限:编码后 >1800 字符截断正文尾部 +「(过长已截断,完整内容已复制)」
  + 剪贴板全文(`feedback_launcher.dart` `feedbackMailtoMaxEncodedLength`)。
- 运维入口:FEEDBACK_EMAIL 经 release.yml 的 dart-define 注入,收件人变更在
  发布配置改,不在源码。
