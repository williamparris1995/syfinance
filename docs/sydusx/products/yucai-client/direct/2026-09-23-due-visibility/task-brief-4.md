# Task T4 — 收件箱页(InboxPage + /inbox 路由 + target 解码)

项目:御财 Flutter 客户端 `yucai/client/`(design-v2,语义令牌 `context.yucai` 零裸色)。
照 `docs/sydusx/products/yucai-client/direct/2026-09-23-due-visibility/` 下 spec.md
(FR-5/6/7)/design.md(ADR-3/6,LLD)执行。T1/T2 已交付:
- `InboxStore`(`core/notifications/inbox/inbox_store.dart`):activeEntries()/all()/
  readLastSeen()/writeLastSeen();drift 行类 `InboxEntry`(entryKey/type/title/
  amountCents/dueDate 文本/state[int:0 待处理/1 已处理/2 已挂失]/createdAt epochMs/
  handledAt?/targetKind[int:0 account/1 debt]/targetId);`InboxEntryState` 枚举。
- `DueCandidateProvider.stream`(候选变化时 InboxSyncer 已同步 diff 表)。
- `due_target.dart`:sealed DueTarget(AccountTarget(accountId)/DebtTarget(debtId))。

## 交付物

1. **target 解码**:在 `inbox_store.dart`(或 `due_target.dart`,择一)补
   `DueTarget decodeTarget(int targetKind, String targetId)`(0→AccountTarget/1→DebtTarget;
   未知值防御:抛 ArgumentError 带值,测试钉死)+ 单测。
2. **InboxPage**:新文件 `lib/inbox/presentation/pages/inbox_page.dart`(新模块目录,
   presentation-only,数据经 InboxStore/DueCandidateProvider)
   - **两区**:待处理区置顶(state=0,createdAt 升序)、历史区沉底(其余,handledAt
     降序)。每区小标题。
   - **条目行**:title · ¥金额 · 「X 天后到期/逾期 N 天」(由 dueDate 与今日算,
     复用 `DueReminderPolicy.daysBetween` 同口径)· 三态 tag(待处理/已处理/已挂失,
     语义令牌着色;已处理/已挂失行整体降不透明度)。
   - **小圆点**:仅待处理区,`createdAt > lastSeen` 的行加视觉点(语义色,样式照
     库内既有圆点/徽标范式;无既有范式则 8px 圆,注释说明)。
   - **lastSeen 写入**:页面首帧渲染后(postFrameCallback)writeLastSeen(now)——
     先读后写,保证本次打开仍能看到点,下次打开消失。
   - **行点击直达**:decodeTarget → AccountTarget 唤起还款对话框(需要账户对象与
     全量列表——本页从账户 repository 查,照 accounts_page 既有取数习惯;
     若本页无现成依赖,可改为跳转该账户详情页 `/accounts/:id` 并注释裁决——
     还款入口在详情页同样可达,AGENTS 复用第一)· DebtTarget → `/debts/:id`。
   - **数据刷新**:订阅 DueCandidateProvider.stream → 重读 store.all();dispose 取消。
   - 空态:两区皆空 → 居中友好空文案(照库内空态范式)。
3. **路由**:改 `lib/app/router.dart`:加 `/inbox`(照库内既有平级页面路由的
   嵌套与守卫习惯;app shell 内,宽窄屏表现同其他页)。

## TDD(强制)

widget/单元测试:两区排序与分界/三态 tag 文案与着色/小圆点出现与消失(lastSeen
读写时序)/行点击直达分派(两种 target)/空态/target 解码(含未知值)/路由注册冒烟。

## 完成门

1. `flutter test test/inbox test/core/notifications/inbox`(新测试+既有全绿)
2. `flutter analyze` 净增 0
3. 最终回复:文件清单、测试数字、直达的具体裁决(对话框 vs 详情页)及理由、偏离裁决。
