# Task Brief T3 — 第七章节+摘要卡(F44 R16 sprint-1)

**工作目录**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r16-f44`(分支 feature/r16-f44;`yucai/client/`)。**流程**:先加载 sydusx-tdd。前置:T2(5a69a53a)已落——ReportDocument.mda 可选字段+MdaSection{findings/counts}。

## UI 事实源(必读)

**prototype v8**:`docs/sydusx/products/yucai-client/prototype/v8/ui/financial-report.html`(诊断摘要双态卡+第七章节形态;生成后可见,F44 增量部分)。F43 既有 presentation 组件(`lib/report/presentation/`)复用惯例。

## 任务

1. **`lib/report/presentation/widgets/mda_section.dart`** — 第七章节:章节头(标题「诊断与建议」+三计数 chip:0 风险/N 提示/M 关注);按 severity 分组列表(风险组空不渲染组头);每条 Finding 卡=严重度图标+结论+建议行+(actionLink)「前往订阅中心 →」跳转按钮(context.push);零发现健康态=居中健康卡(列通过项摘要:储蓄率/资产负债率/可支撑月数,从 doc 取数)。挂入 `financial_report_page.dart` 的 `_chapters` 链(第七章,锚点链变体 B 自动纳入)。
2. **`lib/report/presentation/widgets/mda_summary_card.dart`** — 总览摘要卡两态:有发现(任何 risk/warn/info>0)=计数头+top-3(按 findings 序)+「查看全部」锚滚到第七章节;零发现=单行健康徽章。插总览章节(sum-strip 后、附注卡前)。
3. **测试**:`mda_section_test.dart`(分组渲染/零发现健康态/逐字文案/跳转链/actionLink 按钮)+`mda_summary_card_test.dart`(两态/top-3 截断/锚点)+页面测试扩(第七章节入锚点链/摘要卡两态随 doc.mda)。mda=null(期外异常)时章节与摘要卡均不渲染。

## 硬约束

presentation→domain;零裸色(risk→context.yucai 既有警示红/warn→warn 黄/info→中性,与原型 v8 映射一致,NFR-3);中文文案;不碰 domain/data(T2 已定);金额格式化走 chart_helpers 既有(fmtCents 等,mda 结论文案已含格式化数字,widget 直接展示 Finding.conclusion/advice 字符串,不重算)。

## 完成门

`flutter test test/report` 全绿+全量绿+analyze 446 持平。commit `feat(report): T3 诊断与建议章节+总览摘要卡(变体B锚点链第七章,按 prototype v8)`。回报:文件/测试数/commit/遗留。
