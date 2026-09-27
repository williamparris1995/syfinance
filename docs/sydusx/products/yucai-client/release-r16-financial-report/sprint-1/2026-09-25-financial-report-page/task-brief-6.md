# Task Brief T6 — 门与收尾(F43 R16 sprint-1)

**工作目录(必须在此)**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r16-f43`(分支 feature/r16-f43;`yucai/client/`)。前置:T1-T5 全部落地(当前 HEAD 含 T5 评审修复)。

## 任务

1. **client-e2e 新成员**:`financial_report` 进 e2e 管道——照 `yucai/client-e2e/`(或 client/tool 相应目录,先探明结构)既有成员范式:种子(账户+分录+预算+持仓最小集)→导航 /reports 顶栏「财务报告」→ /reports/full 选期生成→断言六章节关键数值(种子手算 oracle)与自适应(种子缺预算则预算章缺席+附注)→测后清库。e2e 数量与断言保持既有成员风格,勿过度。
2. **全门核验并留证据**:
   - `cd yucai/client && flutter test` 全量全绿(记录总数);
   - `flutter analyze` 与改动前基线零新增(当前公认 446;若 T5 修复有出入,以「stash 前后对比」实测口径为准);
   - `make client-e2e`(在 yucai/ 下;全管道绿,含新成员);
   - **proto/server 零 diff 门**:`git diff main --stat -- yucai/proto yucai/server` 输出为空;
   - build_runner 幂等:`dart run build_runner build --delete-conflicting-outputs` 后 git 无新差异(injection.config 稳定)。
3. **平台噪音还原**:`git checkout -- yucai/client/linux yucai/client/macos yucai/client/windows` 之下被 flutter 命令触碰的 `generated_plugin_registrant*`(若仅空白/行尾差异);有实质差异则报告勿擅自提交。
4. **注记抽查**:lib/report/ 与本票触及的 holding 文件,文件头+函数级中文注释齐(抽查即可,缺则补)。

## 完成动作

commit(`test(report): T6 e2e 新成员 financial_report+全门证据`)。回报:全门五项证据(测试总数/analyze 对比/e2e 结果/零 diff 输出/build_runner 幂等)、修改文件、commit hash、遗留。
