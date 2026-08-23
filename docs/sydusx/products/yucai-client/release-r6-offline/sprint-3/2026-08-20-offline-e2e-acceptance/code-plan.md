# Code Plan — feature I 三判据 e2e 验收

- [x] T1 e2e 测试 4 组(test/e2e/r6_acceptance_test.dart,真实临时文件库+接口级 mock 远端)
- [x] T2 人工验收清单 acceptance-checklist.md(4 场景真机步骤/预期/勾选/执行记录)
- [x] T3 全套 +1089 -4(=基线,+4 新测试);analyze 400(未用 var guardDone 清理后回落);零 server

## 执行记录(2026-08-23)
- 修复:drift 关库不可重开(重开须重建绑定该连接的全部 ds → reopen() helper);mocktail 后置 when 覆盖前 stub(guard 空与验证非空需按阶段切 stub);验证 facet 需返回全量账户数。
- e2e-④ 口径注记:镜像整表替换=绑定后远端是 truth(guest 期交易被远端列表替换——H 的设计口径);holding facet 无远端 mock→刷新静默失败→guest 数据保留(accepted:facet 独立)。
