# Prototype v9 — 财务报告+AI 分析师(两页增量)

> tier: high-fi(design)· path: OD 管线增量(项目 `yucai-fin-report-r16-9239`,run `c1b24569`,2026-09-28,~6min)。
> 基于 v8 两页原地增量(financial-report 5 处+settings 4 处纯插入,零删除;P0 6/6 内层自检+我方浏览器复核)。零新令牌;错误/加载态经 `?llm=` 参数;免责对话框 `?dlg=llm`/浮动开关/启用开关三触发。

## 增量内容(F46 spec FR-1/FR-4 的 UI 事实源)

- **financial-report.html**:page-head「AI 解读」ghost 次按钮;ch-7 尾「分析师解读」小节——done 态(三段纯文本:总体评价/主要风险/可执行建议+「由 glm-4.6 生成」chip)+loading/error(`?llm=` 切换,error 含[重试]);**免责脚注恒显**(「AI 基于脱敏汇总数据生成…不构成投资建议;数字以报告为准」)+「重新解读」;健康态随 findings 隐藏。
- **settings.html**:「AI 分析师」卡六行(启用开关[未启用时配置行半透明禁用]/服务商 pills 智谱·OpenAI·DeepSync·自定义/API Key 圆点输入+「仅存本机安全存储」/模型名 placeholder glm-4.6/城市规模 segmented 一线·新一线·二三线/订阅名明文开关);免责对话框(四行文案+[取消][我已知悉并启用],取消回弹开关)。

## 核验记录(2026-09-28)

http.server 8125+IAB:报告页(生成后 AI 按钮/小节/chip/三段/脚注/重新解读/旧 fixture 全过;首验点击未注册属 IAB 怪癖,页面内直调复核过);设置页(卡六行/Key 描述/档位/对话框文案逐字/旧设置项在位);两页 200+SSOT theme 200。

## CURRENT

待用户确认后指 v9(F46 实现以 v9 为准;v8 保留为 F45 存档)。
