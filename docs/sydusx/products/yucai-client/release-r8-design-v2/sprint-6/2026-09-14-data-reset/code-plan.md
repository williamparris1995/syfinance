# Code Plan — F21 数据重置

- [x] **T1 全链**：入口+三步确认+备份先行+清空重启；TDD；全量门。


## Ledger

| task | 状态 | fix-rounds | 记事 |
|---|---|---|---|
| T1 全链 | ✅ | 0(review APPROVE;格式/文案 minor 顺手修) | fail-closed 顺序[写失败注入双断言];exit/dbFiles/writeBackup 三缝可测;用户三诉求逐条对上 |

## holistic(兼)APPROVE — 2026-09-14
