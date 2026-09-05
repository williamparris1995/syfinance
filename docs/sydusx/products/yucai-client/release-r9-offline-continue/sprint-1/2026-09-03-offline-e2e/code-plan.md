# Code Plan — F13 离线同步 e2e

## Tasks

- [ ] **T1 契约链路测试**:FakeSyncService(进程内 gRPC)+DI 覆写 harness+FR-1 链路+FR-2 失败重试+Makefile 尾追加;`make client-e2e` 全量+flutter test 全量绿。

## 执行方式

单实现任务(测试文件特性)→ 两轴 review → 全量门 → finish。
