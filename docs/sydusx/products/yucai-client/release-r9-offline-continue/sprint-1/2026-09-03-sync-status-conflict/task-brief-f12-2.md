# Task Brief F12-T2 — SyncStatusBadge + 挂载

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r9-f12`,客户端 `yucai/client/`。**TDD。** T1(bc98dec5)已就绪。

## 先读(必读)

1. `docs/.../2026-09-03-sync-status-conflict/{spec.md FR-1/4,design.md ADR-1/4}`
2. `lib/app/widgets/app_shell.dart`(:494 OfflineBadge 挂载处;OfflineBadge 实现约 :688——尺寸/样式基准)
3. `lib/binding/presentation/bloc/sync_coordinator_bloc.dart`(状态类/事件;**顺手修一处 doc 措辞**:pendingCount 字段 doc「syncing/failed 为本批变更数(权威值)」→ 改为「实时待同步计数(watcher 流权威;syncing 中亦随实时覆盖)」——T1 review 观察 (a))
4. R8 令牌:`lib/core/theme/app_design.dart`(context.yucai)

## 交付物

### 1. SyncStatusBadge(`lib/binding/presentation/widgets/sync_status_badge.dart`)

- StatelessWidget,`BlocBuilder<SyncCoordinatorBloc, SyncCoordinatorState>`;**仅 `!tracker.isGuest` 渲染**(SessionModeTracker 注入或 getter 注入——照库内 widget 拿 tracker 的惯例;guest → SizedBox.shrink)。
- 四态(spec FR-1):
  - `syncing` → spinner(小)+「同步中」;
  - `failed` → negative 色调 chip:原因截断+onTap → `SyncRetryRequested`;
  - 其他态 `pendingCount > 0` → muted chip「待同步 N」(无 onTap);
  - clean(非 syncing/failed 且 N==0)→ 隐藏。
  - **渲染优先级**(T1 review 观察 (b) 的消化):syncing/failed 优先于计数文本(failed 且 N>0 时显示失败态,计数不叠加——或叠加小数字,自选,注释理由)。
- 样式对齐 OfflineBadge 规格(读实现:字号/圆角/padding 节奏照抄);语义令牌;中文文案。

### 2. app_shell 挂载

- :494 `const OfflineBadge()` 旁挂 SyncStatusBadge(需要 bloc provider——检查 app_shell 的 bloc 提供结构:SyncCoordinatorBloc 是 getIt lazySingleton,用 `BlocProvider.value` 或直接 `BlocBuilder`+getIt 取,照 app_shell 既有非路由 bloc 的消费惯例;若 app_shell 无先例,最小形态=widget 内 `context.watch` 经 BlocProvider.value 包一层,注释理由)。
- **app_shell 必须提供 SyncCoordinatorBloc 实例**(这是 F10 以来首个生产 resolve 点——构造期补扫随首帧发生,注释)。

### 3. TDD 测试

- badge widget 单测:四态渲染/failed tap 发 SyncRetryRequested(bloc mock 或 spy)/guest 隐藏/令牌(裸色断言:无 Color(0x)/AppColors——静态检查式断言或人工核对注释)。
- app_shell 挂载:既有 app_shell 测试适配(badge 仅绑定态渲染,guest 测试不受扰;若 app_shell 测试需要 fake SyncCoordinatorBloc,照 ThemeSettings fake 模式)。

## 验证

1. 新单测绿(先红后绿)
2. `flutter test` 全量不回归(≥1408)
3. `flutter analyze` 新文件 0 条
4. `make client-e2e F=integration_test/app_pages_test.dart`(guest 主链路抽验不回归——badge guest 不渲染)

## 约束

F10/T1 语义零破坏(除授权的 doc 措辞一行);R8 令牌;中文注释;不 commit。完成后报告。
