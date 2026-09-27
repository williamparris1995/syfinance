# Task Brief T4 — 门与收尾(F44 R16 sprint-1)

**工作目录**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r16-f44`(分支 feature/r16-f44;`yucai/client/`)。前置:T1-T3 全落地(HEAD 含 T3 评审修复)。

## 任务

1. **e2e 扩断言**:`integration_test/financial_report_e2e_test.dart` 扩——种子内造一条可触发发现(如预算超支:某预算项限额压低使 R2 warn 触发;或模板闲置:种子加未暂停模板+期内无推进使 R4 触发,取实现成本最低者,数字手算 oracle),断言:第七章节渲染+对应 Finding 文案+总览摘要卡出现;再断言零发现路径健康徽章(可用另一期或调种子)。照既有 e2e 成员风格,勿过度。
2. **NFR-1 计时**:8 规则引擎全跑 ≤500ms 测试(fake 大 supplement:如 200 模板×12 应扣日+500 大额交易,Stopwatch 断言)。
3. **全门五项证据**(实测原样记录):全量 flutter test 总数/analyze stash 前后对比(基线 446)/make client-e2e 全绿/proto+server 零 diff/build_runner 幂等。
4. **平台噪音还原**(generated_plugin_registrant 仅行尾差异则 checkout,实质差异报告)。

## 完成动作

commit(`test(report): T4 e2e 诊断断言+NFR-1 计时+全门证据`)。回报:五项证据/修改文件/commit hash/遗留。
