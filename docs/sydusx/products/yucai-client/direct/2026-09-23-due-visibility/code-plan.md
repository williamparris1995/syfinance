# 到期事项常显提醒 — code-plan

> execute 任务分解(照 design HLD/LLD)。直落 main(ADR-8);TDD(sydusx-tdd);
> 依赖序:T1→T2→(T3∥T4)→T5→T6;T3/T4 文件不相交可并行,bootstrap 装配统一收在 T5 防冲突。

## Tasks

- [x] **T1 数据层地基**(core/localdb + core/notifications)
  DueScheduleEntry 扩展 target(sealed DueTarget:AccountTarget/DebtTarget,两源各自填);
  InboxEntries 表(v10→v11 仅建表,build_runner codegen);InboxStore(CRUD+entryKey 唯一
  upsert+lastSeen 经 AppMeta);测试:表迁移+store 读写/upsert 幂等。
  文件:`core/notifications/due_scanner.dart`(entry 扩展)、`due_reminder_policy.dart` 邻位
  `due_target.dart`、`core/localdb/tables/inbox_tables.dart`、`core/notifications/inbox/inbox_store.dart`。
- [x] **T2 读侧候选流**(core/notifications)
  DueCandidateProvider(watch 流复用 bootstrap 集{accounts,transactions,
  paymentScheduleEntries,reminderDismissals,debts} 防抖 500ms → 双源候选 → 挂失过滤 →
  Stream<List<DueCandidateView>>);InboxSyncer(diff:入窗 upsert state=0/消失定态——挂失表
  在→2,否则→1,ADR-3)寄宿管道尾;同源契约测试(同 fixture 两管线同候选集,R1)。
  文件:`due_candidate_provider.dart`、`inbox/inbox_syncer.dart` + 测试。
- [x] **T3 首页聚合条**(account 模块)
  DueBanner widget(收起=callout 行范式聚合文案「⏰ N 笔待还 · 最近 X 天后」/逾期子句前置;
  展开=明细行[色条/名称/金额/到期],F37 桶着色,行点击直达[Account→showCreditCardRepayDialog
  需查账户对象/Debt→/debts/:id],尾「查看全部」→/inbox;空态不渲染;宽窄屏;context.yucai
  零裸色);accounts_page ListView 首项(hero 前)接线;widget 测试(空态/聚合/展开/着色/直达)。
  文件:`account/presentation/widgets/due_banner.dart`、`pages/accounts_page.dart` 改 + 测试。
- [x] **T4 收件箱页**(inbox 模块 + router)
  InboxPage(两区:待处理置顶含小圆点[createdAt>lastSeen]/历史沉底;三态 tag;条目同 T3 直达;
  打开即写 lastSeen);/inbox 路由(挂 app shell);widget 测试(两区/三态/小圆点消失)。
  文件:`inbox/presentation/pages/inbox_page.dart`、`app/router.dart` 改 + 测试。
- [x] **T5 托盘行 + 装配**(core/notifications + bootstrap)
  TrayHeadData +dueCount/dueNearestDays(可空);buildContextMenu 数据头区待还行(无候选
  不显示/不跟 showTrayAmounts/fail-safe 行消失);托盘菜单项「提醒中心」(show+go /inbox);
  bootstrap 装配 DueCandidateProvider+InboxSyncer+headProvider due 字段;guest 链路(全本地
  无门控);测试:tray 菜单组合/装配冒烟。
  文件:`tray_controller.dart` 改、`notifications_bootstrap.dart` 改 + 测试。
- [x] **T6 收官门**
  flutter test 全量绿(既有 1958+新增);flutter analyze 基线零新增;code-ledger 记录;
  提交(单 feature 一提交,详尽 message,v1.0.10 先例)。

## 验证纪律

每 task:RED→GREEN 即跑该测试文件;单元完跑相关套件;T6 全量+analyze;
3+ 文件未跑测试 = stop(execute Red Flags)。
