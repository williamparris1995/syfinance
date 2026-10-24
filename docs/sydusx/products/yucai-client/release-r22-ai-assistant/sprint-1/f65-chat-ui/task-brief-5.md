# Task Brief T5 — prompt 七要素 + 全门 + e2e + 覆盖表

- worktree `.claude/worktrees/r22-f65`(T1-T4 已合入:33a69c12 最新)。不碰 UI/工具既有实现(prompt 常量修订属本票豁免);docs 落档允许。
- 任务:
  1. **system prompt 七要素**:`agent_loop_impl.dart` 的 systemPrompt 常量扩为七要素(F64 五要素 + ⑥意图/范围/口径不明先反问澄清给具体选项 ⑦超出工具能力明说局限并给最接近的替代路径);更新常量断言(五要素测→七要素);补一集成回放:脚本化 LLM 首轮遇歧义问句先输出澄清问句(不调工具)→用户补充后二轮才调工具执行(钉 FR-5 话术落点)。
  2. **e2e**(`integration_test/` 照仓内 15 套件惯例建 `assistant_panel_e2e_test.dart`,seed→断言→测后清库范式):真壳起 app→点助手 FAB→浮层出现+**引导态可见**(未启用文案)→「去设置」可跳设置页且「AI 助手」卡渲染(未下载态)→关闭浮层。全程无需引擎/模型(引导态即验收面);若仓 e2e 对无 server/guest 有特殊引导,照最简套件形态。
  3. **全门**:全量 flutter test(精确数)/analyze 459 零新增/git diff main -- yucai/server 空;`make client-e2e` 或等价单文件跑新 e2e 绿(F= 单文件惯例)。
  4. **覆盖表**:新建 `code-ledger.md`(照 F64/F66/F67 格式):spec F65 全 FR/NFR↔用例映射(含 T3 的 v19 对齐差异表转录+两处报备差异[dock 并列几何依据 v19/澄清以文本承载])+T1-T5 commit 记档。
- 验证门:全门四条+e2e 绿。commit `feat(assistant): F65-T5 prompt 七要素+e2e+全门+覆盖表`。汇报:prompt 七要素文案/e2e 断言摘要/全门输出(精确数)/覆盖表摘要/commit hash。
