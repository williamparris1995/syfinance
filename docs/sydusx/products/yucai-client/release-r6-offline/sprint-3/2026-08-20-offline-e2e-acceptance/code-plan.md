# Code Plan — feature I 三判据 e2e 验收

- [x] T1 e2e 测试 4 组(test/e2e/r6_acceptance_test.dart,真实临时文件库+接口级 mock 远端)
- [x] T2 人工验收清单 acceptance-checklist.md(4 场景真机步骤/预期/勾选/执行记录)
- [x] T3 全套 +1089 -4(=基线,+4 新测试);analyze 400(未用 var guardDone 清理后回落);零 server

## 执行记录(2026-08-23)
- 修复:drift 关库不可重开(重开须重建绑定该连接的全部 ds → reopen() helper);mocktail 后置 when 覆盖前 stub(guard 空与验证非空需按阶段切 stub);验证 facet 需返回全量账户数。
- e2e-④ 口径注记:镜像整表替换=绑定后远端是 truth(guest 期交易被远端列表替换——H 的设计口径);holding facet 无远端 mock→刷新静默失败→guest 数据保留(accepted:facet 独立)。

## Review 修复轮(2026-08-23,首轮:FR-4 Critical + analyze 14 诊断 + FR-2 断言缺口)

- **FR-4 重写**:远端 mock 改为**忠实的 post-G 形态**(上传后的 guest 数据 + 带 entries[id 非空] 的绑定期新写)→ 镜像整表替换后 guest+bound 皆在;补 tracker 翻转(登入 isGuest=false/登出 true)与**登出终刷断网场景**(list 抛异常→refreshAll 静默降级,镜像不变);断言 cash 5400/remote-1/entries×2。
- **FR-2 强化**:8 模块键 containsAll(exporter 漏模块不可静默过)+账户实体 ID 集合与本地比对;计数改精确(=2)。
- **14 诊断清零**(unused imports/const 化/下划线局部变量);evaluate:首轮的「口径重塑」批判成立——原实现没测 spec 说的合并可见,mock 形态决定可测性。
- 修复后:e2e 4/4 绿;全套 +1089 -4(=基线);analyze 385;零 server。

## 二轮修复(复审 reject:FR-4 transaction 模块 mock 仍不忠实 + tracker 翻转无消费者)

- **远端 txn mock 补齐 guest 交易**:上传前 capture 本地头+entries→重建为远端返回列表(guest×2+remote-1);终态断言 containsAll(guestIds+remote-1) 且精确计数+1——「合并可见」真正可断言。
- **tracker 翻转接入真 seam**:构造 AccountRepositoryImpl(remoteDs mock, local ds, tracker)——bound 态经 repo 读远端真值 5400;isGuest=true 后同值经本地返回(数据源切换可观察);删除裸 tracker 装饰代码。
- 恒等映射死代码清除。
- 二轮修复后:e2e 4/4;全套 +1089 -4(=基线);analyze 385 该文件 0 诊断。

## Review + Test(2026-08-23,pass — 三轮)

- 三轮收敛(首轮 FR-4 Critical/二轮 transaction 模块 mock 复发[评审者原话:「mock 形态决定可测性」]/三轮补齐)——纯测试 feature 的 review 焦点=断言充分性+mock 保真度,教训:**mock 的形状就是被测世界的形状,不忠实的 mock 会把判据变成不可断言**。
- Test 裁定:pass——4 组判据测试真验各自 spec 场景(合并可见/8 模键+ID 比对/3 轮累计/终刷断网降级)。
