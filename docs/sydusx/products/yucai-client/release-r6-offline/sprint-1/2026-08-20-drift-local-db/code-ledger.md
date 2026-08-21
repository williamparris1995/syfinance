# Code Ledger — feature A drift 本地库落地

| task | status | fix-rounds / rulings |
|---|---|---|
| T1 tables+database+build | done | 2 轮修复:`lazyDatabase()` 函数在 drift 2.33 已变为 `LazyDatabase` 类;`generate_connect_constructor: true` 是死配置(drift 从未用过)致 unused 警告 → 移除 |
| T2 DAO ×10 | done | 1 轮修复:tag_dao `Selectable.map` 语义是逐行映射(非列表) |
| T3 DI 注册 | done | injection.dart 手动 `registerLazySingleton<AppDatabase>`(ADR-5);AppDatabase 惰性打开,注册零开销 |
| T4 内存库单测 | done | 2 轮修复:①SQLite 外键默认关 → `beforeOpen` PRAGMA foreign_keys=ON(级联依赖);②drift/matcher 的 isNull/isNotNull 冲突 + `'$'` 插值 + companion 经 app_database 再导出致 tables import 冗余(dart fix 清理)。**20/20 绿** |
| T5 基线+提交 | done | localdb analyze 0 issue;全套 +1001 -4,4 失败=2 基线文件(3)+receivables_page(1) |

## Rulings

1. **path_provider ^2.1.4 新增依赖**:FR-1 文件库需要 app 数据目录;经 `LazyDatabase` 惰性解析,DI 注册保持同步(design 未指定路径机制,implementation 补齐)。
2. **hook baseline 名单 +receivables_page_test.dart**:该失败在无本 feature 改动的基线上同样复现(git stash 对比,2026-08-21),属 main 既有漂移;按 hook 自身哲学(known drift pass / NEW fails block)入名单,证据记 verify-commit.ps1 注释。
3. **build.yaml 移除 `generate_connect_constructor`**:drift 从未使用时的预留死配置,生成物引发 unused 警告(NFR-1 冲突);保留 `store_date_time_values_as_text: true`(ADR-6 时间 TEXT 形态)。

## Deferred(非本 feature scope)

- 引用数据 seed 机制 / 派生快照写路径 / IsSystem 预置 → design open questions 1-3,归 feature C/E。
- main 的 receivables_page_test 既有失败本体 → 独立债务,不混入本 feature 分支。

## Review(2026-08-21,two-axis,pass)

- Standards:0 HARD;2 Minor(DAO CRUD 五件套重复=ADR-4 可接受;ChartOfAccounts 枚举 INT vs server 字符串,镜像时留意)+ **1 Important:hook 容忍名单(+receivables_page_test)与 conventions.md「3 fail/2 文件」基线分叉——失败系 main 既有(stash-compare 证实),但 MERGE 时必须同步 conventions.md 基线描述,否则 enforcement 与 single source 永久不一致**。
- Spec:FR-1..FR-6 / NFR-1..NFR-2 全 ✓(契约映射字段级核对无遗漏;NFR-2 零 server 文件实测)。
- verdict:**pass** → 进 sydusx-test。

## Test(2026-08-21,pass)

- 20/20 绿;**DAO+database 逻辑行覆盖 165/187 = 88.2%**(tables 声明式列声明不计行,行为覆盖经全表写入/查询回环);review 后补齐 6 模块 update 断言(CRUD 之 U)。
- Requirement coverage:FR-1✓(schema 建库测试+内存库) FR-2✓(映射表 design + review 字段级核对) FR-3✓(UUID TEXT PK 全表+断言) FR-4✓(DI 同实例) FR-5✓(onCreate 机制+骨架) FR-6✓(20 测试秒级) NFR-1✓(全套基线内+analyze 0) NFR-2✓(零 server diff)。
- Deferred integration:文件库 path_provider 启动链路(零调用方阶段无可观察面)→ feature C seam;e2e → feature I。
