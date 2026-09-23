// InboxPage widget 测试(2026-09 到期常显提醒 T4,spec FR-5):
// 两区排序与分界 / 三态 tag 文案与着色 / 小圆点出现与消失(lastSeen 读写
// 时序)/ 行点击直达分派(两种 target)/ 空态 / 候选流刷新重读。
// 台账直插 drift 内存库(显式 createdAt/handledAt,排序断言确定性);
// 时钟注入固定 2026-09-23(due 措辞断言确定性)。
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/due_candidate_provider.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
import 'package:yucai_client/core/notifications/due_target.dart';
import 'package:yucai_client/core/notifications/inbox/inbox_store.dart';
import 'package:yucai_client/core/notifications/inbox/inbox_syncer.dart';
import 'package:yucai_client/core/notifications/reminder_dismissal_store.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/theme/app_theme.dart';
import 'package:yucai_client/inbox/presentation/pages/inbox_page.dart';

/// 可变候选源(照 due_candidate_provider_test 同款)。
class _FakeSource implements DueScheduleSource {
  _FakeSource(this.entries);
  List<DueScheduleEntry> entries;

  @override
  Future<List<DueScheduleEntry>> unpaidDueCandidates() async => entries;
}

void main() {
  // 固定时钟:今天 2026-09-23(due 措辞与 lastSeen 写入时刻确定性)。
  final today = DateTime(2026, 9, 23);
  int ms(DateTime d) => d.millisecondsSinceEpoch;

  late AppDatabase db;
  late InboxStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = InboxStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// 直插台账行(绕过 upsertActive 的 DateTime.now(),显式时间戳)。
  Future<void> seed(
    String key, {
    String? title,
    int amountCents = 120000,
    String dueDate = '2026-09-26', // 今天 +3 天
    int state = 0,
    required int createdAt,
    int? handledAt,
    int targetKind = 1,
    String targetId = 'd1',
  }) =>
      db.into(db.inboxEntries).insert(InboxEntriesCompanion.insert(
            entryKey: key,
            type: kInboxTypeDueReminder,
            title: title ?? key,
            amountCents: amountCents,
            dueDate: dueDate,
            state: state,
            createdAt: createdAt,
            handledAt: handledAt == null ? const Value.absent() : Value(handledAt),
            targetKind: targetKind,
            targetId: targetId,
          ));

  Widget harness({DueCandidateProvider? provider, DateTime Function()? clock}) {
    final page = InboxPage(
      store: store,
      candidateProvider: provider,
      clock: clock ?? () => today,
    );
    final router = GoRouter(
      initialLocation: '/inbox',
      routes: [
        GoRoute(path: '/inbox', builder: (_, __) => page),
        GoRoute(
          path: '/accounts/:id',
          builder: (_, s) => Scaffold(
            body: Center(child: Text('ACCOUNT:${s.pathParameters['id']}')),
          ),
        ),
        GoRoute(
          path: '/debts/:id',
          builder: (_, s) => Scaffold(
            body: Center(child: Text('DEBT:${s.pathParameters['id']}')),
          ),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
  }

  Future<void> pumpPage(WidgetTester tester,
      {DueCandidateProvider? provider, DateTime Function()? clock}) async {
    await tester.pumpWidget(harness(provider: provider, clock: clock));
    await tester.pump(); // initState 异步首载(drift future)落定
    await tester.pump(); // postFrame lastSeen 写入排空
  }

  testWidgets('两区排序与分界:待处理置顶 createdAt 升序;历史沉底 '
      'handledAt 降序;空区不显小标题', (tester) async {
    double dyOf(String text) => tester.getTopLeft(find.text(text)).dy;
    await seed('p-old', title: '旧待办', createdAt: ms(DateTime(2026, 9, 20)));
    await seed('p-new', title: '新待办', createdAt: ms(DateTime(2026, 9, 22)));
    await seed('h-old',
        title: '旧历史',
        state: InboxEntryState.handled.index,
        createdAt: ms(DateTime(2026, 9, 1)),
        handledAt: ms(DateTime(2026, 9, 18)));
    await seed('h-mid',
        title: '中历史',
        state: InboxEntryState.dismissed.index,
        createdAt: ms(DateTime(2026, 9, 2)),
        handledAt: ms(DateTime(2026, 9, 21)));
    await seed('h-new',
        title: '新历史',
        state: InboxEntryState.handled.index,
        createdAt: ms(DateTime(2026, 9, 3)),
        handledAt: ms(DateTime(2026, 9, 23)));
    await pumpPage(tester);

    // 分界:待处理区整体在历史区上方。
    expect(find.text('待处理(2)'), findsOneWidget);
    expect(find.text('历史(3)'), findsOneWidget);
    expect(dyOf('待处理(2)'), lessThan(dyOf('历史(3)')));

    // 待处理区 createdAt 升序(旧在前);历史区 handledAt 降序(新在前,
    // 已处理/已挂失混排按时间沉底)。
    expect(dyOf('旧待办'), lessThan(dyOf('新待办')));
    expect(dyOf('新待办'), lessThan(dyOf('新历史')));
    expect(dyOf('新历史'), lessThan(dyOf('中历史')));
    expect(dyOf('中历史'), lessThan(dyOf('旧历史')));

    // 只有待处理时:历史区(含小标题)不渲染。
    final db2 = AppDatabase(NativeDatabase.memory());
    addTearDown(db2.close);
    await db2.into(db2.inboxEntries).insert(InboxEntriesCompanion.insert(
          entryKey: 'only',
          type: kInboxTypeDueReminder,
          title: '唯一',
          amountCents: 1,
          dueDate: '2026-09-26',
          state: 0,
          createdAt: 1,
          targetKind: 1,
          targetId: 'd1',
        ));
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/inbox',
        routes: [
          GoRoute(
            path: '/inbox',
            builder: (_, __) => InboxPage(
                store: InboxStore(db2), clock: () => today),
          ),
        ],
      ),
      theme: AppTheme.light(),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('唯一'), findsOneWidget);
    expect(find.text('历史(1)'), findsNothing,
        reason: '历史区空 → 不占位不显标题');
  });

  testWidgets('条目行:title · ¥金额(千分位)· 到期措辞(与 banner 同口径)',
      (tester) async {
    await seed('k1',
        title: '房贷',
        amountCents: 123456, // ¥1,234.56
        createdAt: 1,
        dueDate: '2026-09-26'); // +3 天
    await seed('k2',
        title: '车贷',
        amountCents: 9900, // ¥99.00
        createdAt: 2,
        dueDate: '2026-09-19'); // -4 天(逾期)
    await seed('k3',
        title: '当天卡',
        amountCents: 5000,
        createdAt: 3,
        dueDate: '2026-09-23'); // 0 天
    await pumpPage(tester);

    expect(find.text('房贷'), findsOneWidget);
    expect(find.text('¥1,234.56'), findsOneWidget);
    expect(find.text('3 天后到期'), findsOneWidget);

    expect(find.text('逾期 4 天'), findsOneWidget);
    expect(find.text('今日到期'), findsOneWidget);
  });

  testWidgets('三态 tag 文案与着色(语义令牌);已处理/已挂失行整体降不透明度',
      (tester) async {
    await seed('p1', title: '待办甲', createdAt: 1);
    await seed('h1',
        title: '已办乙',
        state: InboxEntryState.handled.index,
        createdAt: 1,
        handledAt: 2);
    await seed('m1',
        title: '挂失丙',
        state: InboxEntryState.dismissed.index,
        createdAt: 1,
        handledAt: 3);
    await pumpPage(tester);

    final t = AppTheme.light().extension<YucaiTheme>()!;

    // 文案:tag 文本恰为三态名(小标题带计数,不与之冲突)。
    expect(find.text('待处理'), findsOneWidget);
    expect(find.text('已处理'), findsOneWidget);
    expect(find.text('已挂失'), findsOneWidget);

    // 着色:待处理=accent / 已处理=positive / 已挂失=muted(chip 底 =
    // 同色 12% 透明,照 OfflineBadge chip 范式)。
    BoxDecoration decoOf(String key) =>
        (tester.widget<Container>(find.byKey(ValueKey('inboxTag-$key')))
                .decoration as BoxDecoration);
    expect(decoOf('p1').color, t.accent.withValues(alpha: 0.12));
    expect(decoOf('h1').color, t.positive.withValues(alpha: 0.12));
    expect(decoOf('m1').color, t.muted.withValues(alpha: 0.12));

    // 行整体降不透明度:仅历史区行包 Opacity(0.6),待处理行不包。
    Opacity? opacityOf(String title) {
      final hit = find.ancestor(
          of: find.text(title), matching: find.byType(Opacity));
      return hit.evaluate().isEmpty ? null : tester.widget<Opacity>(hit.first);
    }

    expect(opacityOf('待办甲'), isNull);
    expect(opacityOf('已办乙')?.opacity, 0.6);
    expect(opacityOf('挂失丙')?.opacity, 0.6);
  });

  testWidgets('小圆点:lastSeen 之前入箱的待处理条目打点,历史区永不打点;'
      '本次打开后写入 lastSeen,重开消失(先读后写时序)', (tester) async {
    await store.writeLastSeen(DateTime(2020, 1, 1)); // 很久以前看过
    await seed('p-fresh',
        title: '新待办', createdAt: ms(DateTime(2026, 9, 22)));
    await seed('h-fresh',
        title: '新历史',
        state: InboxEntryState.handled.index,
        createdAt: ms(DateTime(2026, 9, 23)), // 比 lastSeen 新,但在历史区
        handledAt: ms(DateTime(2026, 9, 23)));
    await pumpPage(tester);

    // 打点:仅待处理区新增行;历史区同样新也不打(档案不打点)。
    expect(find.byKey(const ValueKey('inboxDot-p-fresh')), findsOneWidget);
    expect(find.byKey(const ValueKey('inboxDot-h-fresh')), findsNothing);

    // 先读后写:首帧已渲染(点可见)→ postFrame 写 lastSeen=时钟时刻;
    // 本次打开点仍在(快照基准不因写入而变)。
    expect(find.byKey(const ValueKey('inboxDot-p-fresh')), findsOneWidget);
    expect((await store.readLastSeen())!.millisecondsSinceEpoch,
        ms(today), reason: '首帧后应写入 lastSeen(时钟注入值)');

    // 重开(同一 store,新页面实例):lastSeen 已覆盖 → 点消失。
    await pumpPage(tester);
    expect(find.byKey(const ValueKey('inboxDot-p-fresh')), findsNothing);
  });

  testWidgets('小圆点边界:lastSeen 晚于 createdAt 不打点;从未看过(null)'
      '视为全新 → 待处理全打点', (tester) async {
    // 场景 a:lastSeen 在入箱之后 → 无点。
    await store.writeLastSeen(DateTime(2026, 9, 25));
    await seed('p-before', title: '旧新待办', createdAt: ms(DateTime(2026, 9, 20)));
    await pumpPage(tester);
    expect(find.byKey(const ValueKey('inboxDot-p-before')), findsNothing);

    // 场景 b:全新 store(从未写过 lastSeen)→ 待处理行全打点。
    final db2 = AppDatabase(NativeDatabase.memory());
    addTearDown(db2.close);
    final store2 = InboxStore(db2);
    await db2.into(db2.inboxEntries).insert(InboxEntriesCompanion.insert(
          entryKey: 'p-virgin',
          type: kInboxTypeDueReminder,
          title: '首开待办',
          amountCents: 1,
          dueDate: '2026-09-26',
          state: 0,
          createdAt: ms(DateTime(2026, 9, 20)),
          targetKind: 1,
          targetId: 'd1',
        ));
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/inbox',
        routes: [
          GoRoute(
            path: '/inbox',
            builder: (_, __) =>
                InboxPage(store: store2, clock: () => today),
          ),
        ],
      ),
      theme: AppTheme.light(),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('inboxDot-p-virgin')), findsOneWidget);
  });

  testWidgets('行点击直达:AccountTarget → /accounts/:id;DebtTarget → '
      '/debts/:id', (tester) async {
    await seed('cc',
        title: '招行卡',
        createdAt: 1,
        targetKind: kInboxTargetKindAccount,
        targetId: 'acc-9');
    await seed('inst',
        title: '房贷期次',
        createdAt: 2,
        targetKind: kInboxTargetKindDebt,
        targetId: 'd-7');
    await pumpPage(tester);

    await tester.tap(find.text('招行卡'));
    await tester.pumpAndSettle();
    expect(find.text('ACCOUNT:acc-9'), findsOneWidget,
        reason: 'AccountTarget 应跳该账户详情页(直达裁决,见页面注释)');

    // 回收件箱(重建 harness,同一 store)再点债务行。
    await pumpPage(tester);
    await tester.tap(find.text('房贷期次'));
    await tester.pumpAndSettle();
    expect(find.text('DEBT:d-7'), findsOneWidget);
  });

  testWidgets('空态:两区皆空 → 居中友好文案,无任何小标题/条目', (tester) async {
    await pumpPage(tester);
    expect(find.text('暂无到期提醒'), findsOneWidget);
    expect(find.textContaining('到期事项'), findsOneWidget); // 副文案
    expect(find.textContaining('待处理('), findsNothing);
    expect(find.textContaining('历史('), findsNothing);
  });

  testWidgets('数据刷新:订阅 DueCandidateProvider.stream → syncer 落库 → '
      '页面重读(新条目入箱即现,历史区跟随)', (tester) async {
    final dismissals = ReminderDismissalStore(db);
    final trigger = StreamController<void>.broadcast();
    final source = _FakeSource(const []);
    final provider = DueCandidateProvider(
      changeTriggers: [trigger.stream],
      source: source,
      dismissalStore: dismissals,
      configProvider: () => const DueReminderConfig(advanceDays: 3),
      syncer: InboxSyncer(store: store, dismissalStore: dismissals),
      clock: () => today,
    );
    await provider.start();
    addTearDown(provider.dispose);

    await pumpPage(tester, provider: provider);
    expect(find.text('暂无到期提醒'), findsOneWidget);

    // 候选入窗(3 天内 + 信用卡欠款)→ trigger → 防抖 500ms → diff 入箱
    // → stream 事件 → 页面重读。
    source.entries = [
      DueScheduleEntry(
          id: 'e1',
          debtName: '房贷',
          totalCents: 100000,
          paymentDate: DateTime(2026, 9, 26),
          target: const DebtTarget('d1')),
      DueScheduleEntry(
          id: 'cc:a1:2026-09',
          debtName: '招行卡',
          totalCents: 5000,
          paymentDate: DateTime(2026, 9, 24),
          target: const AccountTarget('a1')),
    ];
    trigger.add(null);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.text('暂无到期提醒'), findsNothing);
    expect(find.text('房贷'), findsOneWidget);
    expect(find.text('招行卡'), findsOneWidget);
    expect(find.text('待处理(2)'), findsOneWidget);

    // 候选消失(欠款清零)→ diff 定态 handled → 沉入历史区。
    source.entries = const [];
    trigger.add(null);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('待处理(2)'), findsNothing);
    expect(find.text('待处理(0)'), findsNothing);
    expect(find.text('历史(2)'), findsOneWidget);
    expect(find.text('已处理'), findsNWidgets(2));
  });
}
