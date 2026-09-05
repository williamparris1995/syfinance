# Feature — F14 生产疑点修复批(R8 sprint-4)

> 2026-09-03 用户"继续"推进 defer 区清零。

## Description

修复 F6/多轮 review 累积的生产疑点 #1-#4 + 测试债收口:①订阅管理路由被 `/accounts/:id` 捕获(真 bug:app_shell 导航指向 `/accounts/templates`,router 无此静态路由);②模板 endDate=null 兜底截到今天(订阅永续场景失效);③④交易/持仓列表表单提交返回后不回拉;⑤goPage helper 11 文件逐字重复迁 link_support;⑥既有三套件 tearDownAll 迁 deleteTestDb(Windows close 后删)。

## Stories

- [ ] S1: 订阅管理路由修复(router 静态子路由,架构约定"静态在 /:id 前")
- [ ] S2: 模板 endDate=null 永续语义(调度/record 不截断;兼容既有存储)
- [ ] S3: 列表回拉(交易顶栏创建/持仓 TradeSheet pop 后重载)
- [ ] S4: 测试债(goPage 迁 link_support+三套件 tearDown 迁 deleteTestDb)
- [ ] S5: 回归门(e2e 双门+单测+UI 测试适配)

## title

F14 生产疑点修复批(路由/endDate/回拉/测试债)

## keywords

defect-batch, subscription-route, enddate-open-ended, list-refresh, gopage, test-debt, F14
