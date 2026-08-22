# Code Plan — feature F 离线写完整性

- [x] T1 BalanceLocalUpdater + transaction local ds 三路径联动(insert/update/delete)
- [x] T2 FIFO 余量报错 + tag 校验幂等 + networth 口径迁移
- [x] T3 离线徽标(AppShell) + 启动自检(AppDatabase.integrityCheck + 横幅)
- [x] T4 测试:联动 oracle ×4/坏 id 回滚/FIFO 报错/幂等/重启持久(临时文件库)/networth 新口径
- [x] T5 全套基线 + analyze + 提交
