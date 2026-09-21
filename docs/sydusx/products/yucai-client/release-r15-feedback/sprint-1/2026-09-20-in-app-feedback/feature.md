---
title: F41 in-app-feedback
keywords: [反馈, 意见反馈, feedback, mailto, 邮件, 侧栏, 设置, in-app-feedback]
---

# Feature — F41 应用内反馈入口(R15 sprint-1)

> 2026-09-20。既有:客户端无任何反馈通道(代码检索零命中);用户要求 app 内有明显入口可写反馈。
> brainstorm+grill 决策全录见 [spec.md](spec.md) Grill record(10 决策用户拍板)。

## Description

现状:用户有问题/建议只能线下找开发者,app 内无通道。目标:mailto 直跳通道——三入口(宽屏侧栏导航列表尾部整行「意见反馈」/窄屏底栏「反馈」项/设置页行)共用单一 FeedbackLauncher,点击唤起系统邮件客户端,预填收件人(dart-define 注入,源码零明文)+主题+诊断头(版本/平台/账户模式/主题 4 字段白名单,零财务数据);FEEDBACK_EMAIL 缺省或无邮件客户端时 SnackBar 降级(后者附剪贴板复制)。guest 可用,零 server/proto 改动。

## Stories

- [ ] S1: FeedbackLauncher 核心(mailto URI 构造[收件人/主题/诊断头白名单]+launchUrl+缺省/失败两降级;FEEDBACK_EMAIL 单点)
- [ ] S2: 三入口 UI+接线(宽屏侧栏整行/窄屏底栏项/设置页行,共用 S1)
- [ ] S3: 测试(launcher 单测:URI 构造/中文编码/白名单/缺省/失败复制;入口 widget 测:渲染/点击/提示)+ 回归门(flutter test+analyze+client-e2e)

## Keywords

`反馈` `意见反馈` `feedback` `mailto` `邮件` `侧栏` `in-app-feedback`
