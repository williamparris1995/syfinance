# Task Brief T5 — bloc+报告页+路由(F43 R16 sprint-1)

**工作目录(必须在此)**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r16-f43`(分支 feature/r16-f43;`yucai/client/`)。

**流程**:先调 Skill 工具加载 `sydusx-tdd` 并遵循(若 ambiguous 报错,直读 `C:/Users/BuHiYo-001/.agents/skills/sydusx-tdd/SKILL.md`)。前置:T4 汇编服务(453523be,`lib/report/domain/report_assembly_service.dart`:generate(period,{onPhase})→ReportDocument,ReportPhase 四阶段)。

## UI 事实源(必读)

- **原型 v7**:`docs/sydusx/products/yucai-client/prototype/v7/ui/financial-report.html`(六章节结构/期选择控件形态/进度四阶段/附注两卡/**章节导航=变体 B 右缘圆点+悬停标签**/预算条与绩效卡形态;fixture 数字仅展示样例,实现读真实 ReportDocument)。
- design-v2 令牌用法:参考既有页面 `lib/report/presentation/pages/report_page.dart` 与 `lib/report/presentation/widgets/`(fl_chart 组件与 chart_helpers 复用惯例、context.yucai 语义色)。
- bloc 惯例:找两个既有 flutter_bloc 页面(如 holding/goal 模块)照抄模式(bloc+getIt+build_runner)。

## 任务

1. **`lib/report/presentation/financial_report_bloc.dart`** — Event:GenerateRequested(ReportPeriod)/Retry;State:Initial/Loading(ReportPhase phase, ReportPeriod period)/Loaded(ReportDocument)/Error(String message, ReportPeriod period)。Loading 态需支持 >300ms 才显示进度的判定(在页面侧或 bloc 计时,选简单者并注释);Error→Retry 重新生成同报告期(FR-8 scenario 3)。bloc_test 全状态迁移。
2. **`lib/report/presentation/pages/financial_report_page.dart`** + widgets(`lib/report/presentation/widgets/`):
   - 页头:月/年 segmented 切换+上一期/下一期+期显示(ReportPeriod.label)+「生成报告」主按钮;顶栏面包屑「报表分析 / 财务报告」。
   - 进度区:四阶段步进(读取账本/回放余额/汇编章节/计算绩效),当前高亮+完成打勾,完成淡出报告体淡入(照原型 .gen-zone 形态);Initial 态引导文案。
   - 报告体=单页滚动六章节+**变体 B 右缘圆点锚点**(悬停标签,点击平滑滚动,滚动高亮当前章)。
   - 章节:总览(hero 期初→期末净资产+变动 chip+四卡:收入/支出/结余/储蓄率+现金净变动+附注两卡[口径/未包含项])、资产负债(期末构成两列+期初期末变动表)、收支(支出分类横条+收入构成+日均/对比)、现金流(三类三列表+勾稽脚注)、预算执行(条形+超支警示色)、投资绩效(五数值卡)。**全部走 context.yucai 语义令牌零裸色**;图表复用 fl_chart 既有组件/写法。
   - 金额格式化:找项目既有千分位格式化助手复用(grep `formatAmount/千分位/NumberFormat` 惯例),禁手搓新副本。
3. **路由**:`lib/app/router.dart` 加 `/reports/full` 子路由(静态,照 go_router 既有惯例与注释规则);`report_page.dart` 顶栏加「财务报告」入口按钮(FR-1,导航到 /reports/full)。
4. **测试**:`test/report/presentation/financial_report_bloc_test.dart`(bloc_test 全迁移含 Retry)+ 页面/widget 测试(`financial_report_page_test.dart`:期选择/生成→Loading→Loaded 章节渲染/错误态重试/附注两卡/变体 B 锚点存在/自适应章节缺席时不渲染)。golden 或文本断言按项目惯例选轻者。

## 硬约束

- presentation→domain 依赖方向;不 import data 层;零 proto/server 改动;中文文案;design-v2 令牌零裸色(NFR-2,review 门 grep);不碰 test/holding。
- 完成门:`flutter test test/report` 全绿+全量 `flutter test` 绿+`flutter analyze` 446 持平;build_runner regen 若 injection 变更。
- commit:`feat(report): T5 财务报告页——bloc+六章节+变体B锚点+进度+路由入口`。回报:文件清单、测试数、commit hash、遗留。
