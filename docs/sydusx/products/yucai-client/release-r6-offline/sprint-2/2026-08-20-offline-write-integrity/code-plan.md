# Code Plan — feature F 离线写完整性

- [x] T1 BalanceLocalUpdater + transaction local ds 三路径联动(insert/update/delete)
- [x] T2 FIFO 余量报错 + tag 校验幂等 + networth 口径迁移
- [x] T3 离线徽标(AppShell) + 启动自检(AppDatabase.integrityCheck + 横幅)
- [x] T4 测试:联动 oracle ×4/坏 id 回滚/FIFO 报错/幂等/重启持久(临时文件库)/networth 新口径
- [x] T5 全套基线 + analyze + 提交

## Review + Test(2026-08-22,pass)

- 首轮 review:无 BLOCKER,4 MEDIUM(update 平衡校验/networth 口径诚实化/自检 warning/重启链路窄)→ 全修 → 复审 **pass**(server DoubleEntryValidator 逐条镜像核对;扩链断言数学核对)。
- Test 裁决:**pass** — 全套 +1068 -4(=基线 4,零新增);analyze 376 < main 398;requirement coverage:FR-1 联动 oracle ×5(含坏 id 整包回滚/holding 自动联动)/FR-2 FIFO+幂等/FR-3 徽标(弱验证,widget 测试 defer)/FR-4 自检 SQL/FR-5 重启扩链全绿/NFR 实测。
- **Accepted 记档**:guest networth 不含 realized PnL(卖出后投资账户贷 proceeds 非 FIFO 成本;与 bound 态差额=累计 realized gross PnL)——记入注释与 ledger,feature H 镜像时统一。
- 残留(非阻塞):write_integrity_test 2 条首轮已存在 warning(顺手清 defer);徽标 widget 测试 defer。
