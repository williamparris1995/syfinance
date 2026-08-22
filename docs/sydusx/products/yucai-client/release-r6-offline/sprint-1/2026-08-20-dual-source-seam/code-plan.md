# Code Plan — feature C 双源 seam + account 试点

> 消费 spec+design(均 confirmed)。inline 模式(单模块试点 + core 两小件)。

## Tasks

- [x] **T1 SessionModeTracker**(core/session_mode,默认 guest)+ injection 手动注册。
- [x] **T2 AuthBloc 接 tracker**:构造 +1 参 + onChange 单点同步;4 个测试文件的 seeded bloc 构造器机械补参(FR-4 边界:被改类自身的测试随构造器更新,记 ledger)。
- [x] **T3 AccountLocalDataSource**:行↔实体映射(index+1 枚举/parentId ''↔NULL/creditLimit 0↔NULL)+ create 默认值 + update patch + delete 余额校验(抛 ServerFailure 直通)。
- [x] **T4 repo 路由**:AccountRepositoryImpl 构造 +local +tracker,每方法 `isGuest ? local : remote`;_guard 加 `on Failure` 直通分支(远端路径行为不变)。
- [x] **T5 测试**:tracker 单测 / local ds 内存库单测(CRUD+映射+写语义)/ repo 路由测试(fake 双 ds+tracker 两态)/ 既有 account·auth·router 全绿;全套基线(4 fail/3 文件)+ analyze 不新增 → commit。

## 约定

- 注释英文仅记约束;local ds 失败以 core Failure 抛出(经 _guard 直通)。

## 执行记录(2026-08-22)

- 全套 +1028 -4(=基线 4,零新增);analyze 394 < main 基线 398(dart fix 顺带清了触碰测试文件的预存 lint)。
- 修复轮:update patch 语义初稿 Value('') 会清空字段 → 改 absent-aware(str/nonZero/orAbsent);drift 行类 `Account` 与 domain 实体同名 → app_database `as db` 前缀限定;Change 单类型参数(bloc 8.x);sede 误跑 main 污染 4 测试文件 → 即时 checkout 回滚并在 worktree 重做(教训:多 worktree 下先 pwd 再批量 sed)。
- FR-4 边界注记:AuthBloc/AccountRepositoryImpl 构造器扩展,其直接单测的构造行随之更新(被改类自身的测试,不属于「无感」面);bloc/usecase/page 测试断言零改动。
