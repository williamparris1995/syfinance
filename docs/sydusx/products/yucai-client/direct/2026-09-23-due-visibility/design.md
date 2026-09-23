# 到期事项常显提醒 — design

> 直落 feature,2026-09-23。spec 见同目录 spec.md(grill 六决策)。
> 本 design grill 三决策(管线分叉/消失语义/prototype)见 ADR-1/3/7 挑战记录。
> prototype: none —— 三面零新视觉词汇(聚合条=callout 警示条范式+F37 着色;收件箱页=标准
> 两区列表页同构设置/备份页;托盘行=F25 菜单行原样式),布局契约由 LLD 钉死;用户拍板
> (F41 prototype:none 先例)。

## Context

v1.0.10 已有:DueScanner 写侧管线(双源 DriftDueSource/CreditCardDueSource → policy 分档 →
挂失过滤 → 桶去重 → toast),ReminderDismissals 挂失表(entryId 主键,权威),F25 托盘
TrayHeadProvider 缝 + buildContextMenu,accounts/reminderDismissals watch 流(500ms 防抖)。
本 feature 在其上加**读侧展示管线**与**收件箱台账**,写侧逐字不动(FR-8)。

## Goals / NonGoals

**Goals**:读侧统一候选流(三消费方);首页聚合条;收件箱页+表;托盘待还行;路由与入口接线。
**NonGoals**:不改通知行为;不加提醒来源;不加第四态;无侧栏/标题栏入口;无已读未读模型。

## Decisions(ADRs,含 grill 挑战/辩护)

### ADR-1 读侧候选流与写侧 scanner 并存,共享 source+dismissal,分叉于去重

- **决策**:新建 `DueCandidateProvider`(watch 驱动 → 双源候选 → 挂失过滤 → 广播视图)。
  banner/托盘/收件箱待处理区三消费方共此一流;`InboxSyncer` 寄宿管道内同步 diff。
- **备选**:B 复用 DueScanner 加回调(定时驱动刷新慢,去重状态搅进 UI);C 各页面自查
  (口径三处复制必漂移)。
- **grill**:两套管线口径漂移?→ 辩护:候选口径(什么算一条待办)完全由共享层
  (source+configProvider+dismissal)定义,分叉仅去重/发送;**同源契约测试**钉死:同一
  fixture 两管线产出同一候选集。用户:同意。

### ADR-2 候选携带强类型路由目标(sealed DueTarget)

- **决策**:`DueScheduleEntry` 扩展 `target` 字段(sealed `DueTarget`:
  `AccountTarget(accountId)` / `DebtTarget(debtId)`),两源构造时各自填。
- **理由**:spec FR-3 明令禁止解析 id 字符串前缀的脆弱契约;DriftDueSource join 已有
  debtId,CreditCardDueSource 本持 accountId,零额外查询。

### ADR-3 候选消失三因归两态:挂失表查证,其余标已处理

- **决策**:InboxSyncer diff 发现候选消失时,查 ReminderDismissals——在表 → 已挂失;不在表
  (真还清/跨月滚动/卡债删除)→ 已处理。
- **grill**:跨月滚动(cc entryId 按月命名,旧条目消失但钱未还)标已处理是语义近似?
  → 辩护:待处理区是行动清单,滚动瞬间新月条目已在待处理区顶班**不漏事**;历史区是档案
  非对账凭证(金额日期俱在可对照);第四态推翻已拍板三态 spec。备选 b 第四态/c syncer
  反查欠款(变质领域仲裁者,复杂度跳档)均弃。用户裁 a。
- **佐证事实**:挂失表行永久留存("无需清理任务"),syncer 随时可查;挂失先于入窗的条目
  永不入箱(挂失=本期不存在),自洽。

### ADR-4 收件箱持久化新表 InboxEntries,真相驱动 upsert

- **决策**:drift v10→v11 增 `InboxEntries`(仅建表,无损):入窗 upsert(唯一键 entryKey);
  状态流转仅由 InboxSyncer 写。
- **理由**:历史回溯必须持久化——已处理期次/滚动条目离开候选集后无可推导源;ReminderLogs
  是发送去重台账(桶 token),复用它当收件箱会把发送语义泄漏进展示。

### ADR-5 托盘行经 TrayHeadData 扩展(headProvider 既有缝)

- **决策**:`TrayHeadData` 增 `dueCount`/`dueNearestDays`(可空);`buildContextMenu` 数据头区
  追加待还行,provider 查询失败 → 该行不显示(fail-safe 同 F25 NFR-1);刷新复用既有三触发。
- **理由**:F25 ADR-2 缝就是为此预留;零新机制。

### ADR-6 小圆点 lastSeen 存 AppMeta

- **决策**:键 `inbox_last_seen`(epochMs);打点条件 = 待处理 && createdAt > lastSeen;
  收件箱页打开即更新 lastSeen。
