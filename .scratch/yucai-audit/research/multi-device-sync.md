# 多设备同步调研 — 御财(YuCai)

**日期**:2026-07-26
**范围**:评估御财(单 Go server gRPC + ent + Postgres + Flutter 客户端,家庭多用户私域)的多设备同步方案
**方法**:WebSearch + 实际代码审查(server sync 模块已存在,client 无 counterpart)
**结论 TL;DR**:**Option A — 复用现有 server scaffolding + 自建 client 端 Drift/queue**(推荐 MVP);Option B(PowerSync)与 Option C(全 CRDT)在御财场景下投入产出比差。详见末尾。

---

## 0. 当前代码现状(关键背景,信源 = 本仓库 graphify/codegraph 审查)

调研前已确认:御财的 sync 模块**并非"schema 存在但实现空"**,而是**服务端已基本搭好、客户端完全缺失**的"半成品原型"。

### 服务端(已建)

| 层 | 文件 | 状态 |
|---|---|---|
| ent schema | `yucai/server/internal/sync/ent/schema/{sync_log,sync_conflict,sync_device}.go` | ✅ 3 表完整 |
| domain | `yucai/server/internal/sync/domain/{entity,valueobject,repository}.go` | ✅ `SyncLogEntry`/`SyncDevice`/`SyncConflict` + `ConflictResolution` VO |
| application | `yucai/server/internal/sync/application/{service,conflict,dto}.go` | ⚠️ service 6 个方法全在,但 `PushChanges` **未调用** `DetectConflict`,`conflicts` 永远 nil |
| adapter/driven | `yucai/server/internal/sync/adapter/driven/repository/sync_repo.go` | ✅ ent repo |
| adapter/driving | `yucai/server/internal/sync/adapter/driving/grpc/sync_handler.go` | ✅ 完整 gRPC handler |
| proto | `yucai/proto/sync/v1/sync.proto` | ✅ 已存在,Go + Dart stub 均生成 |
| wire | `yucai/server/wire/{providers,wire_gen}.go` | ✅ 已注入 |

**SyncLog schema(`sync_log.go:28-39`)**:
- `entity_type` / `entity_id` / `operation(create|update|delete)` / `payload(JSON bytes)` / `version(int64 per-tenant monotonic)` / `device_id`
- 索引:`(tenant_id, version)` + `(tenant_id, entity_type, entity_id)`
- 这就是**游标拉取 + append-only change log** 的标准 shape,与 Actual Budget 的 message log 同构(只是 Actual 是字段级,御财是行级)

**SyncConflict schema(`sync_conflict.go:28-41`)**:`server_payload` / `client_payload` / `resolution(pending|server|client|merged)` / `resolved_at`,带 `(tenant_id, resolution)` 索引 — 冲突待审栈已就位。

### 客户端(缺失)

- ❌ 无 `yucai/client/lib/sync/` 目录(无 domain/data/presentation 任一层)
- ✅ Dart stub `yucai/client/lib/proto/sync/v1/sync.pb.dart` **已存在**(说明 proto regen 过,只是没人调它)

### 现有实现的硬伤(不论选哪个方案都要先修)

1. **`PushChanges` 不做冲突检测**(`service.go:67-101`):`var conflicts []ConflictDTO` 声明后从不赋值,注入的 `resolver` 字段未使用 — `DetectConflict` 是死代码。
2. **版本号分配非原子**(`service.go:73-85`):`LatestVersion()` → `+1` → `Append` 三步分离,两设备并发 push 会撞同一个 `version`。需改为 Postgres 序列或 `INSERT ... RETURNING version` 单语句。
3. **不写真实业务表**:PushChanges 只 append 到 `sync_log`,不 apply 到 account/transaction/... — 等于"只记日志不执行",客户端推上来的变更服务端实体表看不到。需要 transactional outbox 模式(见 Q3)或 apply 管线。
4. **GetSyncStatus 用 tenantID 当 deviceID**(`sync_handler.go:54` 注释明写 "placeholder"):需从 auth context 提取真实 device_id(目前 OIDC 不签发)。
5. **`mapError` 全部塌缩成 `codes.Internal`**(`sync_handler.go:237`):NotFound/FailedPrecondition/InvalidArgument 全丢,gRPC 客户端无法区分"冲突待解"与"网络错"。
6. **`ConflictResolver.Resolve` 是硬编码 server-wins**(`conflict.go:21-36`):update_update / create_create 一律 server 赢,无字段级合并。对金额字段合理(不可猜),对备注/标签字段过激。
7. **业务表无 `version`/`server_updated_at`**(memory `yucai-audit` 与全表 ent schema 确认):无法在 PushChanges 入口校验 `clientVersion < serverVersion → 拒绝`。memory 原话:"ent 无乐观锁(version 字段装饰性)"。
8. **PushChanges 不在事务里 apply 业务表**:即便补上 apply 步骤,如果 apply 与 sync_log append 不在同一 tx,server crash 会产生"业务表写了但日志没写" → 客户端永远拉不到这条变更。

**信源**(本仓库):`yucai/server/internal/sync/application/service.go`、`conflict.go`、`adapter/driving/grpc/sync_handler.go`、`domain/entity.go`、`ent/schema/*.go`(均经 codegraph 验证 verbatim on-disk)。

---

## Q1. Flutter desktop+mobile 多设备同步的主流架构

### 三大主流(2025 年共识)

