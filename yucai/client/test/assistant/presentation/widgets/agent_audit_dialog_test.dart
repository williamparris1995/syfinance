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
//
// 评审修复轮:① 种子改**生产形态人话串** —— executor note 单点同构
// (「已记:支出 ¥35.00 午饭」/「已改:」「已删:」族;原 v21 原型串
// 生产不可能,掩盖了入库 summary 与对话框展示的鸿沟);失败行 reason 同
// 步改生产可能值(versionConflict,原中文 reason 生产不可能)。② 同键
// 注记(T2-M1):failed 行 + 同键 ok 行行尾「键 ****XXXX」,普通 ok 行
// 零注记 —— widget 断言 + keyNote 纯函数直测。
//
// F72 修复轮(评审六项同步):行时间列纯 HH:mm(T1-M1:行内无「今天」
// 字样,日期职责由段头承载)/ 搜索 placeholder「搜索摘要…」(T1-M2:仅
// summary 可搜,不提金额/幂等键)/「以此再记一笔 ›」提示色 muted(T2-M1
// 断言令牌色;恒显不回改 hover —— 可发现性优先,裁决记档 ledger)。
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/assistant/data/assistant_settings_store.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/assistant/domain/engine_port.dart';
import 'package:yucai_client/assistant/domain/engine_state.dart';
import 'package:yucai_client/assistant/domain/model_manager_port.dart';
import 'package:yucai_client/assistant/domain/model_state.dart';
import 'package:yucai_client/assistant/presentation/widgets/agent_audit_dialog.dart';
import 'package:yucai_client/assistant/presentation/assistant_panel/assistant_panel_bloc.dart'
    show AssistantReproposeInbox;
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
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

/// 入库一行审计(id 自增;按入参顺序插即时间升序;key 可指定 = 同键
/// 重试对种子缝)。
Future<void> _seed(
  db.AppDatabase d,
  int day,
  int hour,
  int minute,
  String tool,
  String summary, {
  bool ok = true,
  String? reason,
  String? key,
}) =>
    d.agentAuditDao.insertEvent(db.AgentAuditsCompanion.insert(
      createdMillis: DateTime(2026, 10, day, hour, minute).millisecondsSinceEpoch,
      tool: tool,
      summary: summary,
      ok: ok,
      reason: Value(reason),
      idempotencyKey:
          key ?? 'key-$day-$hour-$minute-$ok-${summary.hashCode}',
    ));

/// 同键重试对键(生产 = 确认卡 uuid 形态;尾 4 位 d479 进注记)。
const _retryKey = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';

/// v21 主态八行(时间升序入库;倒序展示 = 今天 14:32 在顶)。种子 =
/// **生产形态人话串**(executor note 单点同构:「已记:」「已改:」「已删:」
/// 族 —— 入库 summary 即此串,渲染原样);21:47/21:48 两行 = 同键重试对
/// (versionConflict 失败 → 同键重试成功,spec FR-2「失败也留痕」场景)。
Future<void> _seedV21Rows(db.AppDatabase d) async {
  await _seed(d, 25, 11, 2, 'transaction_add', '已记:支出 ¥3,999.00 机票');
  await _seed(d, 25, 18, 26, 'transaction_add', '已记:支出 ¥216.80 生鲜超市');
  await _seed(d, 26, 9, 15, 'transaction_update', '已改:美团买菜 ¥64.00');
  await _seed(d, 26, 21, 47, 'transaction_update', '已改:打车 ¥42.50',
      ok: false, reason: 'versionConflict', key: _retryKey);
  await _seed(d, 26, 21, 48, 'transaction_update', '已改:打车 ¥42.50',
      key: _retryKey);
  await _seed(d, 27, 9, 41, 'transaction_add', '已记:收入 ¥8,500.00 十月工资');
  await _seed(d, 27, 12, 18, 'transaction_delete', '已删:旧手机壳 ¥15.00');
  await _seed(d, 27, 14, 32, 'transaction_add', '已记:支出 ¥35.00 午饭');
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

/// 收尾钉(AppToast Timer 先例的 drift 变体):树卸载 → 订阅 cancel →
/// drift `QueryStream.markAsClosed` 挂零长 Timer,须在测试体内显式推进
/// fake 时钟烧掉 —— `pump()` 缺省不 elapse,零长 Timer 不触发;否则框架
/// 收尾的 `!timersPending` 断言炸(与组件逻辑无关)。所有挂过订阅型
/// 组件的用例末尾必调。
Future<void> _pumpDownTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 16));
}

