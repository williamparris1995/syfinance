# Code Plan — F13 离线同步 e2e

## Tasks

- [x] **T1 契约链路测试**:FakeSyncService(进程内 gRPC)+DI 覆写 harness+FR-1 链路+FR-2 失败重试+Makefile 尾追加;`make client-e2e` 全量+flutter test 全量绿。

## 执行方式

单实现任务(测试文件特性)→ 两轴 review → 全量门 → finish。


## Ledger 记账

| task | 状态 | fix-rounds | 记事 |
|---|---|---|---|
| T1 契约链路测试 | ✅ | 1(REJECT→修:pbjson 手工补齐误改既有描述符 1 字符[T1IJ→T1SJ,字节级实证非法 wire 编码]回退;注释补兄弟模块同病说明) | review 字节级解码抓雷是本流程标杆;修复后纯新增 68 行与 HEAD 逐字节一致;grpc 桥(protobuf↔grpc 5.x Server)与 teardown 顺序(channel 优雅关→server.shutdown)两个环境事实钉入注释;E2E_FILES 现 12 文件 |
