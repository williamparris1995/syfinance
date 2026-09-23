# Task T1 — 数据层地基(DueTarget + InboxEntries + InboxStore)

你是本 feature 的实现者之一。项目:御财个人理财,Flutter 客户端在 `yucai/client/`
(flutter_bloc + drift;完整规范见仓库根 `CLAUDE.md` 与 `AGENTS.md`)。本任务照
`docs/sydusx/products/yucai-client/direct/2026-09-23-due-visibility/` 下 spec.md/design.md
执行(先读这两份,LLD 契约以 design 为准)。

## 交付物

1. **DueTarget(sealed)**:新文件 `lib/core/notifications/due_target.dart`
   - `sealed class DueTarget`;子类 `DueTargetAccount(String accountId)` /
     `DueTargetDebt(String debtId)`(命名可按库内习惯微调,但语义必须一一对应)。
   - `DueScheduleEntry`(`lib/core/notifications/due_scanner.dart`)增加必填字段
     `final DueTarget target;`,构造函数与两处数据源同步补填:
     - `drift_due_source.dart`:join 行已有 `debts.id` → `DueTargetDebt`
     - `credit_card_due_source.dart`:构造处持 accountId → `DueTargetAccount`
   - 修复既有引用该构造的测试(编译错逐个补 target 参数,用合理假值)。
2. **InboxEntries 表**:新文件 `lib/core/localdb/tables/inbox_tables.dart`
   ```dart
   class InboxEntries extends Table {
     IntColumn get id => integer().autoIncrement()();
     TextColumn get entryKey => text()();      // 候选 entryId(期次裸 id / cc:acc:yyyy-MM)
     TextColumn get type => text()();          // 恒 'due_reminder'(类型预留)
     TextColumn get title => text()();
     IntColumn get amountCents => integer()();
     TextColumn get dueDate => text()();       // yyyy-MM-dd
     IntColumn get state => integer()();       // 0 待处理/1 已处理/2 已挂失
     IntColumn get createdAt => integer()();   // epochMs
     IntColumn get handledAt => integer().nullable()();
     IntColumn get targetKind => integer()();  // 0 account/1 debt
     TextColumn get targetId => text()();
     @override Set<Column> get primaryKey => {id};
     @override List<Set<Column>> get uniqueKeys => [ {entryKey} ];
   }
   ```
   - `app_database.dart`:tables 列表注册 + `schemaVersion` 10→11 +
     `if (from < 11) await m.createTable(db.inboxEntries);`(照 v9→v10 注释风格加中文注释)。
   - codegen:`cd yucai/client && dart run build_runner build --delete-conflicting-outputs`
   - 提交前 `git status` 核对 `.g.dart` 真 diff(仓库有已知幻影 CRLF 现象:显示 M 但 diff 空的
     文件不要动它们)。
3. **InboxStore**:新文件 `lib/core/notifications/inbox/inbox_store.dart`
   - 构造注入 `AppDatabase`。方法(名字可微调):
     - `Future<List<InboxRow>> activeEntries()`(state=0,createdAt 升序)
     - `Future<List<InboxRow>> all()`(历史含待处理,便于页面两区一次取)
     - `Future<void> upsertActive({required entryKey, title, amountCents, dueDate, target})`
       (存在 entryKey 且 state≠0 时**不复活**(滚动老条目已定态就不动);
       state=0 时更新 title/amountCents/dueDate;不存在则插入 state=0,createdAt=now)
     - `Future<void> settle(String entryKey, {required int state})`(→1 或 2,写 handledAt;
       仅对 state=0 生效)
     - `Future<DateTime?> readLastSeen()` / `Future<void> writeLastSeen(DateTime)`
       (AppMeta 键 `inbox_last_seen` 存 epochMs;AppMeta 表已存在,看 `lib/core/localdb/tables/app_meta.dart` 的用法)
   - `InboxRow` 为 store 暴露的行模型(或直接用 drift 生成类,二选一,注释说明)。

## 约束

- 中文注释(文件头 library 注释 + 每个公开成员一句话),风格照
  `reminder_dismissal_store.dart`/`reminder_tables.dart` 现有写法。
- 不动 `due_scanner.dart` 的扫描/去重逻辑(只加字段);不动 tray/settings/页面。
- state 常量用库内枚举或 const int + 注释,与 due_reminder_policy.dart 的 DueTier 风格协调。

## TDD(强制)

每个行为先写测试再实现(RED→GREEN),测试放 `test/core/notifications/inbox/` 与
`test/core/localdb/`(照现有目录组织;drift 测试范式参考既有 reminder/表迁移测试怎么建内存库)。
必测:迁移 v10→v11 建表;upsert 幂等(同 entryKey 不重复插);state=0 更新字段;
settle 后 upsert 不复活;lastSeen 读写往返。

## 完成门

1. `cd yucai/client && flutter test test/core/notifications/inbox test/core/localdb`(新测试全绿)
2. `flutter analyze`(不得新增告警;基线 437±少量,若新增修掉)
3. `git status` 只含本任务文件(+生成 .g.dart),把改动文件清单与测试输出摘要写在最终回复里。
