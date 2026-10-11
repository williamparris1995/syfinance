# Task Brief T8 — 备份 envelope isSystem 往返(NFR-2)

## 上下文
worktree:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r17-f49`;客户端 `yucai/client`。
先读 feature 目录 `spec.md`(NFR-2)与 `design.md`(单元8)。T1 已落实体字段。

## 任务(TDD)
1. 核验:`core/localdb/envelope_codec.dart` 与 `envelope_row_codec.dart` 的 accounts 列集合是否含 `isSystem/IsSystem`——读代码定论。
2. 缺则补:编码(实体→行映射列)与解码(行→实体)双向;备份 JSON 键名照该 codec 既有命名风格(找相邻列如 ParentId 的键名范式)。**若已含则只补测试并报告「现状已含」**。
3. guest 备份兼容:旧备份(无该键)恢复 → isSystem=false(缺省安全,旧库载体户未隐藏属预期,T3 repair 已跑过 marker 不再补——在报告里明确这个边界,不改 repair)。

测试(`test/core/localdb/` 既有 envelope 测试文件增测):
- 往返:isSystem=true 的账户 → encode → decode → true
- 旧格式(手工构造无该键的行)→ decode → false

## 约束
只动两个 codec + 测试;禁碰 repairs/页面/debt。

## 完成判据
两测绿;analyze 零新增;报告核验结论(含/缺)+改动清单。
