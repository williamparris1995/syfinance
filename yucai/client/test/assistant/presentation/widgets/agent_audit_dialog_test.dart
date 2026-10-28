// F71-T2 TDD:审计查看对话框 + 卡内入口行(spec FR-3,design ADR-4;文案照
// prototype v21 ui/agent-audit-dialog.html 三态:入口行带条数 / 对话框列表
// (相对时间 · 工具 chip · 摘要 · 徽标)/ 加载更多 / 空态两行)。
//
// seam = ModelManagementCard.auditDao(真 in-memory drift 库,T1 sink 测同款
// —— watchPage/count 真 watch 语义,免 fake 流拟合)+ AgentAuditDialog
// 构造(now/pageSize 可注入)。覆盖:入口行条数实时 / 对话框打开 / 列表
// 渲染(失败行原因 + 金额千分位原样)/ 相对时间(今天/昨天/前天/超三日
// 兜底 + 跨零点纯日期比较)/ 加载更多 append(offset 递增)/ 空态两行 /
// 关闭 / 纯函数与源码守门。
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/assistant/data/assistant_settings_store.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/assistant/domain/engine_port.dart';
import 'package:yucai_client/assistant/domain/engine_state.dart';
import 'package:yucai_client/assistant/domain/model_manager_port.dart';
import 'package:yucai_client/assistant/domain/model_state.dart';
import 'package:yucai_client/assistant/presentation/widgets/agent_audit_dialog.dart';
import 'package:yucai_client/assistant/presentation/widgets/model_management_card.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;

/// Fake AssistantSettings(照 model_management_card_test 范式)。
class _FakeAssistantSettings extends Fake implements AssistantSettings {
  _FakeAssistantSettings(AssistantConfig initial)
      : _notifier = ValueNotifier(initial);
  final ValueNotifier<AssistantConfig> _notifier;

  @override
  AssistantConfig get value => _notifier.value;

  @override
  ValueListenable<AssistantConfig> get listenable => _notifier;

  @override
  Future<void> setConfig(AssistantConfig config) async {
    _notifier.value = config;
  }
}

/// Fake ModelManagerPort:ready 静态即可(本票不触模型态)。
class _FakeModelManager implements ModelManagerPort {
  @override
  final ValueNotifier<ModelState> state = ValueNotifier(const ModelReady());

  @override
  Future<void> download() async {}

  @override
  void pause() {}

  @override
  void cancel() {}

  @override
  Future<void> delete() async {}

  @override
  Future<int> diskUsageBytes() async => kModelManifest.totalBytes;

  @override
  ModelManifest get manifest => kModelManifest;
}

/// Fake EngineManager:stopped 静态即可。
class _FakeEngineManager implements EngineManager {
  @override
  final ValueNotifier<EngineState> state = ValueNotifier(const EngineStopped());

  @override
  Future<void> ensureReady() async {}

  @override
  Future<void> shutdown() async {}

  @override
  void beginActivity() {}

  @override
  void endActivity() {}
}

/// 测试时钟钉定(2026-10-27 15:00;今天=27 / 昨天=26 / 前天=25)。
final DateTime _now = DateTime(2026, 10, 27, 15, 0);

/// in-memory 库(addTearDown 自动关)。
db.AppDatabase _newDb() {
  final database = db.AppDatabase(NativeDatabase.memory());
  addTearDown(() => database.close());
  return database;
}

/// 入库一行审计(id 自增;按入参顺序插即时间升序)。
Future<void> _seed(
  db.AppDatabase d,
  int day,
  int hour,
  int minute,
  String tool,
  String summary, {
  bool ok = true,
  String? reason,
}) =>
    d.agentAuditDao.insertEvent(db.AgentAuditsCompanion.insert(
      createdMillis: DateTime(2026, 10, day, hour, minute).millisecondsSinceEpoch,
      tool: tool,
      summary: summary,
      ok: ok,
      reason: Value(reason),
      idempotencyKey: 'key-$day-$hour-$minute-$ok',
    ));

