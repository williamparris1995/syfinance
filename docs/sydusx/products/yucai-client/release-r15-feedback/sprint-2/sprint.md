# Sprint 2 — R15 反馈双通道(F42)

> /sydusx 流程(2026-09-21)。F41 mailto 通道上线后用户提出双通道路由:在线直传 server,离线走 email;
> 推翻原 brainstorm「否决 server 收集」的部分理由(①proto 工具链风险已不成立——protoc 就位+F33 先例;②guest 不可用→匿名端点解决;③查看后台→落库+日志+SQL 查看接受)。

## Sprint Goal

反馈统一表单 + 提交时智能路由:在线(绑定或 guest)→ server 匿名端点直传落库;离线 → mailto(表单内容并入正文);失败降级链「重试/改用邮件」不丢内容。

## Feature roster

- [ ] **feature F42** feedback-dual-channel — 反馈双通道:统一表单+在线 server 上传/离线邮件(server feedback 模块+ent 落库+匿名 SubmitFeedback+client 表单与路由) `claimed: zcode-main 2026-09-21`

## status: pending