/// 对话框直挂 host(F72 起带搜索防抖缝注入;相对时间判定用注入时钟,
/// 不经入口行)。
Widget _dialogHost(db.AppDatabase d,
        {Duration searchDebounce = const Duration(milliseconds: 300),
        int pageSize = 20}) =>
    MaterialApp(
      home: Scaffold(
        body: AgentAuditDialog(
          dao: d.agentAuditDao,
          now: _now,
          pageSize: pageSize,
          searchDebounce: searchDebounce,
        ),
      ),
    );

/// 内存剪贴板 mock(先例 context_menu_region_test._mockClipboard)。
String? _clipData;
void _mockClipboard(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          _clipData = (call.arguments as Map?)?['text'] as String?;
          return null;
        case 'Clipboard.getData':
          return _clipData == null
              ? null
              : <String, Object>{'text': _clipData!};
      }
      return null;
    },
  );
}

/// 右键(secondary tap down,先例 context_menu_region_test._rightClick)。
Future<void> _rightClick(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(
    tester.getCenter(target),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await gesture.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// F72 搜索面种子:4 行(午饭 ×2 跨今天/前天,地铁/早餐不匹配)。
Future<void> _seedSearchRows(db.AppDatabase d) async {
  await _seed(d, 25, 12, 31, 'transaction_add', '已记:支出 ¥35.00 午饭');
  await _seed(d, 26, 9, 15, 'transaction_add', '已记:支出 ¥4.00 地铁');
  await _seed(d, 27, 10, 0, 'transaction_add', '已记:支出 ¥6.00 早餐');
  await _seed(d, 27, 14, 32, 'transaction_add', '已记:支出 ¥35.00 午饭');
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
      await _seed(d, 27, 14, 50, 'transaction_add', '已记:支出 ¥12.00 咖啡');
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
    testWidgets('行时刻纯 HH:mm(T1-M1;段头承载日期)+ 三工具 chip + 摘要原样(千分位)+ 成败徽标与失败原因',
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
      // 行时间列纯 HH:mm(评审修复 T1-M1,v22 .aud-time 形态):日期职责
      // 已上移分组段头 —— 行内零日期字样。
      expect(find.text('14:32'), findsOneWidget);
      expect(find.text('21:48'), findsOneWidget);
      expect(find.text('18:26'), findsOneWidget);
      expect(find.text('今天 14:32'), findsNothing,
          reason: 'T1-M1:行内无「今天」字样');
      expect(find.text('昨天 21:48'), findsNothing);
      expect(find.text('前天 18:26'), findsNothing);
      // 段头承载日期(种子跨今天/昨天/前天三段,段头各就位)。
      expect(find.text('今天'), findsOneWidget);
      expect(find.text('昨天'), findsOneWidget);
      expect(find.text('前天'), findsOneWidget);
      // 工具 chip 三映射(v21 八行:add ×4 / update ×3 / delete ×1)。
      expect(find.text('记一笔'), findsNWidgets(4), reason: 'v21 八行中 add ×4');
      expect(find.text('改一笔'), findsNWidgets(3), reason: '含重试对两行 update');
      expect(find.text('删一笔'), findsOneWidget);
      // 摘要 = 生产形态人话串(executor note 单点同构),渲染原样(千分位
      // 含在串内,零二次格式化)。
      expect(find.text('已记:收入 ¥8,500.00 十月工资'), findsOneWidget,
          reason: '千分位原样(≥¥1000 note 同源 yuan())');
      expect(find.text('已改:打车 ¥42.50'), findsNWidgets(2),
          reason: '失败行与重试成功行同摘要(同幂等键两行留痕)');
      expect(find.text('已删:旧手机壳 ¥15.00'), findsOneWidget);
      // 徽标:✓ 绿 / ⚠ 红 + 原因小字(生产可能值:versionConflict)。
      expect(find.text('✓ 成功'), findsNWidgets(7));
      expect(find.text('⚠ 失败'), findsOneWidget);
      expect(find.text('versionConflict'), findsOneWidget,
          reason: '失败不粉饰,原因如实展示(生产单行 reason)');
      await _pumpDownTree(tester);
    });

    testWidgets('同键注记(T2-M1):failed 行与同键 ok 行行尾「键 ****尾4位」,普通 ok 行零注记',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final d = _newDb();
      await _seedV21Rows(d);
      await tester.pumpWidget(_dialogHost(d));
      await tester.pumpAndSettle();
      // 重试对(21:47 failed + 21:48 ok,同键 _retryKey 尾 4 位 d479)。
      expect(find.text('键 ****d479'), findsNWidgets(2),
          reason: 'v21 aud-note 语义:重试对两行均可辨识配对');
      // 全列表注记恰 2 处 —— 其余 6 行(普通 ok)零注记零噪音。
      expect(find.textContaining('键 ****'), findsNWidgets(2));
      await _pumpDownTree(tester);
    });

    testWidgets('超前天 → 段头完整日期兜底;今天 00:05 跨零点仍「今天」段(纯日期比较)',
        (tester) async {
      final d = _newDb();
      await _seed(d, 23, 9, 5, 'transaction_add', '已记:支出 ¥10.00 旧账');
      await _seed(d, 27, 0, 5, 'transaction_add', '已记:支出 ¥6.00 深夜');
      await tester.pumpWidget(_dialogHost(d));
      await tester.pumpAndSettle();
      // T1-M1:行内纯时刻;日期兜底职责在段头(v22 aud-group 形态)。
      expect(find.text('09:05'), findsOneWidget);
      expect(find.text('2026-10-23 09:05'), findsNothing,
          reason: 'T1-M1:行内零日期字样');
      expect(find.text('2026年10月23日'), findsOneWidget,
          reason: '演示三档只到前天;更早段头补完整日期兜底');
      expect(find.text('00:05'), findsOneWidget);
      expect(find.text('今天'), findsOneWidget,
          reason: '同日即今天,时刻不参与日期判定(0:05 未跨段)');
      await _pumpDownTree(tester);
    });

    testWidgets('未知工具名 → 原样兜底 chip(前瞻列)', (tester) async {
      final d = _newDb();
      // 前瞻工具(budget_update 尚不存在)= 演示串;摘要保持人话形态。
      await _seed(d, 27, 10, 0, 'budget_update', '已改:预算上限 ¥2,500.00');
      await tester.pumpWidget(_dialogHost(d));
      await tester.pumpAndSettle();
      expect(find.text('budget_update'), findsOneWidget);
      await _pumpDownTree(tester);
    });
  });

  group('加载更多(watchPage 20/页,offset 递增 append)', () {
    testWidgets('首页 20/25 → 追加页 5 条 → 全量后按钮收起', (tester) async {
      // 高窗:25 行 + F72 搜索框/分组段头全部入视口,finder 全行可断
      // (v21 的 1600 高窗在 F72 加搜索框+段头后装不下 25 行,ListView
      // 视口懒建会裁尾行;分页逻辑断言不受影响,抬窗即可)。
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final d = _newDb();
      // 25 行升序(倒序展示 row-25 顶);摘要唯一以便 finder 断言(人话
      // 形态:描述段 row-XX 唯一)。
      for (var i = 1; i <= 25; i++) {
        await _seed(d, 27, 8, i, 'transaction_add',
            '已记:支出 ¥$i.00 row-${i.toString().padLeft(2, '0')}');
      }
      await tester.pumpWidget(_dialogHost(d));
      await tester.pumpAndSettle();
      expect(find.text('已显示 20 / 25 条'), findsOneWidget);
      // 首页 = 最新 20(row-25..row-06);第二页(row-05..row-01)未加载。
      expect(find.text('已记:支出 ¥25.00 row-25'), findsOneWidget);
      expect(find.text('已记:支出 ¥6.00 row-06'), findsOneWidget);
      expect(find.text('已记:支出 ¥5.00 row-05'), findsNothing);
      expect(find.text('已记:支出 ¥1.00 row-01'), findsNothing);
      await tester.tap(find.text('加载更多'));
      await tester.pumpAndSettle();
      expect(find.text('已显示 25 / 25 条'), findsOneWidget);
      expect(find.text('已记:支出 ¥5.00 row-05'), findsOneWidget,
          reason: '第二页 offset 20 追加');
      expect(find.text('已记:支出 ¥1.00 row-01'), findsOneWidget);
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

  group('F72 分组段头(spec FR-1,design ADR-2:纯渲染聚合)', () {
    testWidgets('按日历日分段:今天/昨天/前天/yyyy年M月d日 段头+段内计数,组内倒序',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final d = _newDb();
      await _seedV21Rows(d); // 27×3 / 26×3 / 25×2
      await _seed(d, 23, 9, 5, 'transaction_add', '已记:支出 ¥10.00 旧账');
      await tester.pumpWidget(_dialogHost(d));
      await tester.pumpAndSettle();
      // 四段头各就位(组内行时间倒序由 DAO 排序保真,段头只聚合)。
      expect(find.text('今天'), findsOneWidget);
      expect(find.text('昨天'), findsOneWidget);
      expect(find.text('前天'), findsOneWidget);
      expect(find.text('2026年10月23日'), findsOneWidget);
      // 段内计数:今天 3 / 昨天 3 / 前天 2 / 10-23 段 1。
      expect(find.text('3 条'), findsNWidgets(2));
      expect(find.text('2 条'), findsOneWidget);
      expect(find.text('1 条'), findsOneWidget);
      await _pumpDownTree(tester);
    });

    testWidgets('跨「加载更多」续组:同日跨页不另起段头,计数跟涨', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final d = _newDb();
      // 今天×5(15..11 时)+ 昨天×2(10/9 时);pageSize 3 → 三页。
      for (var h = 11; h <= 15; h++) {
        await _seed(d, 27, h, 0, 'transaction_add', '已记:支出 ¥$h.00 row-$h');
      }
      await _seed(d, 26, 10, 0, 'transaction_add', '已记:支出 ¥10.00 row-26a');
      await _seed(d, 26, 9, 0, 'transaction_add', '已记:支出 ¥9.00 row-26b');
      await tester.pumpWidget(_dialogHost(d, pageSize: 3));
      await tester.pumpAndSettle();
      // 首页 = 今天最新 3 行:一段「今天 3 条」,昨天段未现。
      expect(find.text('今天'), findsOneWidget);
      expect(find.text('3 条'), findsOneWidget);
      expect(find.text('昨天'), findsNothing);
      expect(find.text('已显示 3 / 7 条'), findsOneWidget);
      // 第二页 = 今天余 2 + 昨天 1:今天段续(不另起段头)计数 5,昨天段起。
      await tester.tap(find.text('加载更多'));
      await tester.pumpAndSettle();
      expect(find.text('今天'), findsOneWidget, reason: '跨页续组:同日不重复段头');
      expect(find.text('5 条'), findsOneWidget);
      expect(find.text('昨天'), findsOneWidget);
      expect(find.text('1 条'), findsOneWidget);
      expect(find.text('已显示 6 / 7 条'), findsOneWidget);
      // 第三页 = 昨天余 1:昨天段续,计数 2。
      await tester.tap(find.text('加载更多'));
      await tester.pumpAndSettle();
      expect(find.text('昨天'), findsOneWidget);
      expect(find.text('2 条'), findsOneWidget);
      expect(find.text('1 条'), findsNothing, reason: '段计数随续组更新');
      await _pumpDownTree(tester);
    });
  });

  group('F72 搜索(spec FR-2,design ADR-1:DAO 重查 + 300ms 防抖)', () {
    testWidgets('副行双态 + 过滤重查 + 清除恢复(零防抖缝)', (tester) async {
      final d = _newDb();
      await _seedSearchRows(d);
      await tester.pumpWidget(_dialogHost(d, searchDebounce: Duration.zero));
      await tester.pumpAndSettle();
      // 默认态副行(v21 后缀保真)。
      expect(find.text('共 4 条 · 全部操作均经你确认'), findsOneWidget);
      expect(find.text('已显示 4 / 4 条'), findsOneWidget);
      // T1-M2:placeholder 仅「搜索摘要…」—— DAO keyword 只 LIKE summary,
      // 原「/ 金额 / 幂等键」误导可搜面(金额含在 summary 串内,搜摘要即覆盖)。
      final field = tester.widget<TextField>(
          find.byKey(const ValueKey('agentAuditSearchInput')));
      expect(field.decoration?.hintText, '搜索摘要…');
      // 输入「午饭」(防抖零缝,pump 推进后即触发)。
      await tester.enterText(
          find.byKey(const ValueKey('agentAuditSearchInput')), '午饭');
      await tester.pumpAndSettle();
      // 过滤态副行(v22:计数 + 关键词 + 清除搜索链接)。
      expect(find.text('2 条匹配「午饭」'), findsOneWidget);
      expect(find.text('清除搜索'), findsOneWidget);
      expect(find.text('共 4 条 · 全部操作均经你确认'), findsNothing);
      // 仅匹配行显示(两条午饭,分属今天/前天两段)。
      expect(find.text('已记:支出 ¥35.00 午饭'), findsNWidgets(2));
      expect(find.text('已记:支出 ¥4.00 地铁'), findsNothing);
      expect(find.text('已记:支出 ¥6.00 早餐'), findsNothing);
      expect(find.text('1 条'), findsNWidgets(2), reason: '过滤态照分组,段计数=段内匹配数');
      // foot 双计数:matched / 全量。
      expect(find.text('2 / 4 条匹配'), findsOneWidget);
      expect(find.text('加载更多'), findsNothing, reason: 'matched 全量已载');
      // 清除钮 → 恢复全量。
      await tester.tap(find.byKey(const ValueKey('agentAuditSearchClear')));
      await tester.pumpAndSettle();
      expect(find.text('共 4 条 · 全部操作均经你确认'), findsOneWidget);
      expect(find.text('已显示 4 / 4 条'), findsOneWidget);
      expect(find.text('已记:支出 ¥4.00 地铁'), findsOneWidget);
      await _pumpDownTree(tester);
    });

    testWidgets('防抖 300ms:输入后未到期不重查,到期触发(缺省缝)', (tester) async {
      final d = _newDb();
      await _seedSearchRows(d);
      await tester.pumpWidget(_dialogHost(d)); // 缺省 300ms
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('agentAuditSearchInput')), '午饭');
      await tester.pump(const Duration(milliseconds: 100));
      // 未到期:仍默认态全量(防抖期不闪过滤)。
      expect(find.text('共 4 条 · 全部操作均经你确认'), findsOneWidget);
      expect(find.text('已记:支出 ¥4.00 地铁'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 250)); // 累计 350ms ≥ 300
      await tester.pumpAndSettle();
      expect(find.text('2 条匹配「午饭」'), findsOneWidget);
      expect(find.text('已记:支出 ¥4.00 地铁'), findsNothing);
      await _pumpDownTree(tester);
    });

    testWidgets('过滤走 DAO 层重查:未加载页的匹配行可达 + offset 重置',
        (tester) async {
      final d = _newDb();
      // 24 行不匹配(今天 8:01..8:24)+ 1 行匹配(昨天,最旧 = 第二页)。
      for (var m = 1; m <= 24; m++) {
        await _seed(d, 27, 8, m, 'transaction_add',
            '已记:支出 ¥$m.00 地铁 fill-${m.toString().padLeft(2, '0')}');
      }
      await _seed(d, 26, 10, 0, 'transaction_add', '已记:支出 ¥35.00 午饭');
      await tester.pumpWidget(_dialogHost(d, searchDebounce: Duration.zero));
      await tester.pumpAndSettle();
      // 全量:首页 20 行,午饭行(最旧)未加载 —— 客户端过滤若只筛已加载
      // 页将永远漏行;DAO 重查才可达(spec「非仅已加载页」)。
      expect(find.text('已显示 20 / 25 条'), findsOneWidget);
      expect(find.text('已记:支出 ¥35.00 午饭'), findsNothing);
      await tester.enterText(
          find.byKey(const ValueKey('agentAuditSearchInput')), '午饭');
      await tester.pumpAndSettle();
      expect(find.text('1 条匹配「午饭」'), findsOneWidget);
      expect(find.text('1 / 25 条匹配'), findsOneWidget);
      expect(find.text('已记:支出 ¥35.00 午饭'), findsOneWidget,
          reason: 'offset 归零重查 matched 集,首页即含未加载的匹配行');
      // 清除 → 回全量首页(分页状态重置)。
      await tester.tap(find.byKey(const ValueKey('agentAuditSearchClear')));
      await tester.pumpAndSettle();
      expect(find.text('已显示 20 / 25 条'), findsOneWidget);
      await _pumpDownTree(tester);
    });

    testWidgets('空匹配:0 条计数 + 无匹配态,清链接恢复', (tester) async {
      final d = _newDb();
      await _seedSearchRows(d);
      await tester.pumpWidget(_dialogHost(d, searchDebounce: Duration.zero));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('agentAuditSearchInput')), '不存在');
      await tester.pumpAndSettle();
      expect(find.text('0 条匹配「不存在」'), findsOneWidget);
      expect(find.text('无匹配「不存在」的记录'), findsOneWidget);
      expect(find.text('换个关键词,或清除搜索查看全部'), findsOneWidget);
      expect(find.text('已记:支出 ¥35.00 午饭'), findsNothing);
      expect(find.text('加载更多'), findsNothing, reason: '空匹配无 foot 分页件');
      // 副行「清除搜索」链接与清除钮同效。
      await tester.tap(find.text('清除搜索'));
      await tester.pumpAndSettle();
      expect(find.text('共 4 条 · 全部操作均经你确认'), findsOneWidget);
      await _pumpDownTree(tester);
    });
  });

  group('F72 右键复制(spec FR-3,design ADR-5:ContextMenu 先例+AppToast)', () {
    testWidgets('右键行 →「复制摘要」→ 剪贴板=行摘要串 + toast「已复制」',
        (tester) async {
      _mockClipboard(tester);
      final d = _newDb();
      await _seed(d, 27, 14, 32, 'transaction_add', '已记:支出 ¥35.00 午饭');
      await tester.pumpWidget(_dialogHost(d));
      await tester.pumpAndSettle();
      // 右键行 → 菜单项单项「复制摘要」。
      await _rightClick(tester, find.text('已记:支出 ¥35.00 午饭'));
      expect(find.text('复制摘要'), findsOneWidget);
      // 点项 → 剪贴板含该行摘要串 + toast 确认。
      await tester.tap(find.text('复制摘要').last);
      await tester.pumpAndSettle();
      expect(_clipData, '已记:支出 ¥35.00 午饭');
      expect(find.text('已复制'), findsOneWidget);
      // toast 3s Timer 收尾泵空(免悬挂;先例 context_menu_region_test)。
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await _pumpDownTree(tester);
    });
  });

  group('纯函数(行时刻/段头文案/工具名映射)', () {
    test('formatRowTime:纯 HH:mm(评审修复 T1-M1;时/分零补位)', () {
      int at(int day, int h, int m) =>
          DateTime(2026, 10, day, h, m).millisecondsSinceEpoch;
      expect(AgentAuditDialog.formatRowTime(at(27, 14, 32)), '14:32');
      expect(AgentAuditDialog.formatRowTime(at(26, 23, 59)), '23:59');
      expect(AgentAuditDialog.formatRowTime(at(25, 0, 1)), '00:01',
          reason: '时零补位');
      expect(AgentAuditDialog.formatRowTime(at(27, 9, 5)), '09:05',
          reason: '分零补位');
      // 日期职责已上移 groupLabel(下测);行内与「今天/昨天」档位无关。
    });

    test('groupLabel:F72 分组段头文案(三档 + yyyy年M月d日 完整日期不补零)', () {
      int at(int day, int h, int m) =>
          DateTime(2026, 10, day, h, m).millisecondsSinceEpoch;
      expect(AgentAuditDialog.groupLabel(at(27, 0, 1), _now), '今天');
      expect(AgentAuditDialog.groupLabel(at(26, 23, 59), _now), '昨天');
      expect(AgentAuditDialog.groupLabel(at(25, 0, 1), _now), '前天');
      expect(AgentAuditDialog.groupLabel(at(24, 20, 3), _now), '2026年10月24日');
      // 更早:日历日完整日期(v22 aud-group 形态;月/日不补零)。
      expect(
          AgentAuditDialog.groupLabel(
              DateTime(2026, 5, 3, 8, 0).millisecondsSinceEpoch, _now),
          '2026年5月3日');
      expect(
          AgentAuditDialog.groupLabel(
              DateTime(2025, 12, 31, 8, 0).millisecondsSinceEpoch, _now),
          '2025年12月31日');
    });

    test('toolLabel:三映射 + 未知原样', () {
      expect(AgentAuditDialog.toolLabel('transaction_add'), '记一笔');
      expect(AgentAuditDialog.toolLabel('transaction_update'), '改一笔');
      expect(AgentAuditDialog.toolLabel('transaction_delete'), '删一笔');
      expect(AgentAuditDialog.toolLabel('budget_update'), 'budget_update');
    });

    test('keyNote:尾 4 位掩码 + 短键全掩码(T2-M1 纯函数)', () {
      // 生产键(uuid)→ 尾 4 位。
      expect(AgentAuditDialog.keyNote(_retryKey), '键 ****d479');
      expect(AgentAuditDialog.keyNote('key-8f42'), '键 ****8f42');
      // 恰 4 位 / 更短 → 尾段无辨识意义,全掩码。
      expect(AgentAuditDialog.keyNote('8f42'), '键 ****');
      expect(AgentAuditDialog.keyNote('ab'), '键 ****');
    });
  });

  group('F72-T2 以此再记一笔(记行可点 / 改删只读)', () {
    testWidgets('记行 onTap:关对话框 + note 原样上抛(getIt inbox 总线)',
        (tester) async {
      final d = _newDb();
      await _seedV21Rows(d); // 顶行 = add「已记:支出 ¥35.00 午饭」(27 14:32)
      final inbox = AssistantReproposeInbox();
      getIt.registerSingleton<AssistantReproposeInbox>(inbox);
      addTearDown(getIt.reset);
      await tester.pumpWidget(_cardHost(d));
      await tester.tap(find.byKey(const ValueKey('agentAuditEntryRow')));
      await tester.pumpAndSettle();
      expect(find.text('AI 助手 · 操作记录'), findsOneWidget);
      // 右缘提示挂记一笔行(v21 种子 4 笔 add;ListView 懒建 —— 视口内
      // 至少顶行午饭可见即可)。
      expect(find.text('以此再记一笔 ›'), findsWidgets);

      await tester.tap(find.text('以此再记一笔 ›').first);
      await tester.pumpAndSettle();

      expect(find.text('AI 助手 · 操作记录'), findsNothing,
          reason: 'spec FR-4:点击后关闭对话框');
      expect(inbox.pending, '已记:支出 ¥35.00 午饭',
          reason: 'note = 审计行 summary 原样(人话单源串)');
      await _pumpDownTree(tester);
    });

    testWidgets('改/删行只读:点击零上抛零关闭;提示仅记行(视觉区分)',
        (tester) async {
      final d = _newDb();
      // 三行同日短种子(全在视口内,免懒建滚动耦合):记/改/删各一。
      await _seed(d, 27, 10, 0, 'transaction_add', '已记:支出 ¥35.00 午饭');
      await _seed(d, 27, 11, 0, 'transaction_update', '已改:美团买菜 ¥64.00');
      await _seed(d, 27, 12, 0, 'transaction_delete', '已删:旧手机壳 ¥15.00');
      final inbox = AssistantReproposeInbox();
      getIt.registerSingleton<AssistantReproposeInbox>(inbox);
      addTearDown(getIt.reset);
      await tester.pumpWidget(_cardHost(d));
      await tester.tap(find.byKey(const ValueKey('agentAuditEntryRow')));
      await tester.pumpAndSettle();

      // 改行(update)/删行(delete)点击:无事件无关闭(行无手势壳,
      // 点击落在只读文本上)。
      await tester.tap(find.text('已改:美团买菜 ¥64.00'));
      await tester.pump();
      await tester.tap(find.text('已删:旧手机壳 ¥15.00'));
      await tester.pump();

      expect(find.text('AI 助手 · 操作记录'), findsOneWidget,
          reason: '改/删行点击不关对话框');
      expect(inbox.pending, isNull, reason: '零上抛');
      // 提示只挂记一笔行(spec FR-4 视觉区分;短种子恰 1 笔 add)。
      expect(find.text('以此再记一笔 ›'), findsOneWidget);
      // T2-M1:提示色 = muted 低噪(v22 .aud-again var(--muted);恒显不
      // 回改原型 hover 显隐 —— 可发现性优先,裁决记档 ledger)。
      final hint =
          tester.widget<Text>(find.text('以此再记一笔 ›'));
      expect(hint.style?.color, YucaiTheme.light().muted);
      await _pumpDownTree(tester);
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