/// v21 主态八行(时间升序入库;倒序展示 = 今天 14:32 在顶)。
Future<void> _seedV21Rows(db.AppDatabase d) async {
  await _seed(d, 25, 11, 2, 'transaction_add', '支出 ¥3,999.00 机票 → 招商银行');
  await _seed(d, 25, 18, 26, 'transaction_add', '支出 ¥216.80 生鲜超市 → 花呗');
  await _seed(d, 26, 9, 15, 'transaction_update', '预算「餐饮」月上限 ¥2,000.00 → ¥2,500.00');
  await _seed(d, 26, 21, 47, 'transaction_delete', '删除 支出 ¥42.50 打车 → 高德',
      ok: false, reason: '内容已被其他修改更新');
  await _seed(d, 26, 21, 48, 'transaction_delete', '删除 支出 ¥42.50 打车 → 高德');
  await _seed(d, 27, 9, 41, 'transaction_add', '收入 ¥8,500.00 十月工资 → 储蓄卡');
  await _seed(d, 27, 12, 18, 'transaction_update', '支出 ¥1,280.00 手机 备注「京东」→「京东自营」');
  await _seed(d, 27, 14, 32, 'transaction_add', '支出 ¥35.00 午饭 → 招商银行');
}

/// 卡整挂 host(入口行 → showDialog 全链路)。
Widget _cardHost(db.AppDatabase d) => MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          ModelManagementCard(
            settings: _FakeAssistantSettings(const AssistantConfig(enabled: true)),
            modelManager: _FakeModelManager(),
            engineManager: _FakeEngineManager(),
            auditDao: d.agentAuditDao,
          ),
        ]),
      ),
    );

/// 对话框直挂 host(相对时间判定用注入时钟,不经入口行)。
Widget _dialogHost(db.AppDatabase d) => MaterialApp(
      home: Scaffold(body: AgentAuditDialog(dao: d.agentAuditDao, now: _now)),
    );

