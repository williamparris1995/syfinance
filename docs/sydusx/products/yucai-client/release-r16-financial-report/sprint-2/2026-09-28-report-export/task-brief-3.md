# Task Brief T3 — 门与收尾(F45 R16 sprint-2)

**工作目录**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r16-f45`(分支 feature/r16-f45;`yucai/client/`)。前置:T1(f388009f)+T2(d549b2be)全落地。

## 任务

1. **NFR-2 计时测试**:典型报告(全章节 fixture)PDF 全链渲染(含字体加载,字体经真实 bytes 注入)≤2s,Stopwatch 断言+防空调转断言(页数/锚点复用既有)。
2. **e2e 入口断言**:`integration_test/financial_report_e2e_test.dart` 扩——Loaded 态「导出财务报告」按钮存在+格式菜单两项(PDF/Markdown)可弹(真实 saveFile 对话框不可 e2e 自动化,断言到菜单层即可,注释说明边界);照既有成员风格。
3. **全门五项证据**(实测原样):全量 flutter test 总数/analyze stash 对比(基线 446)/make client-e2e 全绿/proto+server 零 diff/build_runner 幂等(本票无 injectable 变更则记「无 regen 面」跳过)。
4. 平台噪音 checkout(generated_plugin_registrant 行尾差异)。

## 完成动作

commit(`test(report): T3 NFR-2 计时+e2e 入口断言+全门证据`)。回报:五项证据/修改文件/commit hash/遗留。
