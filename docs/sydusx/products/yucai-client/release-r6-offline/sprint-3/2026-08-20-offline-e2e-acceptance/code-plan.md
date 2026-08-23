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
