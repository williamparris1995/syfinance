# Task Brief T6 — 收尾:全量门 + 金图重录

## 位置与环境
- worktree(只在此工作):`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r19-f58`;client `<worktree>/yucai/client`
- 前置:T1-T5 全部完成(以实际落码为准)。

## 任务
1. **金图**:跑 `flutter test --update-goldens` 于波及的 golden 测试(shell 顶栏三段面包屑、三详情页结构)——先跑全量 test 看哪些 golden 红,逐个判断「预期变更」vs「回归」:预期变更才重录,回归上报勿录。重录后复跑全量须绿。
2. **全量门**:
   - `cd <worktree>/yucai/client && flutter test`(全量,0 failures;既有 flake 双跑排除因果照仓惯例)
   - `flutter analyze`(≤ 基线 463;若 T3-T5 有清欠可低于)
   - e2e:`cd <worktree>/yucai && make client-e2e`(15 套件;波及成员——债务/债权/账户详情导航断言——若因 AppBar 退役/面包屑回退而红,按新行为更新断言;tap 落空先想 tapAt 坑)
3. **e2e 更新约束**:只改导航相关断言;行为断言(记账/删除等功能)不动——若功能断言红=实现 bug,上报。
4. 报告:各门输出摘要 + 重录金图清单 + e2e 改动清单。

## 约束
- 勿动 lib/ 生产代码(发现 bug 上报,不擅改;金图/e2e 断言文件可改)。
- Windows 坑:如需跑 app,先 taskkill yucai_client.exe(进程锁)——本任务纯测试,理论上不需要。
