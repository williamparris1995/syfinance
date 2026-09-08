// F18-T3(spec FR-5,design ADR-5):ConflictPanelPage widget 测试 —— 面板 UI 面:
// - 渲染:标题「同步冲突」+ 总数;loading/error/空态/列表;
// - 双栏对照:「服务端版本」/「我的版本」各 FieldFormatter 摘要 + 模块徽章
//   (中文模块名)+ createdAt 相对时间;
// - 操作回调:「保留服务端」→ resolution "server" /「保留我的」→ "client";
// - resolving 禁用:解决在途时该条按钮禁用,完成后复位;
// - 分页:hasMore → 「加载更多」续页追加。
//
// port 用手写 fake(页队列 + resolve 记录/闸门);bloc 用真件(页面消费的
// 即生产 bloc);主题 AppTheme.light()(context.yucai 令牌真注入)。
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/binding/presentation/bloc/conflict_list_bloc.dart';
import 'package:yucai_client/binding/presentation/pages/conflict_panel_page.dart';
import 'package:yucai_client/core/localdb/sync_state.dart' show SyncModule;
import 'package:yucai_client/core/theme/app_theme.dart';

/// 面板专用 fake port:listConflicts 按页队列弹出(耗尽回空页);
/// resolveConflict 记录调用,可挂闸门控在途时长。
class _FakePort implements OfflineSyncPort {
  _FakePort({List<ConflictPage> pages = const [], this.resolveGate})
      : _pages = [...pages];

  final List<ConflictPage> _pages;
  final Completer<void>? resolveGate;

  /// (conflictId, resolution) 调用记录。
  final resolveCalls = <(String, String)>[];

  @override
  Future<ConflictPage> listConflicts({String? pageToken}) async {
    if (_pages.isNotEmpty) return _pages.removeAt(0);
    return const ConflictPage(items: [], totalCount: 0);
  }

  @override
  Future<void> resolveConflict(String conflictId, String resolution,
      {List<int>? mergedPayload}) async {
    resolveCalls.add((conflictId, resolution));
    await resolveGate?.future;
  }

  // 面板不消费的面:
  @override
  Future<SyncResult> push(SyncBatch batch) => throw UnimplementedError();
  @override
  Future<void> registerDevice(String deviceName) =>
      throw UnimplementedError();
  @override
  Future<PullBatch> pull(int sinceVersion,
          {List<String>? entityTypes, int? pageSize}) =>
      throw UnimplementedError();
}

/// envelope 最小账户行 → payload bytes(formatter 消费面)。
Uint8List _accountPayload(String name, int balanceCents) =>
    Uint8List.fromList(utf8.encode(jsonEncode({
          'ID': 'a-1',
          'Name': name,
          'CurrentBalanceCents': balanceCents,
          'OpeningDate': '2026-09-01T00:00:00.000Z',
        })));

