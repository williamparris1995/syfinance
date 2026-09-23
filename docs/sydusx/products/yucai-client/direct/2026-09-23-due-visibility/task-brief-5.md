# Task T5 — 托盘待还行 + bootstrap 装配

项目:御财 Flutter 客户端 `yucai/client/`。照
`docs/sydusx/products/yucai-client/direct/2026-09-23-due-visibility/` spec.md(FR-4/FR-7/
NFR-1/5)/design.md(ADR-1/5,LLD「托盘行与入口」)执行。
T1-T4 已交付:`DueCandidateProvider`(stream + `latest` 同步取值 + 可注入 syncer,启动
即广播)、`InboxSyncer`、`InboxStore`、DueBanner(已接线 accounts_page,经
`getIt.isRegistered<DueCandidateProvider>()` 守卫取)、InboxPage(已挂 /inbox 路由,经
getIt 取 InboxStore,未注册时由 AppDatabase 兜底自建)。

## 交付物

1. **TrayHeadData 扩展**(`tray_controller.dart`):增 `dueCount`(int?)与
   `dueNearestDays`(int?,最小非负 daysLeft,0=今日到期;全逾期时语义自定并在注释
   钉死——推荐存最小 daysLeft 允许负,渲染层判)。null/0 条 → 无待还行。
2. **buildContextMenu 待还行**:数据头区(今日/本月两行之后)追加 disabled 行
   「待还 N 笔 · 最近 X 天后」(全逾期形「待还 N 笔 · 已逾期 M 天」,与 DueBanner
   聚合语义一致;core 不 import account 模块——文案逻辑在本文件实现,勿复用
   account 的 dueBannerSummary)。规则:**永不含金额**;**不跟 showAmounts**
   (showAmounts=false 时金额两行变「金额已隐藏」但待还行照常);dueCount==null
   (查询失败/未注入)→ 该行不显示(fail-safe,照 F25 NFR-1)。
3. **托盘菜单项「提醒中心」**:enabled 项,点击 → 窗口 show+focus → 导航 /inbox。
   照 `newTransactionNav` 闭包范式加 `inboxNav` 注入(onTrayMenuItemClick 分派);
   bootstrap 侧闭包 = windowManager.show/focus + rootNavigatorKey context go('/inbox')
   (照既有 nav 闭包写法)。
4. **bootstrap 装配**(`notifications_bootstrap.dart`,组合根豁免区):
   - 构造共享 `MultiDueSource` 实例**复用**既有那份(scanner 与 provider 同一实例,
     NFR-1)——注意现状是 scanner 内联构造,提取为局部变量两处共用,不改行为。
   - `InboxSyncer`(注入 InboxStore+dismissalStore)挂 provider;
   - `DueCandidateProvider`(changeTriggers:既有 5 流照抄 + `db.select(db.debts)
     .watch().map((_) {})` 债务名变更刷新)启动;
   - **getIt 注册**:`DueCandidateProvider` 与 `InboxStore`(单例;T3 守卫与 T4 兜底
     自建在注册后自动切共享实例)。注册时机注意 injection.dart 既有序;bootstrap 在
     main runApp 前跑,页面守卫已兼容。
   - `headProvider` 既有闭包扩展:查数时并入 provider.latest → dueCount/dueNearestDays
     (provider 异常 → null 字段,行消失)。
5. **guest**:全链本地无门控,确认无 server/绑定依赖即可(注释说明)。

## 约束

- scanner 装配行为零变化(既有通知测试零改动);不改 T1-T4 交付文件的对外契约
  (发现契约缺口可在最终回复提出,勿静默改)。
- 中文注释;菜单行文案不含金额(spec FR-4)。

## TDD(强制)

必测:buildContextMenu 待还行(有/无候选/隐私开关两态/fail-safe null);「提醒中心」
项存在与点击分派(fake inboxNav);TrayHeadData 扩展字段往返;装配冒烟(bootstrap 后
getIt 可取 provider/store,syncer 已挂——可注入假件断言 diff 被调)。

## 完成门

1. `flutter test test/core/notifications`(新测试+既有全绿,尤其 tray/scanner 既有组)
2. `flutter analyze` 净增 0
3. 最终回复:文件清单、测试数字、全逾期文案裁决、偏离裁决。
