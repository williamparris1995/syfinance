# code-ledger — 到期事项常显提醒

| Task | 状态 | 评审 | fix-rounds | 裁决/遗留 |
|---|---|---|---|---|
| T1 数据层地基 | ✅ done(2026-09-23) | 控制器两轴 PASS | 0 | DueTarget=AccountTarget/DebtTarget;settle 收 InboxEntryState 枚举;upsertActive 收 DateTime 内部格式化;行模型=drift 生成类。**遗留:store 无 target 解码,T4 补(targetKind/targetId→DueTarget)** |
| T2 读侧候选流 | ✅ done(2026-09-23) | 控制器两轴 PASS(scanner diff 逐字核对) | 0 | filterActiveCandidates 共享纯函数(scanner 机械提取,既有测试零改动=行为不变证明);daysBetween 公开化(纯重命名);syncer 无条件 upsert(store 幂等使滚动刷新可达,ADR-3 不复活由 store 保证);provider 吞错降级已测试钉死 |
| T3 首页聚合条 | ✅ done(2026-09-23) | 控制器两轴 PASS(令牌同源 F37 核对) | 0 | 纯展示+回调式;getIt.isRegistered 守卫(T5 注册前裸测试不炸);**已知边界:空账户页无 hero 锚点不出条**(无账户却有候选的极边界, parked);明细行序=候选流原序(排序若需统一应上移共享管线,避免三消费方分叉) |
| T4 收件箱页 | ✅ done(2026-09-23) | 控制器两轴 PASS(lastSeen 先读后写时序核对) | 0 | **AccountTarget 直达裁决:跳 /accounts/:id 详情页非直开对话框**(HLD 依赖注记+复用第一;聚合条仍两击直达,收件箱三击可接受);/inbox = StatefulShellBranch index 9;窄屏底栏无 inbox 槽(FR-7 唯二入口,回退高亮仪表盘);lastSeen=null 全打点;app_shell 面包屑 case 9 |
| T5 托盘行+装配 | ✅ done(2026-09-23) | 控制器两轴 PASS(FR-4 四规则核对) | 0 | 全逾期文案=「待还 N 笔 · 已逾期 M 天」(M=最大逾期天数,与 banner 口径一致);提醒中心项在记一笔之下;tray 既有 exact-keys 断言 3 处更新(加菜单项的既定行为变化,scanner 测试零改动保持);装配经 @visibleForTesting 拆缝(测试即生产,F22 先例);headProvider 并入 provider.latest |
| T6 收官门 | ✅ done(2026-09-23) | 控制器亲跑:全量 **2028 全绿**(基线 1958+新 70);analyze **438=基线净 0** | 0 | 提交(单 feature 一提交,详尽 message,v1.0.10 先例);排除既有杂散(.zcode//devtools_options.yaml/scratch_repro_test.dart) |
