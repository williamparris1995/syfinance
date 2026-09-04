# Task Brief F10-T2 — schema v3(syncState+墓碑)+ pending 置位 + 镜像协调

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r9-f10`,客户端 `yucai/client/`。**TDD。** T1(27ec26aa)已就绪:三态路由+写降级(降级写 local 处有 TODO-F10T2 锚点)。

## 先读(必读)

1. `docs/.../2026-09-03-offline-write-buffer/{spec.md FR-3/4,design.md ADR-2/3/4}`
2. `lib/core/localdb/app_database.dart`(schemaVersion=2;migration 先例 127-145 加 ReminderLogs)与 `tables/` 8 头表
3. `lib/binding/data/bound_mirror.dart`(refreshModule 的 delete-all+rebuild,如 _refreshTransactions :110-128)与 `mirror_mappers.dart`
4. 8 个 local DS 的写路径(置 pending 的落点)与删除路径(墓碑落点);T1 的 `bound_write_fallback.dart` 与 repo `_routedWrite` 的 TODO-F10T2 锚点

## 交付物

### 1. schema v3 迁移

- 8 头表(accounts/transactions/tags/budgets/debts/goals/holdings/transactionTemplates)加 `syncState TEXT NOT NULL DEFAULT 'synced'`(值域 synced/pending;drift 表类+DAO 相应支持)。
- 新表 `SyncTombstones(module TEXT, entityId TEXT, deletedAt DateTime, PRIMARY KEY(module, entityId))`。
- schemaVersion 2→3 migration:加列(回填 synced)+建墓碑表。**旧库升级无损**(既有 e2e 库走迁移路径——注意 integration_test 用新库即 v3;单测用内存库自动最新)。

### 2. pending 置位(route 感知)

- 各 local DS 写路径(create/update/record 等)增可选或 route 感知参数——**形态自选**(推荐:repo `_routedWrite` 的降级分支与 boundOfflineLocal 分支显式传 `markPending: true`,guest 分支不传默认 synced;local DS 方法加可选参默认 false,注释三态语义)。TODO-F10T2 锚点处落地。
- 8 模块全覆盖(含 template record、debt 期次还款/借出、holding buy/sell 等复合写——复合写在同一事务内,头行置 pending;子表无 syncState 不动)。
- **update 场景**:bound 路由对 synced 行的本地 update → 置回 pending(整行待上行)。

### 3. 墓碑写入

- 8 模块 local DS 的 **delete 路径**(route 感知同上):bound 路由删除 → 硬删本地行 + 插墓碑;guest 删除不写墓碑(注释:绑定走全量首传)。
- account delete 有非零余额守卫——守卫语义不变,守卫通过后的删除才墓碑。

### 4. 镜像协调(bound_mirror)

- refreshModule 各模块的 delete-all 改为**排除 pending**(delete where syncState != 'pending');rebuild 插入遇同 id 且 pending 的行**跳过**(保本地内容)。单设备语义注释。
- **在线全 synced 场景行为逐位不变**(delete 条件对 synced 行等价于 delete-all;断言钉)。

### 5. DAO 支持与查询

- `pendingOf(module)` 类查询(供 T3 收集器):各头表 DAO 增 `watchPending/getPending`(返回实体行);墓碑 DAO get/clear。

### TDD 测试

- 迁移:v2 库升级到 v3 加列默认 synced/墓碑表存在(drift migration 测试,照库内迁移测试先例找;无先例则 NativeDatabase 内存 + 手动 schemaVersion 步进)。
- pending:bound 路由写→pending;guest 写→synced;update 置回;复合写(还款/买入)头行 pending。
- 墓碑:bound 删→墓碑+行删;guest 删→无墓碑;账户守卫不变。
- 镜像:pending 行在 refreshModule 后内容/存在性不变;synced 行照常 rebuild;在线全 synced 快照等价。

## 验证(全部执行并贴证据)

1. 新单测绿(先红后绿)
2. `flutter test` 全量不回归(≥1325)
3. `flutter analyze` 新文件 0 条

## 约束

在线全 synced 路径逐位不变;不动同步管线(T3);drift schemaVer 生成物按库内惯例(build.yaml/手写 .g.dart?查库内先例——表改动后 .g.dart 如何再生,照办);中文注释;不 commit。完成后报告。
