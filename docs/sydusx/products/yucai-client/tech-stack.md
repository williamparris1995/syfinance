# 御财 Client — Tech Stack

> client 产品栈(Flutter/Dart)。决策溯源见 [adr/index.md](adr/index.md);架构见 [architecture.md](architecture.md);共享基建见 [portfolio/infrastructure.md](../../portfolio/infrastructure.md)。
> 2026-08-05 拆分自原统一 tech-stack。

| 类别 | 选型 | 备注 |
|---|---|---|
| 语言/框架 | Flutter(Dart) | desktop + mobile 响应式 |
| 架构 | DDD 四层 | 见 [architecture.md](architecture.md) |
| 状态管理 | **flutter_bloc** | Event→State 映射 CQRS |
| DI | **getIt + injectable**(`@LazySingleton` / `@Injectable`) | build_runner 重生成 |
| 路由 | go_router | 静态子路由(`/new` `/edit`)必须在 `/:id` 前 |
| 网络 | grpc + AuthRetryCaller `_retry` | 401→RefreshToken→retry;consumes [yucai-api 契约](../../portfolio/contracts/yucai-api/README.md) |
| i18n | **中文直写(非 i18next)** | ⚠️ 阶段二改 i18next,[ADR-006](adr/index.md#adr-006) |
| icons | lucide | — |
| 本地 DB | **Drift(SQLite)** | R6 本地优先落地(schemaVersion=11);guest 主库/绑定后全量镜像;断网续写+增量同步 |
| 测试 | flutter test + mocktail(M/Fake)+ bloc_test | 基线 3 fail/2 文件(test drift) |

## 关键约束(影响栈使用)

> 详见 [portfolio/conventions.md](../../portfolio/conventions.md)。栈相关:
- proto 改后 Dart stub regen(Dart **protoc_plugin 必须 25.0.0**;21.x→protobuf 4.x 旧 API → analyze 暴增)。
- injectable 改后 `dart run build_runner build --delete-conflicting-outputs`。
- 路由优先级:静态子路由(`/new` `/edit`)必须在 `/:id` 前。