| 架构 | 代表 | 适用场景 |
|---|---|---|
| **A. 中心化 server 权威 + 客户端缓存** | Firebase/Supabase + Flutter、Firefly III、Maybe、Pennylane | 数据有强一致性约束(金额、余额)、并发编辑少、信任服务器 |
| **B. 本地优先 + CRDT + 轻量 relay** | Actual Budget(Yjs-style 自研)、Linear、Notion | 频繁离线编辑、需自动合并、字段级协作 |
| **C. 混合(Postgres ↔ SQLite 同步层)** | PowerSync、ElectricSQL、Replicache | 想要 local-first 的开发体验但不想自研 CRDT |

### 家庭/小团队场景的最佳实践(多份行业资料一致)

- **简单 CRUD 用 A,频繁离线协作用 B,中间地带用 C**。
- **家庭理财 = 低并发 + 强金额一致性 + 信任自有服务器** → **架构 A 的子集:server 权威 + 客户端只读缓存 + 推改时短暂离线队列**。
- Flutter 官方架构文档推荐用 **repository/data layer 抽象同步**,让 UI 不感知 sync 细节 — 御财现有 DDD 四层(client `domain/data/presentation/core`)已天然 fit。
- 2025 越来越多产品走 "CRDT + 同步服务器" 的混合(不是纯 P2P),因为纯 P2P 不可靠。
- 关键提醒:CRDT 不适合需要维护跨字段不变量的数据(如"转账两侧必须平账") — Actual Budget 作者 Long 明确说 "no ability to enforce cross-field invariants since messages can be dropped or arrive independently",对御财 transaction 双账是硬伤。