/// 收尾钉(AppToast Timer 先例的 drift 变体):树卸载 → 订阅 cancel →
/// drift `QueryStream.markAsClosed` 挂零长 Timer,须在测试体内显式推进
/// fake 时钟烧掉 —— `pump()` 缺省不 elapse,零长 Timer 不触发;否则框架
/// 收尾的 `!timersPending` 断言炸(与组件逻辑无关)。所有挂过订阅型
/// 组件的用例末尾必调。
Future<void> _pumpDownTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  group('入口行(卡底部,带条数,实时)', () {
    testWidgets('label + 副行文案 + 「N 条 ›」随入库实时刷新', (tester) async {
      final d = _newDb();
      await _seedV21Rows(d);
      await tester.pumpWidget(_cardHost(d));
      await tester.pumpAndSettle();
      expect(find.text('操作记录'), findsOneWidget);
      expect(find.text('助手执行过的每一笔,留痕可查'), findsOneWidget);
      expect(find.text('8 条'), findsOneWidget, reason: 'v21 入口值「12 条」同款 N 条形态');
      // 实时:入口行 watchPage(count 联动)—— 第 9 条入库后条数跟涨。
      await _seed(d, 27, 14, 50, 'transaction_add', '支出 ¥12.00 咖啡');
      await tester.pumpAndSettle();
      expect(find.text('9 条'), findsOneWidget);
      await _pumpDownTree(tester);
    });

    testWidgets('空库入口显示「0 条」(不藏行)', (tester) async {
      final d = _newDb();
      await tester.pumpWidget(_cardHost(d));
      await tester.pumpAndSettle();
      expect(find.text('0 条'), findsOneWidget);
      await _pumpDownTree(tester);
    });
  });

  group('对话框打开(入口行点击)', () {
    testWidgets('标题「AI 助手 · 操作记录」+ 副行总数 + 确认后缀', (tester) async {
      final d = _newDb();
      await _seedV21Rows(d);
      await tester.pumpWidget(_cardHost(d));
      await tester.pumpAndSettle();
      await tester.tap(find.text('操作记录'));
      await tester.pumpAndSettle();
      expect(find.text('AI 助手 · 操作记录'), findsOneWidget);
      expect(find.text('共 8 条 · 全部操作均经你确认'), findsOneWidget);
      await _pumpDownTree(tester);
    });
  });

  group('列表渲染(v21 主态八行)', () {
    testWidgets('相对时间今天/昨天/前天 + 三工具 chip + 摘要原样(千分位)+ 成败徽标与失败原因',
        (tester) async {
      // 高窗(security_page_test 先例):八行 + 头 + foot 全量入视口,finder
      // 全行可断(默认 600 高窗最后一行被裁,ListView 视口懒建)。
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final d = _newDb();
      await _seedV21Rows(d);
      await tester.pumpWidget(_dialogHost(d));
      await tester.pumpAndSettle();
      // 相对时间(v21 三档;纯日期比较无时区抖动)。
      expect(find.text('今天 14:32'), findsOneWidget);
      expect(find.text('昨天 21:48'), findsOneWidget);
      expect(find.text('前天 18:26'), findsOneWidget);
      // 工具 chip 三映射。
      expect(find.text('记一笔'), findsNWidgets(4), reason: 'v21 八行中 add ×4');
      expect(find.text('改一笔'), findsNWidgets(2));
      expect(find.text('删一笔'), findsNWidgets(2));
      // 摘要由 T1 入库串携带,渲染原样(千分位含在串内,零二次格式化)。
      expect(find.text('支出 ¥1,280.00 手机 备注「京东」→「京东自营」'), findsOneWidget);
      expect(find.text('预算「餐饮」月上限 ¥2,000.00 → ¥2,500.00'), findsOneWidget);
      expect(find.text('删除 支出 ¥42.50 打车 → 高德'), findsNWidgets(2),
          reason: '失败行与重试成功行同摘要(同幂等键两行留痕)');
      // 徽标:✓ 绿 / ⚠ 红 + 原因小字。
      expect(find.text('✓ 成功'), findsNWidgets(7));
      expect(find.text('⚠ 失败'), findsOneWidget);
      expect(find.text('内容已被其他修改更新'), findsOneWidget, reason: '失败不粉饰,原因如实展示');
      await _pumpDownTree(tester);
    });

    testWidgets('超前天 → 完整日期兜底;今天 00:05 跨零点仍「今天」(纯日期比较)',
        (tester) async {
      final d = _newDb();
      await _seed(d, 23, 9, 5, 'transaction_add', '支出 ¥10.00 旧账');
      await _seed(d, 27, 0, 5, 'transaction_add', '支出 ¥6.00 深夜');
      await tester.pumpWidget(_dialogHost(d));
      await tester.pumpAndSettle();
      expect(find.text('2026-10-23 09:05'), findsOneWidget,
          reason: 'v21 演示只到前天;更早补完整日期兜底');
      expect(find.text('今天 00:05'), findsOneWidget,
          reason: '同日即今天,时刻不参与日期判定');
      await _pumpDownTree(tester);
    });

    testWidgets('未知工具名 → 原样兜底 chip(前瞻列)', (tester) async {
      final d = _newDb();
      await _seed(d, 27, 10, 0, 'budget_update', '预算改');
      await tester.pumpWidget(_dialogHost(d));
      await tester.pumpAndSettle();
      expect(find.text('budget_update'), findsOneWidget);
      await _pumpDownTree(tester);
    });
  });

  group('加载更多(watchPage 20/页,offset 递增 append)', () {
    testWidgets('首页 20/25 → 追加页 5 条 → 全量后按钮收起', (tester) async {
      // 高窗:25 行全量入视口(断言 row-01..row-25 全在树上)。
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final d = _newDb();
      // 25 行升序(倒序展示 row-25 顶);摘要唯一以便 finder 断言。
      for (var i = 1; i <= 25; i++) {
        await _seed(d, 27, 8, i, 'transaction_add',
            '摘要 row-${i.toString().padLeft(2, '0')}');
      }
      await tester.pumpWidget(_dialogHost(d));
      await tester.pumpAndSettle();
      expect(find.text('已显示 20 / 25 条'), findsOneWidget);
      // 首页 = 最新 20(row-25..row-06);第二页(row-05..row-01)未加载。
      expect(find.text('摘要 row-25'), findsOneWidget);
      expect(find.text('摘要 row-06'), findsOneWidget);
      expect(find.text('摘要 row-05'), findsNothing);
      expect(find.text('摘要 row-01'), findsNothing);
      await tester.tap(find.text('加载更多'));
      await tester.pumpAndSettle();
      expect(find.text('已显示 25 / 25 条'), findsOneWidget);
      expect(find.text('摘要 row-05'), findsOneWidget, reason: '第二页 offset 20 追加');
      expect(find.text('摘要 row-01'), findsOneWidget);
      expect(find.text('加载更多'), findsNothing, reason: '全量后按钮收起');
      await _pumpDownTree(tester);
    });

    testWidgets('恰一页(8 条)无加载更多,计数同显', (tester) async {
      final d = _newDb();
      await _seedV21Rows(d);
      await tester.pumpWidget(_dialogHost(d));
      await tester.pumpAndSettle();
      expect(find.text('加载更多'), findsNothing);
      expect(find.text('已显示 8 / 8 条'), findsOneWidget);
      await _pumpDownTree(tester);
    });
  });

  group('空态(v21 第三段)', () {
    testWidgets('「共 0 条」无确认后缀 + 两行文案,无加载更多', (tester) async {
      final d = _newDb();
      await tester.pumpWidget(_cardHost(d));
      await tester.pumpAndSettle();
      await tester.tap(find.text('操作记录'));
      await tester.pumpAndSettle();
      expect(find.text('共 0 条'), findsOneWidget);
      expect(find.text('还没有通过助手操作过记账'), findsOneWidget);
      expect(find.text('每次助手记账 / 修改 / 删除都会在这里留痕'), findsOneWidget);
      expect(find.text('加载更多'), findsNothing);
      expect(find.text('已显示 0 / 0 条'), findsNothing, reason: 'v21 空态无 foot');
      await _pumpDownTree(tester);
    });
  });

  group('关闭(✕;只读零编辑零删除)', () {
    testWidgets('✕ 关闭对话框回设置卡', (tester) async {
      final d = _newDb();
      await _seedV21Rows(d);
      await tester.pumpWidget(_cardHost(d));
      await tester.pumpAndSettle();
      await tester.tap(find.text('操作记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('agentAuditCloseButton')));
      await tester.pumpAndSettle();
      expect(find.text('AI 助手 · 操作记录'), findsNothing);
      expect(find.text('操作记录'), findsOneWidget, reason: '入口行仍在');
      await _pumpDownTree(tester);
    });
  });

  group('纯函数(相对时间/工具名映射)', () {
    test('formatRelativeTime:今天/昨天/前天/兜底(纯日期比较,零时区运算)', () {
      int at(int day, int h, int m) =>
          DateTime(2026, 10, day, h, m).millisecondsSinceEpoch;
      expect(AgentAuditDialog.formatRelativeTime(at(27, 14, 32), _now),
          '今天 14:32');
      expect(AgentAuditDialog.formatRelativeTime(at(26, 23, 59), _now),
          '昨天 23:59');
      expect(AgentAuditDialog.formatRelativeTime(at(25, 0, 1), _now), '前天 00:01');
      expect(AgentAuditDialog.formatRelativeTime(at(24, 9, 5), _now),
          '2026-10-24 09:05');
      // 跨月/跨年兜底同样纯日历输出。
      expect(
          AgentAuditDialog.formatRelativeTime(
              DateTime(2025, 12, 31, 8, 0).millisecondsSinceEpoch, _now),
          '2025-12-31 08:00');
    });

    test('toolLabel:三映射 + 未知原样', () {
      expect(AgentAuditDialog.toolLabel('transaction_add'), '记一笔');
      expect(AgentAuditDialog.toolLabel('transaction_update'), '改一笔');
      expect(AgentAuditDialog.toolLabel('transaction_delete'), '删一笔');
      expect(AgentAuditDialog.toolLabel('budget_update'), 'budget_update');
    });
  });

  group('守门(硬约束:只读 + 零裸色 + 不触写路径)', () {
    test('源码静态检查:无裸色/无 AppColors/无 insertEvent/不 import sink', () {
      final src = File('lib/assistant/presentation/widgets/agent_audit_dialog.dart')
          .readAsStringSync();
      expect(src.contains('Color(0x'), isFalse, reason: '禁裸色:走 context.yucai');
      expect(src.contains('AppColors'), isFalse, reason: 'legacy 色禁用');
      expect(src.contains('insertEvent'), isFalse, reason: '对话框只读,零写路径');
      expect(src.contains('agent_audit_sink'), isFalse,
          reason: 'presentation 不 import 写 sink(经 DAO 读面)');
    });
  });
}
