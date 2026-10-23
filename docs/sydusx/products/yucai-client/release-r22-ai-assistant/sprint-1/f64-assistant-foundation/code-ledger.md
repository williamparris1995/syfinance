# F64 code-ledger

> /sydusx-execute 任务台账(task done / fix-rounds / rulings)。评审批次说明:T2/T3/T4 评审合并一轮(data 层三 diff 联评,T1 已单独评)。

- **T1 domain 契约层 ✅ done**(commit 57aad7c5;33 测;analyze 459 零新增;server diff 空) — 评审 **PASS**(2026-10-23,零 High/Medium)。fix-rounds 0。parked:L-1 domain 经 core/llm 传递拉 Flutter 依赖(复用单源 vs domain 纯度两难,后续票把 LlmProvider/LlmEndpoints 提纯 Dart 文件);L-2 pubspec 注释传递依赖枚举可补「等」。ruling:均 Low 可延,F65 前提取票候选。
- **T2 AssistantSettings 存储 ✅ done**(commit fbcba729;8 测;关键差异断言 localhost 免 Key 助手档 ready vs F46 not-ready 已钉) — 评审并入 T3/T4 批次(待)。
- **T3 三只读工具** — 在途。
- **T4 LlmStreamClient+审计** — 在途。
- **design.md 漂移修正**:HLD 树注释 ToolContext 字样移除(T1 评审 Low-3,控制器顺手修文档,非实现)。