**信源**:
- [Flutter Architectural Overview](https://docs.flutter.dev/resources/architectural-overview)
- [Flutter Common Architecture Concepts](https://docs.flutter.dev/app-architecture/concepts)
- [Reddit r/FlutterDev: How should I design data synchronization for a mostly offline Flutter app?](https://www.reddit.com/r/FlutterDev/comments/1uy2rur/how_should_i_design_data_synchronization_for_a/)
- [Best CRDT Libraries 2025 — Velt](https://velt.dev/blog/top-crdt-libraries-for-real-time-data-sync)
- [Local-First Software: Principles, Patterns, and Technologies — wal.sh](https://wal.sh/research/local-first)
- [The Secret Life of a Local-First Value — marco bambini](https://marcobambini.substack.com/p/the-secret-life-of-a-local-first)(SQLite 内追踪 INSERT/UPDATE/DELETE)
- [Designing Bidirectional Data Sync for Offline-First Flutter Apps — Medium](https://medium.com/@janvi34334/how-i-implemented-bidirectional-data-sync-in-a-flutter-retail-app-060aa2f69c9f)

---

## Q2. 并发编辑冲突解决:哪种策略适合家庭理财?

### 五种策略对比

| 策略 | 优点 | 缺点 | 理财场景适配 |
|---|---|---|---|
| **乐观锁(version 字段)** | 检测冲突不阻塞;高吞吐;语义清晰 | 需重试逻辑;冲突多时退化 | ✅ 适合 — 家庭并发极低,几乎不会触发 |
| **Last-Write-Wins(LWW)** | 实现最简 | **静默丢更新** — 金融数据不可接受 | ⚠️ 仅适合备注/标签,不适合金额 |
| **字段级 merge** | 精细,不丢字段 | 需每字段定义合并规则;复杂度高 | ✅ 适合备注/标签/分类,不适合金额 |
| **CRDT(Yjs/Automerge)** | 数学保证收敛,自动合并 | 数值型 CRDT 难(计数器有上限);失去跨字段不变量 | ❌ 过度 — 家庭场景编辑稀疏,CRDT 收益 << 复杂度 |
| **Operational Transformation(OT)** | 文本协作成熟(Google Docs) | 实现极复杂;非文本数据无优势 | ❌ 不适合结构化金融数据 |

### 行业共识(多份资料一致)

- **乐观锁是个人理财的甜点**:DynamoDB、System Design School、Modern Treasury 都把乐观锁列为"冲突罕见 + 数据完整性高"场景的首选。家庭理财天然冲突罕见(同一时刻两人编辑同一笔交易的概率极低)。
- **LWW 在金融数据上是反模式**:Dave Callan 的对比明确指出"LWW can silently lose updates — an important trade-off for financial data integrity"。
- **CRDT 在金额字段上有结构性问题**:Actual Budget 是业内 CRDT 典范,但作者 James Long 强调"even the chance to manually resolve doesn't make sense" — 他们靠的是 HLC 时间戳的 LWW 语义,而不是真正的"合并"。换句话说,**Actual Budget 实质上是字段级 LWW + CRDT 传输层**,不是数学合并。
- **Modern Treasury(fintech 视角)明确推荐乐观锁 + 悲观锁混合**:账户余额/转账用悲观(避免双花),普通字段编辑用乐观。御财 transaction 双账是 transfer,Server-side 已在 application 层用 tx 保证两侧同时生效 — 多设备同步不破坏这个不变量。

### 御财推荐

- **金额/交易/账户余额**:乐观锁(server 版本号 + UPDATE ... WHERE version = ?),冲突时 server 权威,**永不静默合并**(用户必须看到"对方刚改了这笔,你的改动基于旧版,请决定")。
- **备注/标签/分类**:字段级 merge(取最新非空字段)或 LWW-by-HLC。
- **CRDT/OT**:明确**不采用**。家庭场景编辑稀疏,CRDT 投入产出比极差,且会破坏 transaction 双账不变量。

**信源**:
- [Optimistic Locking with Version Number — Amazon DynamoDB](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/BestPractices_OptimisticLocking.html)
- [Last Write Wins versus Optimistic Concurrency — Dave Callan](https://www.linkedin.com/posts/davidcallan_last-write-wins-versus-optimistic-concurrency-activity-7474059390703075329-98Xl)
- [Pessimistic Locking vs. Optimistic Locking — Modern Treasury](https://www.moderntreasury.com/learn/pessimistic-locking-vs-optimistic-locking)
- [Understanding Optimistic Locking — System Design School](https://systemdesignschool.io/blog/optimistic-locking)
- [Optimistic Locking Implementation — OneUptime](https://oneuptime.com/blog/post/2026-01-30-optimistic-locking-implementation/view)
- [Actual: Using CRDTs in the Wild — James Long](https://archive.jlongster.com/using-crdts-in-the-wild)(字段级 CRDT 实质是 LWW 的明确陈述)

---

## Q3. 离线编辑 + 重连同步:outbox / client queue / conflict UI

### 服务端:Transactional Outbox 模式(微服务经典)

**问题**:写业务表 + 发事件到 broker/同步日志,两步无法放同一分布式事务 → 任一崩溃会"业务表写了,事件丢了"。

**方案**:
1. 业务变更 + 一条 `outbox`/`sync_log` 行写入**同一数据库事务**。
2. 独立的 publisher 进程(或 CDC 工具如 Debezium 读 Postgres WAL)读 outbox,推到 broker / 通知客户端拉取。
3. 消费端**幂等处理**(可能重复投递)。

**对御财**:Postgres 已在用,业务表与 `sync_log` 同库 — outbox 模式天然 fit。当前 `PushChanges` 把 append 和 apply 分裂、且未 apply 业务表,正是 outbox 模式要解决的反面。修正:每个 domain service(account/transaction/...)的 Create/Update/Delete 在**同一 ent tx** 内 append 一条 SyncLogEntry,由 client pull-by-cursor 消费。无需额外 broker(gRPC PullChanges 充当投递通道)。

### 客户端:本地持久化 mutation queue

**主流实践**:
- 本地 SQLite(Drift/sqflite)做主存 + 一个 `pending_changes` 表存待推变更。
- 写入流程:**先写本地 DB + 入队 → 后台 sync worker 拉网推 → 失败指数退避重试 → 成功后出队**。
- UI:_pending 状态徽章("3 项待同步")、网络状态指示器。
- 幂等:服务端按 `(device_id, client_seq)` 去重,客户端按 `entity_id + version` 检测冲突。

**Flutter 现成包**:
- **`sync_queue_drift`**(pub.dev)— Drift/SQLite 持久化的 mutation queue + sync engine 核心,直接 fit 御财的 Drift 栈。
- **`flutter_offline_data_sync`**(pub.dev)— Hive/SQLite 双后端,但社区活跃度低。
- PowerSync + Drift + Riverpod 是 2025 生产级组合(dinkomarinac.dev 教程),但引入 PowerSync 服务依赖。

### Conflict Resolution UI 行业模式

- **Android 官方 offline-first 指南**:如果本地写与服务器"misaligned",**必须在 sync 前解决**冲突 — 不能静默覆盖。
- **三种 UI 策略**:
  1. **静默自动合并**(适合备注/标签):用户不感知,后台字段级 merge。
  2. **Toast + 选择**(适合偶发金额冲突):"对方刚改了这笔金额,保留 [你的 / 他的 / 取消]"。
  3. **冲突中心页**(适合批量):独立"待解决冲突"列表,类似 Git merge conflict UI — 御财已有 `ListConflicts` RPC 与 `SyncConflict.resolution=pending` 状态机,直接 fit。
- **Hacker News(Command Pattern 讨论)**:UI 必须保持响应,但**清晰警告"变更待同步,可能进入冲突"**,不能假装已落库。

**信源**:
- [Pattern: Transactional Outbox — microservices.io](https://microservices.io/patterns/data/transactional-outbox.html)
- [Transactional Outbox Pattern — AWS Prescriptive Guidance](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html)
- [The Transactional Outbox Pattern — James Carr](https://james-carr.org/posts/2026-01-15-transactional-outbox-pattern/)
- [Build an Offline-First App — Android Developers](https://developer.android.com/topic/architecture/data-layer/offline-first)
- [Offline-First Architecture from Zero to Production — Medium](https://medium.com/@ramadan123sayed/offline-first-architecture-from-zero-to-production-everything-you-need-to-know-about-the-strategy-2d5710ed9075)
- [Building Offline-First Flutter Apps with Drift — Medium](https://777genius.medium.com/building-offline-first-flutter-apps-a-complete-sync-solution-with-drift-d287da021ab0)
- [Building Local-First Flutter Apps with Riverpod, Drift, and PowerSync](https://dinkomarinac.dev/blog/building-local-first-flutter-apps-with-riverpod-drift-and-powersync/)
- [sync_queue_drift — pub.dev](https://pub.dev/packages/sync_queue_drift)
- [The Command Pattern for Offline Web Apps — Hacker News](https://news.ycombinator.com/item?id=13246187)
- [Designing for Offline-First: Conflict Resolution Strategies in .NET MAUI — shaunebu.com](https://shaunebu.com/Details/e3c6cc6d-05db-490f-9937-5c102e756754)

---

## Q4. 开源家庭理财/记账应用的同步实现

### 1. Actual Budget — CRDT 典范,与御财最可比

- **架构**:local-first,SQLite 本地 + 可选自托管 sync server(约 300 行代码的"瘦客户端"中继)。
- **核心机制**(作者 James Long 长文):
  - 所有数据拆成**字段级 message**(`dataset/row/column/value`),delete 是 tombstone。
  - `messages_crdt` 表与业务表并存("数据存两份",DB 约 16MB,tradeoff 划算)。
  - **HLC(Hybrid Logical Clock)** 给每条 message 一个全局唯一单调时间戳(`2019-06-06T16:40:53.876Z-0000-9f66d38cba0ef956`)。
  - **Merkle 树** 跟踪已 apply 的 message,客户端比较顶层 hash 定位分歧点,向服务器拉取该时刻后的所有 message。
  - message **可按任意顺序 apply**(交换律)。
- **领域特化决策**:
  - 字段级而非行级:某次 schema migration 改了 transaction 的某字段,不会与用户对其他字段的并发编辑冲突。
  - **"全手动解决冲突对预算 app 没意义"** — 用户期望"后来者赢"。这意味着实质上是**字段级 LWW**,CRDT 只是传输层。
  - **明确限制**:无 bulk UPDATE/DELETE(全走单条)、**无法保证跨字段不变量**(transaction 借贷必须平账这种)。
- **对御财的启示**:
  - 字段级 message 思路过激(御财 transaction 双账要平账,CRDT 不能保证)。
  - HLC + Merkle 树 + append-only log 思路 ✅ 值得借鉴 — 御财 `SyncLog(version int64 per-tenant monotonic)` 已是简化版(用整数 version 替代 HLC,因为单服务器权威不需要逻辑时钟)。
  - "数据存两份"的 tradeoff 在御财不必要 — 御财 server 是权威,客户端只是缓存,不需要 `messages_crdt` 镜像表。

**信源**:
- [Actual: Using CRDTs in the Wild — James Long](https://archive.jlongster.com/using-crdts-in-the-wild) ⭐ 最权威
- [Actual Budget — Syncing Across Devices(官方)](https://actualbudget.org/docs/getting-started/sync/)
- [The Actual Project Structure(官方)](https://actualbudget.org/docs/contributing/project-details/)
- [Actual Budget — 官网](https://actualbudget.org/)

### 2. Firefly III — 中心化 server 权威,无离线同步

- **架构**:PHP/Laravel,REST JSON API,per-user 数据隔离(无限用户,每人独立账本)。
- **同步**:无原生离线/多设备同步 — 客户端直连服务器 API,在线编辑。第三方"Nordigen/SimpleFin" importer 做 ETL 银行导入(单向)。
- **Webhooks**:支持事件订阅,可用于事件驱动同步管线。
- **对御财的启示**:这是"server 权威 + 在线优先"的典型 — 御财 server 已是此模型,加 client 缓存 + mutation queue 就能升级到"offline-capable server-authoritative"。

**信源**:
- [Firefly III — How to Use the API](https://docs.firefly-iii.org/how-to/firefly-iii/features/api/)
- [Firefly III — Multi-User Support](https://docs.firefly-iii.org/how-to/firefly-iii/features/multi-user/)
- [Firefly III — Data Importer Introduction](https://docs.firefly-iii.org/explanation/data-importer/introduction/)
- [Firefly III — API Reference](https://docs.firefly-iii.org/references/firefly-iii/api/)

### 3. Maybe Finance — 已停止 OSS 维护,无借鉴价值

- **状态**:2026 年 OSS 版**已停止维护**,团队 pivot 到 B2B。GitHub repo 标 "no longer maintained"。
- **架构**:Ruby on Rails + Postgres,Docker 自托管,**无离线/多设备同步**(纯在线 SaaS 模型)。
- **对御财**:无参考价值,不建议对标。Successor 项目 "Sure" 亦无新内容。

**信源**:
- [Maybe finance is shutting down the OSS app and pivoting to B2B — r/selfhosted](https://www.reddit.com/r/selfhosted/comments/1m8oavd/maybe_finance_is_shutting_down_the_oss_app_and/)
- [maybe-finance/maybe — GitHub](https://github.com/maybe-finance/maybe)

### 4. GnuCash — 无原生多设备同步(反面教材)

- **架构**:XML(默认)/ SQLite / MySQL / PostgreSQL 后端,桌面单机。
- **同步**:**无原生多设备同步**。
  - Android 与桌面 schema 不匹配,无法直接 DB sync(github issue #737)。
  - 移动端靠 **QIF 文件导出/导入**(手动工作流)。
  - 多用户场景需切到 MySQL/PostgreSQL 后端,SQLite/XML 并发访问有损坏风险。
- **对御财的启示**:GnuCash 是"文件时代"桌面应用的代表 — 御财已超前(自带 server + Postgres + gRPC),不应回头学其同步模式。

**信源**:
- [GnuCash — Storing Your Financial Data(官方)](https://www.gnucash.org/docs/v5/C/gnucash-guide/basics-files1.html)
- [GnuCash — Datamodel Transformations](https://wiki.gnucash.org/wiki/Datamodel_Transformations)
- [GnuCash Android — Database Sync Issue #737](https://github.com/codinguser/gnucash-android/issues/737)
- [Synchronizing GnuCash Mobile with Desktop — srcco.de](https://srcco.de/posts/synchronizing-gnucash-mobile-with-gnucash-desktop.html)

### 5. Pennylane — SaaS 多租户,架构不可对标

- **架构**:法国 B2B SaaS,双面平台(会计师事务所 + 客户端),中心化 Postgres + RBAC。
- **同步**:纯在线,无离线概念。多用户靠**角色权限 + 共享 schema**(admin/accountant/client/viewer)。
- **对御财的启示**:御财已有 OIDC + tenant_id 隔离(`TenantMixin`),Pennylane 的 RBAC 模型可借鉴(若未来扩到家庭多成员有不同权限),但同步机制无可参考。

**信源**:
- [Pennylane Data Sharing Documentation](https://data-sharing.pennylane.com/docs/en/pennylane/)
- [Pennylane Accounting Schema Documentation](https://data-sharing.pennylane.com/docs/en/accounting/)

### 横向对比表

| 应用 | 同步模型 | 离线 | 冲突解决 | 对御财的可借鉴度 |
|---|---|---|---|---|
| Actual Budget | CRDT(字段级 message + HLC + Merkle) | ✅ 完全离线 | 字段级 LWW(隐式) | ⭐⭐⭐ 思路(HLC/log/tombstone) |
| Firefly III | server 权威 REST + webhooks | ❌ 在线 | N/A(单用户/在线) | ⭐⭐ API 模型 |
| Maybe | Rails + Postgres(已停维) | ❌ | N/A | ⭐ 无 |
| GnuCash | 文件 / DB 后端,无原生同步 | 部分(SQLite) | N/A | ⭐ 反面教材 |
| Pennylane | SaaS 多租户在线 | ❌ | N/A | ⭐ 仅 RBAC 思路 |

---

## Q5. 御财现有 sync schema 的复用价值 + client counterpart 如何建

### 现有 schema 复用价值评估

| 组件 | 复用价值 | 评价 |
|---|---|---|
| **SyncLog** | ⭐⭐⭐⭐⭐ | **核心资产**,append-only + per-tenant monotonic version + entity_type/entity_id/operation/payload/device_id 是教科书级 change log 设计。与 Actual Budget message log 同构(行级 vs 字段级)。索引 `(tenant_id, version)` 即游标拉取。 |
| **SyncDevice** | ⭐⭐⭐⭐ | last_sync_version + last_sync_at 是 client cursor 的服务端镜像,完美。需补:device 公钥/Token、platform、app_version、user_id(目前只有 tenant_id)。 |
| **SyncConflict** | ⭐⭐⭐⭐ | server/client payload + resolution 状态机直接 fit 冲突中心页。需补:conflict_reason、merged_payload(若做字段级合并)。 |
| **proto + handler + service** | ⭐⭐⭐ | shape 对,但 service 实现有 7 处硬伤(Q0 已列),需修。 |
| **ConflictResolver** | ⭐⭐ | 死代码 + 硬编码 server-wins,需重写为按字段分类的策略表。 |

**结论**:御财不是"白纸上画 sync",而是"已搭好骨架,需要补 7 处硬伤 + 建客户端"。投入远低于"从零做"。

### Client 端 counterpart 建法(推荐路径)

按御财 client DDD 四层(`domain/data/presentation/core`)镜像 server:

#### 1. `client/lib/sync/domain/`
```dart
// entities
class PendingChange { String entityType; String entityId; SyncOp op; Uint8List payload; int clientSeq; }
class ConflictRecord { String id; String entityType; String entityId; Uint8List server; Uint8List client; String resolution; }
abstract class SyncRepository { /* queue/pull/resolve */ }
class SyncStatus { int lastSyncVersion; DateTime lastSyncAt; int pendingCount; int conflictCount; }
```

#### 2. `client/lib/sync/data/`
- **本地 Drift DB**(新增 `yucai/client/lib/core/database/` 或复用 sqflite):
  - `pending_changes` 表(client outbox):`entity_type, entity_id, op, payload, client_seq, status(queued|pushing|failed), retry_count, last_error`
  - `local_cache` 表(每实体的镜像):各实体字段 + `server_version` + `server_updated_at`
  - `sync_state` 表:`device_id, last_sync_version, last_sync_at`
- **SyncRemoteDataSource**:封装已生成的 `SyncServiceClient`(RegisterDevice/PushChanges/PullChanges/ListConflicts/ResolveConflict)
- **SyncRepositoryImpl**:协调 queue / remote / cache
- 复用现有 `GrpcClient` + `AuthRetryCaller._retry` 模式(`client/lib/core/network/grpc_client.dart`)

#### 3. `client/lib/sync/presentation/`
- **SyncCubit**(flutter_bloc):状态 = `SyncStatus`,事件 = `Online/Offline/StartSync/SyncDone/ConflictArrived/ResolveConflict`
- **SyncIndicatorWidget**:顶部徽章("3 待同步" / "离线" / "1 冲突待解")
- **ConflictListPage**:调 `ListConflicts`,渲染 server/client payload diff,按钮 [保留我的 / 用服务器 / 取消]
- **Injectable**:`@LazySingleton` 注入 SyncRepository / SyncCubit

#### 4. `client/lib/core/`
- **网络监听**:`connectivity_plus` 包监听 online/offline 触发 SyncCubit.StartSync
- **DI 注册**:在 `injection.config.dart` 加 sync 模块(镜像现有模块如 backup 的注册)
- **拦截器**(可选):在每个 remote_ds 的写入成功后,触发 SyncCubit.pull() — 或走纯后台 worker

### Server 端必修项(Q0 七伤,按优先级)

| # | 修复 | 优先级 |
|---|---|---|
| S1 | PushChanges 改为**单事务 apply 业务表 + append SyncLog**(outbox 模式) | P0 |
| S2 | 版本号分配改**原子**(Postgres `nextval(seq)` 或 `INSERT...RETURNING version`) | P0 |
| S3 | 业务表 ent schema 加 `version int64` + `server_updated_at`,UPDATE 带 `WHERE version = ?` | P0 |
| S4 | PushChanges 实际**调用 DetectConflict**,conflicts 不再是 nil | P0 |
| S5 | GetSyncStatus 从 auth context 提**真实 device_id**(OIDC claim 或 client 自注册) | P1 |
| S6 | `mapError` 分层:NotFound/FailedPrecondition/InvalidArgument/AlreadyExists | P1 |
| S7 | ConflictResolver 改**按字段分类**(金额 server-wins / 备注 LWW-HLC / 标签字段并集) | P2 |

---

## 御财推荐方案(2-3 选项 + 权衡 + 工作量)

### Option A:复用 server scaffolding + 自建 client Drift/queue ⭐ **推荐 MVP**

**做什么**:
- 服务端:修 Q0 的 7 伤(P0 四项必须,P1 两项强烈建议,P1 S7 视产品决策)
- 客户端:建 `client/lib/sync/` 四层(domain/data/presentation/core),Drift 持久化 queue + cache,SyncCubit + SyncIndicatorWidget + ConflictListPage
- 同步策略:**server 权威 + 乐观锁 + 字段分类冲突**(金额永不静默合并)
- 协议:复用现有 `yucai/proto/sync/v1/sync.proto`,客户端 PullChanges 后台轮询/长连接(gRPC server-streaming 可后续加,先用 unary polling)

**优点**:
- ✅ **最大化已有投入**(server schema/handler/proto/dart stub 全部已存在,~80% 骨架可用)
- ✅ 保持 server 权威 → transaction 双账不变量、holding lot 完整性不受影响
- ✅ 无新外部依赖(不引入 PowerSync / Replicache / Yjs)
- ✅ 与现有 DDD 四层 + Injectable + flutter_bloc 范式完全一致
- ✅ 客户端可分阶段上:先做"在线模式 + 后台 pull",再加"离线 queue"

**缺点**:
- ❌ 需要给所有业务表 ent schema 加 `version` 字段 → migration(但本就是 audit 已识别的硬伤)
- ❌ Conflict UI 是真要写的产品决策(金额冲突如何展示、备注合并规则)

**工作量粗估**(1 名熟悉御财的开发):
| 阶段 | 内容 | 工时 |
|---|---|---|
| Server P0 修复 | S1-S4 + ent migration | 5-8 天 |
| Server P1 修复 | S5-S6 | 2-3 天 |
| Client domain + data(Drift schema、queue、remote_ds、repository) | 5-7 天 |
| Client presentation(SyncCubit、IndicatorWidget、ConflictListPage) | 4-6 天 |
| DI 接线 + 现有模块改造(transaction/holding remote_ds 写后入队) | 3-5 天 |
| 测试(widget test + e2e) | 3-5 天 |
| **合计** | | **3-5 周(15-25 工作日)** |

---

### Option B:PowerSync / ElectricSQL 托管同步层

**做什么**:
- 在 Postgres 前面架 PowerSync service(自托管 Docker),配置 sync rules(每 tenant 部分复制)
- 客户端用 `sqlite_async` + PowerSync Flutter SDK 替代自建 Drift queue
- 现有 ent schema 保留(同步规则读 Postgres 表)
- 现有 `sync_log`/`sync_conflict` 表**可保留作审计日志,但同步逻辑交给 PowerSync**
- 服务端 sync_handler / sync.proto / dart stub **基本作废**

**优点**:
- ✅ 客户端 queue / conflict / 离线重连全不用写(SDK 内置)
- ✅ PowerSync 已与 Supabase/Postgres 集成成熟,dinkomarinac 教程 + Serverpod 集成文档完整
- ✅ sync rules 灵活(按 tenant_id 行级过滤)

**缺点**:
- ❌ **丢掉现有 server scaffolding**(sync_handler.go / service.go / sync.proto / dart stub 全废,约 8 个文件 + ent 模块的代码价值归零)
- ❌ **新增运行时依赖**(PowerSync service 是单独容器,自托管需要维护)
- ❌ 商业授权(PowerSync 自托管免费但 cloud 收费;商业使用需查 license)
- ❌ sync rules 学习曲线 + 调试复杂(规则写错会沉默丢数据)
- ❌ ElectricSQL 虽全开源,但 2024 后活跃度下降,ElectricSQL ↔ PowerSync 之间还需要再选
- ❌ 与御财"client 直连 server、无中间服务"的架构哲学冲突

**工作量粗估**:
| 阶段 | 内容 | 工时 |
|---|---|---|
| PowerSync service 自托管部署 + sync rules 配置 | 3-5 天 |
| 客户端 sqlite_async + SDK 集成,替换 grpc 写入路径 | 5-8 天 |
| 现有业务模块改造(remote_ds 从 gRPC 改本地 sqlite + 后端靠 PowerSync) | 5-8 天 |
| 冲突策略配置 + UI(若需要) | 3-5 天 |
| 测试 + sync rules 调优 | 4-6 天 |
| **合计** | | **3-5 周(15-25 工作日)** |

**与 A 的对比**:工时相近,但 B **新增外部依赖 + 丢现有投入**,只在"客户端 sync 体验更丝滑(实时部分复制)"上略胜。家庭场景不需要实时,故 B 不划算。

---

### Option C:全 CRDT(Actual Budget-style)

**做什么**:
- 抛弃 server 权威模型,server 降级为 thin relay
- 自研字段级 CRDT message log + HLC + Merkle 树(或集成 Yjs/Automerge Go 端口)
- 业务表与 `messages_crdt` 表并存
- 客户端 SQLite 同样存 message log + apply 管线

**优点**:
- ✅ 真正 local-first,完全离线协作
- ✅ 数学保证最终收敛
- ✅ Actual Budget 开源代码可参考

**缺点**:
- ❌ **过度工程**:家庭 2-5 人,编辑稀疏,CRDT 收益 << 复杂度
- ❌ **破坏 transaction 双账不变量**(message 可独立到达 → 借贷可能暂时不平)
- ❌ **schema 演进极难**(Actual 作者明确说"hard";需要处理旧 schema message)
- ❌ 抛弃现有 ent + ent DDD 四层(server/domain/application/infrastructure 全要重设计)
- ❌ 需要每业务表存两份数据(16MB tradeoff 在御财多币种 + 多年历史下会膨胀)
- ❌ HLC + Merkle 自研周期长

**工作量粗估**:**2-3 个月(40-60 工作日)**,且伴随大量产品决策(每字段的 CRDT 类型选择)。

**与 A 的对比**:投入是 A 的 3-4 倍,收益却只在"高频协作"场景 — 御财不存在此场景。**不推荐**。

---

### 推荐与里程碑

**推荐 Option A**,理由:
1. 家庭理财 = 低并发 + 强金额一致性 + 已有 server 权威架构 — Option A 的设计匹配度满分
2. 现有 sync scaffolding(schema + handler + proto + dart stub)已是 Option A 的 shape,丢掉等于浪费既有投入
3. 无新外部依赖,符合御财"client 直连 server、无中间服务"哲学
4. 工作量(3-5 周)与 B 相近但产出更受控,远低于 C(2-3 个月)

**MVP 里程碑(分阶段降低风险)**:

| 阶段 | 范围 | 验收 |
|---|---|---|
| **M1: server P0 + 单实体 POC** | S1-S4 修复 + transaction 单实体 client 缓存 + PullChanges 后台 worker | 两设备编辑同一笔交易,后改者收到"version 冲突"提示 |
| **M2: 离线 queue** | client Drift pending_changes + PushChanges retry/backoff | 飞行模式下能编辑,落地后自动同步 |
| **M3: 冲突中心页** | ListConflicts/ResolveConflict 接 ConflictListPage | 金额冲突展示 server/client 双方,用户可选 |
| **M4: 全实体接入** | 把 account/debt/budget/goal/holding/currency/tag/template 全部走 client queue | 全模块多设备同步 e2e |
| **M5: 实时性增强(可选)** | gRPC server-streaming PushChanges(替代轮询) | 实时反映对方编辑 |

---

## 附录:关键术语速查

- **HLC(Hybrid Logical Clock)**:本地物理时间 + 逻辑计数器 + node ID,跨设备单调Comparable。Actual Budget 用于给 message 排序。
- **Merkle 树**:哈希树,比对根哈希快速定位分歧点。Actual Budget 用于高效同步。
- **Transactional Outbox**:同一 DB 事务内写业务表 + 事件表,避免双写丢失。
- **CRDT(Conflict-free Replicated Data Type)**:无需协调即可收敛的分布式数据结构,数学保证合并确定性。
- **OT(Operational Transformation)**:文本协作的变换算法(Google Docs),非结构化数据不用。
- **LWW(Last-Write-Wins)**:按时间戳取最新,简单但丢更新。
- **OCC(Optimistic Concurrency Control)**:乐观锁,version 字段检测冲突。
- **Cursor-based pull**:客户端记 `last_version`,服务端 `SELECT WHERE version > ?` 增量拉取 — 御财 `PullChanges(since_version)` 已是此模式。

---

## 信源汇总(按调研问题分组)

### Q1 — Flutter 多设备同步架构
- [Flutter Architectural Overview](https://docs.flutter.dev/resources/architectural-overview)
- [Flutter Common Architecture Concepts](https://docs.flutter.dev/app-architecture/concepts)
- [Modular App Architecture in Flutter 2025](https://www.200oksolutions.com/blog/modular-app-architecture-in-flutter-for-custom-software-projects-2025-edition/)
- [Reddit r/FlutterDev — offline-first sync design](https://www.reddit.com/r/FlutterDev/comments/1uy2rur/how_should_i_design_data_synchronization_for_a/)
- [Bidirectional Data Sync in Flutter — Medium](https://medium.com/@janvi34334/how-i-implemented-bidirectional-data-sync-in-a-flutter-retail-app-060aa2f69c9f)
- [Best CRDT Libraries 2025 — Velt](https://velt.dev/blog/top-crdt-libraries-for-real-time-data-sync)
- [Local-First Software Survey — wal.sh](https://wal.sh/research/local-first)
- [Synking all the things with CRDTs — dev.to](https://dev.to/charlietap/synking-all-the-things-with-crdts-local-first-development-3241)
- [The Secret Life of a Local-First Value — marco bambini](https://marcobambini.substack.com/p/the-secret-life-of-a-local-first)

### Q2 — 冲突解决
- [Optimistic Locking — DynamoDB](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/BestPractices_OptimisticLocking.html)
- [LWW vs Optimistic Concurrency — Dave Callan](https://www.linkedin.com/posts/davidcallan_last-write-wins-versus-optimistic-concurrency-activity-7474059390703075329-98Xl)
- [Pessimistic vs Optimistic Locking — Modern Treasury](https://www.moderntreasury.com/learn/pessimistic-locking-vs-optimistic-locking)
- [Optimistic Locking — System Design School](https://systemdesignschool.io/blog/optimistic-locking)
- [Optimistic Locking Implementation — OneUptime](https://oneuptime.com/blog/post/2026-01-30-optimistic-locking-implementation/view)
- [Stack Overflow — Optimistic vs Pessimistic Locking](https://stackoverflow.com/questions/129329/optimistic-vs-pessimistic-locking)

### Q3 — Outbox + Client Queue + Conflict UI
- [Transactional Outbox — microservices.io](https://microservices.io/patterns/data/transactional-outbox.html)
- [Transactional Outbox — AWS Prescriptive Guidance](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html)
- [Transactional Outbox Pattern — James Carr](https://james-carr.org/posts/2026-01-15-transactional-outbox-pattern/)
- [Build an Offline-First App — Android Developers](https://developer.android.com/topic/architecture/data-layer/offline-first)
- [Offline-First Architecture from Zero to Production — Medium](https://medium.com/@ramadan123sayed/offline-first-architecture-from-zero-to-production-everything-you-need-to-know-about-the-strategy-2d5710ed9075)
- [Offline-First Flutter Apps with Drift — Medium](https://777genius.medium.com/building-offline-first-flutter-apps-a-complete-sync-solution-with-drift-d287da021ab0)
- [Building Local-First Flutter Apps — Dinko Marinac](https://dinkomarinac.dev/blog/building-local-first-flutter-apps-with-riverpod-drift-and-powersync/)
- [sync_queue_drift — pub.dev](https://pub.dev/packages/sync_queue_drift)
- [Command Pattern for Offline Web Apps — HN](https://news.ycombinator.com/item?id=13246187)
- [Conflict Resolution in .NET MAUI — shaunebu.com](https://shaunebu.com/Details/e3c6cc6d-05db-490f-9937-5c102e756754)

### Q4 — 开源理财应用
- [Actual: Using CRDTs in the Wild — James Long](https://archive.jlongster.com/using-crdts-in-the-wild) ⭐
- [Actual Budget — Official](https://actualbudget.org/)
- [Actual Budget — Sync Docs](https://actualbudget.org/docs/getting-started/sync/)
- [Firefly III — API](https://docs.firefly-iii.org/how-to/firefly-iii/features/api/)
- [Firefly III — Multi-User](https://docs.firefly-iii.org/how-to/firefly-iii/features/multi-user/)
- [Maybe Finance — GitHub(archived)](https://github.com/maybe-finance/maybe)
- [GnuCash — Storing Financial Data](https://www.gnucash.org/docs/v5/C/gnucash-guide/basics-files1.html)
- [GnuCash Android Sync Issue #737](https://github.com/codinguser/gnucash-android/issues/737)
- [Pennylane Data Sharing Docs](https://data-sharing.pennylane.com/docs/en/pennylane/)

### Q5 — Postgres ↔ SQLite 同步层
- [PowerSync vs ElectricSQL — PowerSync Blog](https://powersync.com/blog/electricsql-electric-next-vs-powersync)
- [Introducing ElectricSQL v0.6](https://electric.ax/blog/2023/09/20/introducing-electricsql-v0.6)
- [PowerSync: Offline-First Sync for Postgres — QueryPlane](https://queryplane.com/blog/powersync-offline-first-sync/)
- [PowerSync + Supabase — PowerSync Blog](https://powersync.com/blog/offline-first-apps-made-simple-supabase-powersync)
- [Serverpod + PowerSync Integration](https://docs.powersync.com/integrations/serverpod)
- [Demystifying Flutter's Local DB Options — PowerSync](https://powersync.com/blog/flutter-local-database-options)
- [sqlite-sync(CRDT-based)— GitHub](https://github.com/sqliteai/sqlite-sync)

### 本仓库代码(graphify / codegraph 审查,信源 = verbatim on-disk)
- `yucai/server/internal/sync/ent/schema/{sync_log,sync_conflict,sync_device}.go`
- `yucai/server/internal/sync/domain/{entity,valueobject,repository}.go`
- `yucai/server/internal/sync/application/{service,conflict,dto}.go`
- `yucai/server/internal/sync/adapter/driving/grpc/sync_handler.go`
- `yucai/server/internal/sync/adapter/driven/repository/sync_repo.go`
- `yucai/proto/sync/v1/sync.proto`
- `yucai/client/lib/proto/sync/v1/sync.pb.dart`(已生成,无人调用)
