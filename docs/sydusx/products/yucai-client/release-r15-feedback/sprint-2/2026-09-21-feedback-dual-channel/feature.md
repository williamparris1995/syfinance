---
title: F42 feedback-dual-channel
keywords: [反馈, 意见反馈, feedback, server 上传, 匿名端点, 双通道, 表单, mailto, feedback-dual-channel]
---

# Feature — F42 反馈双通道:统一表单+在线 server 上传/离线邮件(R15 sprint-2)

> 2026-09-21。既有:F41 mailto 直跳通道(三入口+诊断头白名单+两降级)已上线;
> 用户提出「在线走 server 上传/离线走 email」。grill 四决策拍板见 spec.md Grill record。

## Description

现状:F41 反馈只能唤起邮件客户端,离线/无邮件客户端体验断层,反馈无结构化沉淀。目标:①统一反馈表单(类型[问题/建议/其他]+正文限长+可选联系方式+只读诊断头,三入口共用);②提交时路由:在线(绑定或 guest,匿名端点)→ server `SubmitFeedback` 直传落库;离线 → mailto(表单内容并入正文,超限截断+剪贴板兜底);③失败降级:上传失败 SnackBar+「重试/改用邮件」双动作,表单内容不丢;④server 新增 feedback 模块(proto feedback/v1 匿名端点+ent feedback 表+DDD 四层,照 holding/debt 范式),落库+English 结构化日志,查看=SQL(部署文档给出查询);⑤防滥用最轻机制(per-IP 限流+body 尺寸上限,design 定);⑥诊断头白名单 4 字段延续(隐私红线,server 存储同样仅此)。

## Stories

- [ ] S1: server feedback 模块(proto feedback/v1 匿名 SubmitFeedback+ent 表+四层+限流+日志+集成测)
- [ ] S2: client 表单(类型/正文限长/联系方式/只读诊断头;三入口改唤表单)
- [ ] S3: 提交路由与降级(在线→gRPC 上传;离线/失败→mailto 带正文[截断+剪贴板]/重试;内容不丢)
- [ ] S4: 契约与工具链(yucai-api bump vN+CURRENT;make gen-dart regen;sync.pbjson.dart F13 补丁重套核验)
- [ ] S5: 测试与门(server 集成测 RED→GREEN+client 单测/widget 测+回归:go 全绿+flutter 全绿+analyze+client-e2e)

## Keywords

`反馈` `意见反馈` `feedback` `server 上传` `匿名端点` `双通道` `表单` `mailto` `feedback-dual-channel`
