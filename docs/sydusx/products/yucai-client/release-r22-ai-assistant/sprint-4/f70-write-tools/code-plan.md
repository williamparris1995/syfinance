# F70 code-plan

> /sydusx-execute 2026-10-27。批次:[T1]→[T2]→[T3]→[T4] 串行;SDD;UI 照 prototype/CURRENT v20。

- [x] T1 写域契约+三工具 — write_action.dart(sealed WriteAction)/write_executor.dart(port+WriteOutcome)/loop port 扩 appendToolOutcome;transaction_add/update/delete 三工具(名称→id 解析消歧/定位复用只读查询);AssistantAuditLog 扩 logWrite;表单预填入口查证回填 design OQ(2026-10-27 完成:无部分字段预填入口,v1 引导只跳转);单测(domain 2 文件 + 三工具 3 文件 44 例 + loop/audit 扩例)
- [ ] T2 执行器+bloc 扩展 — WriteExecutorImpl(TransactionRepository 同管道+幂等集+审计+appendToolOutcome);bloc 扩 WriteApprovalMsg/ConfirmWrite/CancelWrite/作废/替换;绕过负测(未经确认回调零写调用)
- [ ] T3 确认卡 UI — 三形态卡(preview/diff/destructive)+五状态徽标+失败重试+引导卡 deep link(照 v20);widget 测
- [ ] T4 全门+e2e — 全量门+e2e(记→改→删真壳全流程含取消路径)+覆盖表
