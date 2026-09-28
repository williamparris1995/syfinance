# Task Brief T3 — 门与收尾(F46 R16 sprint-2)

**工作目录**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r16-f46`(分支 feature/r16-f46;`yucai/client/`)。前置:T1(050ed7ac)+T2(f7d63963)全落地。

## 任务

1. **e2e 断言**:设置页「AI 分析师」卡可达+六行渲染(种子库默认未启用→配置行禁用态;真实 LLM 调用不进 e2e,注释钉边界);报告页「AI 解读」按钮在未启用时不出现(与 Loaded 无关)——扩 `integration_test/` 既有成员或 financial_report_e2e 增链,照风格勿过度。
2. **全门五项证据**(实测原样):全量 flutter test 总数/analyze stash 对比(基线 446)/make client-e2e 全绿/proto+server 零 diff/build_runner 幂等(本票有 DI 变更,必验)。
3. 平台噪音 checkout。

## 完成动作

commit(`test(llm): T3 e2e 设置卡可达+全门证据`)。回报:五项证据/修改文件/commit hash/遗留。
