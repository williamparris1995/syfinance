# Spec — F13 离线同步 e2e(消费方契约测试)

> R9 sprint-1 · 2026-09-03 · analysis 产出(形态=契约测试 CDC,用户拍板)。

## Goal

client 离线同步全链路的**消费方契约测试**进默认回归门:断网记账→pending→回网→真 gRPC 线协议→进程内假 SyncService(钉同一份 wire 契约)→成功回写;与 F11 的提供方测试(Go 侧)组成完整 CDC。

## Requirements

- **FR-1 契约链路测试**(integration_test 新文件,自包含夹具):真 DI/真三态路由/真 pending/真 collector/真 envelope 编码/真 GrpcOfflineSyncPort/**进程内 gRPC 假 SyncService**(sync.pbserver 服务基类,127.0.0.1 临时端口,记录收到的 PushChangesRequest)——链路:bound+offline(fake ConnectivityGateway 注入)→ 多模块写+删 → 回网翻转 → 协调器触发 → 假 server 断言 wire 形态(entityType/payload 解码=envelope 行/墓碑 DELETE/deviceId/entityId==payload.ID)→ OK 响应 → 本地 synced/墓碑清/镜像刷新数据仍在。
- **FR-2 失败重试路径**:假 server 回 unavailable → pending 保留(badge 状态语义级)→ server 恢复 → 再触发 → 收敛 synced。
- **FR-3 回归门收编**:文件尾追加 E2E_FILES;`make client-e2e` 全绿(guest 既有链路零扰动——本文件自建 DI 覆写不泄漏)。

## NFR

- 测试库隔离照旧(YUCAI_DB_FILE 守卫/测后删);端口用临时分配避免冲突;确定性(无真实网络依赖——localhost 进程内)。

## Scope boundary

| 排除 | 理由 |
|---|---|
| 全栈真 server e2e(docker+Go+真登录绑定) | CDC 定案;真集成信心由双侧契约+R6 式人工验收承载 |
| UI 级断网操作(badge 渲染/表单点按) | F12 widget 测试+既有 ui_* 已覆盖;本文件钉数据链路契约 |

## Grill record

| 决策 | 定案 |
|---|---|
| 测试形态 | 用户选 CDC(契约测试):消费方测试+提供方测试(F11)夹同一契约;术语澄清后拍板 |

## Feasibility

technical ✓(pbserver 生成物在;GrpcClient 经 AppConfig 可覆写;fake gateway 注入先例=tracker 单测);economic ✓(单测试文件);operational ✓(进默认门)。
