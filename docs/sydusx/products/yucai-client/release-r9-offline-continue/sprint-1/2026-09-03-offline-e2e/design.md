# Design — F13 离线同步 e2e

> R9 sprint-1 · 2026-09-03。

## ADRs

- **ADR-1 进程内假 server**:`FakeSyncService extends SyncServiceBase`(sync.pbserver.dart);grpc `Server([...])` 绑 `127.0.0.1:0` 取临时端口;记录 requests(原始 proto)+可编程响应(OK/unavailable);测试收尾 `server.shutdown()`。
- **ADR-2 DI 覆写 harness**:resetTestDb 后——覆写注册 `ConnectivityGateway` 为 `FakeGateway`(可控 online 流,StreamController.broadcast)、覆写 `GrpcClient`(channel 指向临时端口)、tracker 手动置 bound/offline(照 F10 测试先例直接驱动字段或经 auth 流);BoundMarker fake 注入(port deviceId 来源)。getIt 覆写用 reset 局部重建或 allowReassignment——照库内测试覆写惯例,注释理由。
- **ADR-3 协调器驱动**:不 pump app shell——直接 `getIt<SyncCoordinatorBloc>()` 构造(经覆写后的 DI)→ fake gateway 发 online true → await 状态收敛(轮询/Completer,照既有集成测试 pumpAndSettle 节奏或纯 Future 等待——本文件无 UI,纯 Future 即可,注释)。
- **ADR-4 断言口径**:wire 形态断言复用 F11 T3 的字段清单(entityType=SyncModule 常量/payload jsonDecode 后 PascalCase 键集/无 tenant 无 syncState/墓碑空 payload/deviceId=BoundMarker 串);成功后本地状态经 DAO 断言(synced/墓碑空)+镜像刷新(data 保留——refreshModule 经 fake repo remote?镜像在此链路触发=协调器成功回调,走真 BoundMirror→真 repo→远端 gRPC=假 server 的各模块 list RPC…**假 server 只实现 SyncService,repo remote 会打不通**——设计裁决:镜像刷新在测试断言层用「数据仍在」(本地 pending 已 synced,无 refresh 也不丢)替代真镜像往返;refresh 的 pending 保护已由 F10 单测钉。注释论证此简化)。

## HLD

单文件 `integration_test/link_offline_sync_e2e_test.dart` + Makefile 尾追加 + (若需)link_support 增 harness helper。

## Risks

| 风险 | 缓解 |
|---|---|
| 进程内 gRPC 在 Windows 集成测试环境的行为 | grpc 包 server 纯 Dart,localhost 无防火墙问题;端口临时 |
| DI 覆写污染其他测试 | 本文件独立进程(每文件单跑);文件内 tearDown 恢复 |
| 纯 Future 等待的超时 | Completer+超时断言,照集成测试既有模式 |

## Open Questions

无。
