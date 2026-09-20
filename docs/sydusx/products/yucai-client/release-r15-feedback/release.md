# Release R15 — 应用内反馈(in-app-feedback)

> /sydusx-portfolio 2026-09-20 立项。product checkpoint:重读 [vision.md](../vision.md),Product Goal(可分发的商业级个人专业理财客户端、19 模块行业级)ongoing;用户之声通道是商业级 app 标配,属体验打磨。
> 起因:用户指出缺少反馈模块,要求 app 内有明显入口可写反馈(brainstorm 2026-09-20,两项决策用户拍板:通道=邮件预填;入口=设置页行+侧栏底部双入口)。

## Release Goal

用户在 app 内任一页面都能一键进入反馈入口,唤起系统邮件客户端并预填主题与诊断头(app 版本/平台),反馈直达开发者;零 server/proto 改动,guest 未绑服务器同样可用。

## Decisions(用户拍板 2026-09-20)

- **通道 = 邮件预填(mailto)**:否决 GitHub Issues 跳转(用户群未必玩 GitHub、离开 app 体验割裂)与 server gRPC 收集(proto regen 工具链风险 + guest 不可用 + 需另做查看后台,工程量 5-10 倍)。后续如升级 server 收集,本通道不冲突。
- **入口 = 设置页行 + 侧栏底部双入口**:侧栏底部常驻(任一页面一键可达,最明显)+ 设置页一行(习惯性查找位置),两处复用同一跳转。

## Sprint roster

- [ ] [sprint-1](sprint-1/sprint.md) — F41 应用内反馈入口(邮件预填通道 + 双入口)

## Done criteria

1. 设置页与侧栏底部均有可见反馈入口,点击唤起系统邮件客户端(mailto 预填主题+正文诊断头),guest 模式同样可用。
2. 诊断头仅含技术元数据(app 版本/平台等),**不含任何财务数据**(隐私红线)。
3. 收件邮箱等常量单点收敛(一处定义,双入口复用,无硬编码散落)。
4. `flutter test` 全绿 + analyze 基线 + `make client-e2e` 门(纯客户端票,不动 proto,免 go 门)。

## status: pending
