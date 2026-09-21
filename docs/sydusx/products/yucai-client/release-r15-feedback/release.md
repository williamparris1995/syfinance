# Release R15 — 应用内反馈(in-app-feedback)

> /sydusx-portfolio 2026-09-20 立项。product checkpoint:重读 [vision.md](../vision.md),Product Goal(可分发的商业级个人专业理财客户端、19 模块行业级)ongoing;用户之声通道是商业级 app 标配,属体验打磨。
> 起因:用户指出缺少反馈模块,要求 app 内有明显入口可写反馈(brainstorm 2026-09-20,两项决策用户拍板:通道=邮件预填;入口=设置页行+侧栏底部双入口)。

## Release Goal

用户在 app 内任一页面都能一键进入反馈入口,唤起系统邮件客户端并预填主题与诊断头(app 版本/平台),反馈直达开发者;零 server/proto 改动,guest 未绑服务器同样可用。

## Decisions(用户拍板 2026-09-20)

- **通道 = 邮件预填(mailto)**:否决 GitHub Issues 跳转(用户群未必玩 GitHub、离开 app 体验割裂)与 server gRPC 收集(proto regen 工具链风险 + guest 不可用 + 需另做查看后台,工程量 5-10 倍)。后续如升级 server 收集,本通道不冲突。
- **入口 = 设置页行 + 侧栏底部双入口**:侧栏底部常驻(任一页面一键可达,最明显)+ 设置页一行(习惯性查找位置),两处复用同一跳转。

## Sprint roster

- [x] [sprint-1](sprint-1/sprint.md) — F41 应用内反馈入口(邮件预填通道 + 双入口) ✅(2026-09-20 收官,ff 合并 `a040c663`)
- [x] [sprint-2](sprint-2/sprint.md) — F42 反馈双通道(统一表单+在线 server 匿名直传/离线邮件) ✅(2026-09-21 收官,ff 合并 `1d9673ce`)

## Done criteria(sprint-1)

1. 设置页与侧栏底部均有可见反馈入口,点击唤起系统邮件客户端(mailto 预填主题+正文诊断头),guest 模式同样可用。✅(FR-2 按用户 fix-2 裁决微调:侧栏入口=导航列表尾部整行,720p 下保主导航全部可见;验收证据 e2e)
2. 诊断头仅含技术元数据(app 版本/平台等),**不含任何财务数据**(隐私红线)。✅(白名单测试+禁词表钉死)
3. 收件邮箱等常量单点收敛(一处定义,双入口复用,无硬编码散落)。✅(FEEDBACK_EMAIL=String.fromEnvironment 全仓单点,release.yml Secret 注入)
4. `flutter test` 全绿 + analyze 基线 + `make client-e2e` 门(纯客户端票,不动 proto,免 go 门)。✅(1907 全绿/analyze 437≤439/client-e2e 5 套件 21 测全过)

## Done criteria(sprint-2 追加)

1. 统一反馈表单(类型/正文限长/联系方式/只读诊断头),三入口共用,提交时按在线状态路由。✅(原型 v4 契约;dialog 7 测)
2. 在线(绑定或 guest)→ server 匿名 SubmitFeedback 直传落库;离线 → mailto(表单内容并入正文,超限截断+剪贴板)。✅(集成测 5 件+service 10 测)
3. 失败降级链:重试/改用邮件,表单内容不丢。✅(重试原样重发+forceMail 不触 gRPC 钉测)
4. 防滥用:per-IP 限流 5/min+域校验;隐私白名单延续。✅(跨 IP 限流测+白名单构造排他)
5. 全门:go 全绿+flutter 全绿+analyze+client-e2e(proto 变更过 server 门)。✅(67 包/1935/436/14 套件)

## status: done(R15 两 sprint 收官=release 功能 done;**发版待用户**:①server 先部署[F42 新端点+feedback 表迁移自动] ②GitHub Secrets 配置 FEEDBACK_EMAIL ③tag 推送走 release.yml 流水线 —— 离线邮件通道在 Secret 配置前走「未配置」降级,在线通道不受影响)
