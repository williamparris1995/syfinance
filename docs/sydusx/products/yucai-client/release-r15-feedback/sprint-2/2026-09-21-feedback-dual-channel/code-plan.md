# Code Plan — F42 反馈双通道

> 2026-09-21 execute 产出。spec/design 均用户确认(prototype v4 已定稿)。跨产品票:T1 server → T2 client 串行(pb 依赖)。

## Tasks

- [x] T1: server 侧 —— proto `feedback/v1` 新增(`make proto` go 生成 + `make gen-dart` client 生成;**sync.pbjson.dart F13 补丁重套+全量 pb diff 核验**)→ `internal/feedback` 四层+ent schema(全局无租户列)+auth 拦截器 allowlist 豁免+per-IP 限流(5/min 具名常量,零新依赖优先手写)+slog+wire_gen.go 手改 → 集成测 RED→GREEN(落库/校验拒绝/限流/匿名可达/其余 RPC 认证回归)→ `go test ./...` 全绿。
- [x] T2: client 侧 —— `FeedbackFormDialog`(照 prototype v4)+`FeedbackSubmitService`(路由/超时/降级)+`feedback_launcher.dart` 扩展(mailto 带表单字段+>1800 截断+剪贴板)+三入口改唤表单 → 单测(路由/失败重试不丢/限流变体/截断边界/表单校验)+widget 测(表单渲染/状态/入口唤表单)RED→GREEN → flutter test 全绿+analyze+`make client-e2e`。
- [x] T3: 契约与运维面 —— yucai-api 契约 bump(新 vN+CURRENT)+feature 目录 `feedback-ops.md`(SQL 查询现成语句+限流阈值/调整点+端点豁免说明)。

依赖:T1 → T2(pb 文件);T3 并入 T1/T2 收尾。派发:两份 task-brief 串行同实现者,两轴评审在 T2 后统一跑(代码面整体)。

## 验收门

`go test ./...` 全绿 + `flutter test` 全绿 + analyze 基线 + `make client-e2e`(proto 变更过 server 门)。