/// 标准冲突条目(账户模块 + 双 payload + 5 分钟前的 createdAt)。
SyncConflictInfo _conflict(String id,
    {String serverName = '服务端现金',
    String clientName = '我的现金',
    String module = SyncModule.account}) {
  return SyncConflictInfo(
    conflictId: id,
    module: module,
    entityId: 'entity-$id',
    conflictType: 'version_conflict',
    serverPayload: _accountPayload(serverName, 1000),
    clientPayload: _accountPayload(clientName, 2000),
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

void main() {
  /// 挂载 harness:真 bloc + fake port;页面 initState 自发 Load。
  Future<void> pumpPanel(WidgetTester tester, OfflineSyncPort port) {
    final bloc = ConflictListBloc(port);
    addTearDown(bloc.close);
    return tester.pumpWidget(
      BlocProvider<ConflictListBloc>.value(
        value: bloc,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ConflictPanelPage(),
        ),
      ),
    );
  }

  /// 冲突条目卡(按 conflictId 定位;列表多卡时的精准断言/点击锚)。
  Finder cardOf(String conflictId) =>
      find.byKey(ValueKey('conflict-card-$conflictId'));

  testWidgets('渲染:标题 + 总数 + 条目卡(模块徽章/相对时间/双栏对照)',
      (tester) async {
    final port = _FakePort(pages: [
      ConflictPage(items: [_conflict('c1'), _conflict('c2')], totalCount: 2),
    ]);
    await pumpPanel(tester, port);
    await tester.pump();
    await tester.pump();

    // 标题 + 总数(权威计数)。
    expect(find.text('同步冲突'), findsOneWidget);
    expect(find.text('待处理 2 条'), findsOneWidget);

    // 条目卡 ×2:模块徽章(中文模块名)+ 相对时间。
    expect(cardOf('c1'), findsOneWidget);
    expect(cardOf('c2'), findsOneWidget);
    expect(find.text('账户'), findsNWidgets(2)); // 两卡各一枚模块徽章。
    expect(find.text('5 分钟前'), findsNWidgets(2));

    // 双栏对照:两栏标题 + 各自 formatter 摘要行。
    expect(find.text('服务端版本'), findsNWidgets(2));
    expect(find.text('我的版本'), findsNWidgets(2));
    expect(find.text('名称:服务端现金'), findsNWidgets(2));
    expect(find.text('名称:我的现金'), findsNWidgets(2));
    expect(find.text('金额:¥10.00'), findsNWidgets(2));
    expect(find.text('金额:¥20.00'), findsNWidgets(2));
  });

  testWidgets('空态:无冲突 → 「无待处理冲突」', (tester) async {
    final port = _FakePort(pages: [
      const ConflictPage(items: [], totalCount: 0),
    ]);
    await pumpPanel(tester, port);
    await tester.pump();
    await tester.pump();

    expect(find.text('无待处理冲突'), findsOneWidget);
    expect(find.text('服务端版本'), findsNothing);
  });

  testWidgets('操作回调:「保留我的」→ resolveConflict(client)', (tester) async {
    final port = _FakePort(pages: [
      ConflictPage(items: [_conflict('c1')], totalCount: 1),
      const ConflictPage(items: [], totalCount: 0), // 解决后刷新为空。
    ]);
    await pumpPanel(tester, port);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.descendant(
        of: cardOf('c1'), matching: find.text('保留我的')));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(port.resolveCalls, [('c1', 'client')]);
    // 解决成功 → 重拉首页 → 空态(面板刷新)。
    expect(find.text('无待处理冲突'), findsOneWidget);
  });

  testWidgets('操作回调:「保留服务端」→ resolveConflict(server)', (tester) async {
    final port = _FakePort(pages: [
      ConflictPage(items: [_conflict('c1'), _conflict('c2')], totalCount: 2),
      ConflictPage(items: [_conflict('c1')], totalCount: 1),
    ]);
    await pumpPanel(tester, port);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.descendant(
        of: cardOf('c2'), matching: find.text('保留服务端')));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(port.resolveCalls, [('c2', 'server')]);
    // 刷新后剩 1 条(c1)。
    expect(cardOf('c1'), findsOneWidget);
    expect(cardOf('c2'), findsNothing);
    expect(find.text('待处理 1 条'), findsOneWidget);
  });

  testWidgets('resolving 中禁用:解决在途该条两按钮禁用,完成后复位',
      (tester) async {
    final gate = Completer<void>();
    final port = _FakePort(pages: [
      ConflictPage(items: [_conflict('c1')], totalCount: 1),
    ], resolveGate: gate);
    await pumpPanel(tester, port);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.descendant(
        of: cardOf('c1'), matching: find.text('保留我的')));
    await tester.pump();
    await tester.pump();

    // 在途:该条「保留服务端」(OutlinedButton)与「保留我的」(FilledButton)
    // 均禁用(onPressed null)。
    final outlined =
        tester.widget<OutlinedButton>(find.descendant(of: cardOf('c1'), matching: find.byType(OutlinedButton)));
    expect(outlined.onPressed, isNull);
    final filled =
        tester.widget<FilledButton>(find.descendant(of: cardOf('c1'), matching: find.byType(FilledButton)));
    expect(filled.onPressed, isNull);

    gate.complete();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(port.resolveCalls.single, ('c1', 'client'));
  });

  testWidgets('分页:hasMore → 「加载更多」续页追加,末页隐藏', (tester) async {
    // 大视口:ListView 惰性构建,3 卡在 600px 默认面下 c2/c3 在折叠线下。
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final port = _FakePort(pages: [
      ConflictPage(items: [_conflict('c1')], totalCount: 3,
          nextPageToken: 'tok-2'),
      ConflictPage(items: [_conflict('c2'), _conflict('c3')], totalCount: 3),
    ]);
    await pumpPanel(tester, port);
    await tester.pump();
    await tester.pump();

    expect(cardOf('c1'), findsOneWidget);
    expect(find.text('加载更多'), findsOneWidget);

    await tester.tap(find.text('加载更多'));
    await tester.pump();
    await tester.pump();

    expect(cardOf('c1'), findsOneWidget);
    expect(cardOf('c2'), findsOneWidget);
    // c3 在折叠线下:滚动到可见(ListView 惰性构建的条目卡)。
    await tester.scrollUntilVisible(cardOf('c3'), 200);
    expect(cardOf('c3'), findsOneWidget);
    expect(find.text('待处理 3 条'), findsOneWidget);
    expect(find.text('加载更多'), findsNothing); // 末页:按钮退场。
  });

  testWidgets('错误态:加载失败文案 + 「重试」恢复', (tester) async {
    final port = _FakePort(pages: [
      ConflictPage(items: [_conflict('c1')], totalCount: 1),
    ]);
    // 首拉炸、重试成功:用可变开关注入。
    var failNext = true;
    // 覆盖 listConflicts:首拉抛错(直接换第二个 fake 不便,改用手写覆写)。
    final failingPort = _DelegatingPort(port, () {
      if (failNext) {
        failNext = false;
        throw Exception('grpc down');
      }
      return null;
    });
    await pumpPanel(tester, failingPort);
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('加载冲突列表失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump();
    expect(cardOf('c1'), findsOneWidget);
  });
}

/// 包装 port:hook 可注入首拉失败(listConflicts 代理)。
class _DelegatingPort implements OfflineSyncPort {
  _DelegatingPort(this._inner, this._onList);

  final OfflineSyncPort _inner;
  final Object? Function() _onList; // 返回非 null Exception 即抛。

  @override
  Future<ConflictPage> listConflicts({String? pageToken}) async {
    final err = _onList();
    if (err != null) throw err;
    return _inner.listConflicts(pageToken: pageToken);
  }

  @override
  Future<void> resolveConflict(String conflictId, String resolution,
          {List<int>? mergedPayload}) =>
      _inner.resolveConflict(conflictId, resolution,
          mergedPayload: mergedPayload);

  @override
  Future<SyncResult> push(SyncBatch batch) => throw UnimplementedError();
  @override
  Future<void> registerDevice(String deviceName) =>
      throw UnimplementedError();
  @override
  Future<PullBatch> pull(int sinceVersion,
          {List<String>? entityTypes, int? pageSize}) =>
      throw UnimplementedError();
}