- **理由**:AppMeta 键值表既有(v8→v9);仅待处理区打点(spec 一致性缝 #1)。

### ADR-7 prototype: none(用户拍板)

- **grill**:收件箱页是新组合的一屏,是否先出原型?→ 辩护:三面零新视觉词汇,LLD 钉布局
  契约,execute 照既有组件拼装;F41 先例。用户:同意。

### ADR-8 直落 main,无 worktree

- **决策**:照 v1.0.10 直落先例直接在 main 实现(用户流程拍板);提交粒度照三连先例
  (单 feature 一提交,详尽 commit message)。

## HLD(单元/接口/依赖)

```
core/notifications/
  due_candidate_provider.dart   ★新 DueCandidateProvider(+DueCandidateView/DueTarget)
    ├─ 依赖:MultiDueSource(共享实例),ReminderDismissalStore,watch 流(复用 bootstrap 集)
    ├─ 输出:Stream<List<DueCandidateView>>(防抖 500ms,既有范式)
    └─ 管道尾挂 InboxSyncer.diff(candidates)
  inbox/
    inbox_store.dart            ★新 InboxStore(InboxEntries 表 CRUD + lastSeen 读写)
    inbox_syncer.dart           ★新 InboxSyncer(diff:入箱 upsert/消失定态)
  due_scanner.dart              不动(FR-8)
  tray_controller.dart          改:TrayHeadData +due 字段;buildContextMenu +待还行
account/presentation/
  widgets/due_banner.dart       ★新 DueBanner(聚合条+展开明细+直达)
  pages/accounts_page.dart      改:ListView 顶部(hero 前)插 DueBanner
inbox/presentation/
  pages/inbox_page.dart         ★新 收件箱页(两区/三态/小圆点)
app/router.dart                 改:+/inbox 路由
core/localdb/tables/inbox_tables.dart ★新 InboxEntries(v10→v11)
bootstrap(notifications_bootstrap.dart) 改:装配 provider+syncer+tray due 字段
```

依赖方向:core/notifications 不 import feature 模块(既有不变式);inbox 页只依赖
core store + 语义令牌;DueBanner 依赖 provider 流与 router(直达),放 account 模块内
(消费 accounts 页与还款对话框,同模块合法)。

## LLD(关键单元契约)

### InboxEntries(drift v10→v11)

```
InboxEntries {
  id          INTEGER PK autoIncrement
  entryKey    TEXT UNIQUE        —— 复用候选 entryId(期次裸 id / cc:acc:yyyy-MM)
  type        TEXT               —— 恒 'due_reminder'(类型预留)
  title       TEXT               —— 卡名/counterparty
  amountCents INTEGER
  dueDate     TEXT               —— yyyy-MM-dd
  state       INTEGER            —— 0 待处理 / 1 已处理 / 2 已挂失
  createdAt   INTEGER(epochMs)   —— 入窗时刻(小圆点基准)
  handledAt   INTEGER?           —— 定态时刻
  targetKind  INTEGER            —— 0 account / 1 debt
  targetId    TEXT
}
```

### DueCandidateView / DueTarget

```
sealed DueTarget { AccountTarget(String accountId) | DebtTarget(String debtId) }
DueCandidateView { entryKey, title, amountCents, dueDate, tier(advance|overdue),
                   daysLeft(负=逾期天数), target }
DueScheduleEntry 扩展 target 字段(两源各自填,ADR-2)
```

### DueBanner(布局契约,prototype:none 的替代钉子)

- 位置:accounts ListView 首项,_AccountsHeader 之前;空态不渲染(不占位)。
- 收起态:单行高度同 callout 行;「⏰ N 笔待还 · 最近 X 天后」/逾期并入「M 笔已逾期 N 天」
  (两者并存时逾期子句前置);着色按最紧条目档(逾期/≤7 红,≤15 黄)。
- 展开态:条目行 = [色条] 名称 · 金额 · 「X 天后到期/逾期 N 天」;行点击直达(ADR-2 target);
  尾部「查看全部」文字钮 → /inbox。宽窄屏同构自适应(既有 SeparatedRow 范式)。
- 令牌:context.yucai 语义色(callout.warn/danger 同族),零裸色(NFR-2)。

### InboxSyncer(伪代码)

```
on candidates(已挂失过滤后):
  activeKeys = candidates.map(entryKey)
  inboxActive = store.where(state=0)
  for c in candidates:
    if c.entryKey not in inboxActive: upsert(state=0, createdAt=now)   // 入窗
  for row in inboxActive where row.entryKey not in activeKeys:
    dismissed = dismissalTable.contains(row.entryKey)
    row.state = dismissed ? 2 : 1; row.handledAt = now                 // ADR-3
```

### 托盘行与入口

- 数据头区追加行:「待还 N 笔 · 最近 X 天后」(无候选不显示;不跟 showTrayAmounts);
  head 查询失败 → 行消失(fail-safe)。
- 托盘菜单项「提醒中心」:窗口 show + go('/inbox')(记一项点击同范式)。
- 聚合条「查看全部」→ /inbox;无候选时主窗口无入口(spec FR-7)。

## Risks

| # | 风险 | 缓解 |
|---|---|---|
| R1 | 两管线口径漂移(改源忘另一侧) | 同源契约测试:同 fixture 断言两管线同候选集 |
| R2 | 跨月滚动误标已处理 | 已裁决近似(ADR-3);新月条目顶班不漏事 |
| R3 | schema 迁移风险 | v10→v11 仅建表;既有 migration 测试范式照写 |
| R4 | provider 常驻扫描性能 | watch 防抖 500ms 既有;查询走小表索引 |
| R5 | .g.dart 幻影 CRLF diff 噪音 | 已知现象(memory),提交前核对真 diff |

## Migration

drift schema v10→v11(仅建 InboxEntries);无数据回填(入窗起记);AppMeta 新键惰性写。

## Open Questions

无(grill 全收敛;实现期发现再回补)。
