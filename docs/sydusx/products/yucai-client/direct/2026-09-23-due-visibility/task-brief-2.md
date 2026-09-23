# Task T2 — 读侧候选流(DueCandidateProvider + InboxSyncer)

项目:御财 Flutter 客户端 `yucai/client/`。照
`docs/sydusx/products/yucai-client/direct/2026-09-23-due-visibility/` 下 spec.md/design.md
执行(重点:ADR-1/ADR-3、R1、LLD「InboxSyncer 伪代码」节)。T1 已交付(可直接消费):
`core/notifications/due_target.dart`(sealed DueTarget)、`DueScheduleEntry.target` 字段、
`core/localdb/tables/inbox_tables.dart`、`core/notifications/inbox/inbox_store.dart`
(InboxStore:activeEntries/all/upsertActive/settle/lastSeen;`InboxEntryState{pending,handled,dismissed}`)。

## 交付物

1. **DueCandidateProvider**:新文件 `lib/core/notifications/due_candidate_provider.dart`
   - 构造注入(照 TrayController 注入范式):`List<Stream<void>> changeTriggers` +
     `DueScheduleSource source` + `ReminderDismissalStore dismissalStore` +
     `DueReminderConfig Function() configProvider` + `InboxSyncer? syncer`(可空:测试可不挂)。
   - 行为:任一 trigger 发射 → 防抖 500ms(照既有防抖范式)→ 拉源候选 → 挂失过滤
     (dismissalStore.dismissedEntryIds)→ 映射 `DueCandidateView` → 广播;启动时先发一次初始值。
   - `DueCandidateView { String entryKey; String title; int amountCents; DateTime dueDate;
     DueTier tier; int daysLeft; /*负=逾期天数*/ DueTarget target; }`
     ——tier/daysLeft 用 `due_reminder_policy.dart` 既有分档逻辑(同口径,勿另写一套)。
   - 对外:`Stream<List<DueCandidateView>> get stream` + `List<DueCandidateView> get latest` +
     `Future<void> start()`/`Future<void> dispose()`(命名可微调;banner/托盘/收件箱三消费方共用)。
   - 时钟可注入(照 CreditCardDueSource 先例,测试确定性)。
2. **InboxSyncer**:新文件 `lib/core/notifications/inbox/inbox_syncer.dart`
   - `diff(List<DueCandidateView> candidates)`(design LLD 伪代码):
     现有 active(ystore.activeEntries)与候选集对比 → 新 entryKey upsert;消失的定态
     (查挂失表在→dismissed,否则→handled,ADR-3)。挂失表查询用 ReminderDismissalStore。
   - 只消费 InboxStore + dismissalStore,无 UI 依赖。
3. **共享口径 + 同源契约测试(R1 缓解,重点)**:
   - 把「源候选 → 挂失过滤」这步从 DueScanner 内部提取为共享纯函数(如
     `filterActiveCandidates(raw, dismissedIds)`,放 due_scanner.dart 或独立文件),
     scanner 与 provider **都调它**(scanner 改为调用提取函数,行为逐字不变——
     既有 scanner 测试不改断言全绿即证明)。
   - 契约测试:同一 fixture(假源+假挂失集)分别走 scanner 路径与 provider 路径,
     断言候选集一致。

## 约束

- 中文注释照库内风格;**不改 scanner 任何可观察行为**(FR-8:既有 scanner/policy 测试断言零改动);
- 不碰 bootstrap 装配(T5 收);不碰 UI。

## TDD(强制)

必测:provider 初始值/防抖合流/挂失过滤/tier·daysLeft 映射;syncer 入箱 upsert·消失定态
(挂失→2、滚动/还清→1)·幂等(重复 diff 不重复插);同源契约测试;
scanner 行为零变化(既有测试全绿)。

## 完成门

1. 新测试 + `flutter test test/core/notifications`(含既有 scanner/policy 测试全绿)
2. `flutter analyze` 净增 0
3. 最终回复:文件清单、测试数字、契约测试的断言形态、偏离裁决。
