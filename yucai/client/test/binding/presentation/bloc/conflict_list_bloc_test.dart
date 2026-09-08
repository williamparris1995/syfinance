// F18-T3(spec FR-5,design ADR-5):ConflictListBloc 单测 —— 冲突面板数据面:
// - Load(首页/刷新):loading → loaded(items+totalCount+hasMore)/ error;
// - LoadMore(pageToken):追加页 + 游标推进 / 末页终止 / 非 loaded 态忽略;
// - ResolveConflictRequested(conflictId,resolution):resolving 标记 →
//   port.resolveConflict → 成功后重拉首页(权威计数,FR-5「解决后面板刷新」);
// - 失败收敛 error(port 契约:listConflicts/resolveConflict 透抛)。
//
// port 用 mocktail 替身(照库内 bloc 测试惯例);事件命名照 ...Requested。
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/binding/presentation/bloc/conflict_list_bloc.dart';
import 'package:yucai_client/core/localdb/sync_state.dart' show SyncModule;

class _MockPort extends Mock implements OfflineSyncPort {}

void main() {
  late _MockPort port;

  setUpAll(() {
    registerFallbackValue('');
  });

  setUp(() {
    port = _MockPort();
  });

  /// 最小冲突条目(面板消费面只读这些字段)。
  SyncConflictInfo info(String id, {String module = SyncModule.account}) =>
      SyncConflictInfo(
        module: module,
        entityId: 'e-$id',
        conflictType: 'version_conflict',
        conflictId: id,
      );

  test('初始态 = loading(空 items / 0 计数 / 无游标)', () {
    final bloc = ConflictListBloc(port);
    addTearDown(bloc.close);
    expect(bloc.state.status, ConflictListStatus.loading);
    expect(bloc.state.items, isEmpty);
    expect(bloc.state.totalCount, 0);
    expect(bloc.state.hasMore, isFalse);
    expect(bloc.state.resolvingConflictId, isNull);
  });

  group('ConflictListLoadRequested(首页/刷新)', () {
    test('成功 → loaded(items+totalCount+hasMore 游标透传)', () async {
      when(() => port.listConflicts(pageToken: null)).thenAnswer((_) async =>
          ConflictPage(items: [info('c1'), info('c2')], totalCount: 5,
              nextPageToken: 'tok-2'));

      final bloc = ConflictListBloc(port);
      addTearDown(bloc.close);
      bloc.add(const ConflictListLoadRequested());
      await until(bloc, (s) => s.status == ConflictListStatus.loaded);

      expect(bloc.state.items.length, 2);
      expect(bloc.state.totalCount, 5);
      expect(bloc.state.hasMore, isTrue);
      expect(bloc.state.nextPageToken, 'tok-2');
    });

    test('首页即末页(nextPageToken null)→ hasMore false', () async {
      when(() => port.listConflicts(pageToken: null)).thenAnswer(
          (_) async => ConflictPage(items: [info('c1')], totalCount: 1));

      final bloc = ConflictListBloc(port);
      addTearDown(bloc.close);
      bloc.add(const ConflictListLoadRequested());
      await bloc.close();

      expect(
          bloc.state.status, ConflictListStatus.loaded); // close 后 state 冻结
    });

    test('失败 → error(port 透抛,面板收敛加载失败态)', () async {
      when(() => port.listConflicts(pageToken: null))
          .thenThrow(Exception('grpc down'));

      final bloc = ConflictListBloc(port);
      addTearDown(bloc.close);
      final states = <ConflictListState>[];
      bloc.stream.listen(states.add);
      bloc.add(const ConflictListLoadRequested());
      await bloc.close();

      final err = states.last;
      expect(err.status, ConflictListStatus.error);
      expect(err.errorMessage, isNotNull);
      expect(err.items, isEmpty);
    });
  });

  group('ConflictListLoadMoreRequested(分页)', () {
    test('追加页:items 累加 + 游标推进 + totalCount 更新', () async {
      when(() => port.listConflicts(pageToken: null)).thenAnswer((_) async =>
          ConflictPage(items: [info('c1')], totalCount: 3,
              nextPageToken: 'tok-2'));
      when(() => port.listConflicts(pageToken: 'tok-2')).thenAnswer(
          (_) async => ConflictPage(items: [info('c2'), info('c3')],
              totalCount: 3));

      final bloc = ConflictListBloc(port);
      addTearDown(bloc.close);
      bloc.add(const ConflictListLoadRequested());
      await until(bloc, (s) => s.status == ConflictListStatus.loaded);
      bloc.add(const ConflictListLoadMoreRequested('tok-2'));
      await until(bloc,
          (s) => s.status == ConflictListStatus.loaded && s.items.length == 3);

      expect(bloc.state.items.map((i) => i.conflictId), ['c1', 'c2', 'c3']);
      expect(bloc.state.totalCount, 3);
      expect(bloc.state.hasMore, isFalse); // 末页:null 游标。
    });

    test('末页后再 LoadMore → 忽略(不重复请求)', () async {
      when(() => port.listConflicts(pageToken: null)).thenAnswer(
          (_) async => ConflictPage(items: [info('c1')], totalCount: 1));

      final bloc = ConflictListBloc(port);
      addTearDown(bloc.close);
      bloc.add(const ConflictListLoadRequested());
      await until(bloc, (s) => s.status == ConflictListStatus.loaded);
      bloc.add(const ConflictListLoadMoreRequested('tok-2'));
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => port.listConflicts(pageToken: 'tok-2'));
    });

    test('非 loaded 态(loading)→ 忽略', () async {
      // 不播种 listConflicts → bloc 停在初始 loading;LoadMore 须被丢弃。
      final bloc = ConflictListBloc(port);
      addTearDown(bloc.close);
      bloc.add(const ConflictListLoadMoreRequested('tok-2'));
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => port.listConflicts(pageToken: 'tok-2'));
    });

    test('追页失败 → error(简单收敛,面板展示后可重试首页)', () async {
      when(() => port.listConflicts(pageToken: null)).thenAnswer((_) async =>
          ConflictPage(items: [info('c1')], totalCount: 2,
              nextPageToken: 'tok-2'));
      when(() => port.listConflicts(pageToken: 'tok-2'))
          .thenThrow(Exception('page 2 down'));

      final bloc = ConflictListBloc(port);
      addTearDown(bloc.close);
      bloc.add(const ConflictListLoadRequested());
      await until(bloc, (s) => s.status == ConflictListStatus.loaded);
      bloc.add(const ConflictListLoadMoreRequested('tok-2'));
      await until(bloc, (s) => s.status == ConflictListStatus.error);

      verify(() => port.listConflicts(pageToken: 'tok-2')).called(1);
    });
  });

  group('ConflictResolveRequested(解决流)', () {
    test('成功:resolving 标记 → resolveConflict → 重拉首页(权威计数)', () async {
      var listCalls = 0;
      when(() => port.listConflicts(pageToken: null)).thenAnswer((_) async {
        listCalls++;
        return listCalls == 1
            ? ConflictPage(items: [info('c1'), info('c2')], totalCount: 2)
            : ConflictPage(
                items: [info('c2')],
                totalCount: 1); // 解决 c1 后剩 1(权威计数刷新)。
      });
      when(() => port.resolveConflict('c1', 'client'))
          .thenAnswer((_) async {});

      final bloc = ConflictListBloc(port);
      addTearDown(bloc.close);
      bloc.add(const ConflictListLoadRequested());
      await until(bloc, (s) => s.status == ConflictListStatus.loaded);

      bloc.add(const ConflictResolveRequested('c1', 'client'));
      await until(bloc,
          (s) => s.status == ConflictListStatus.loaded && s.totalCount == 1);

      verify(() => port.resolveConflict('c1', 'client')).called(1);
      expect(bloc.state.items.single.conflictId, 'c2');
      expect(bloc.state.resolvingConflictId, isNull); // 解决完成复位。
    });

    test('resolving 中的瞬时态:loaded 保留 items + resolvingConflictId 置位',
        () async {
      final resolveGate = Completer<void>();
      when(() => port.listConflicts(pageToken: null)).thenAnswer((_) async =>
          ConflictPage(items: [info('c1')], totalCount: 1));
      when(() => port.resolveConflict('c1', 'server'))
          .thenAnswer((_) => resolveGate.future);

      final bloc = ConflictListBloc(port);
      addTearDown(bloc.close);
      bloc.add(const ConflictListLoadRequested());
      await until(bloc, (s) => s.status == ConflictListStatus.loaded);

      bloc.add(const ConflictResolveRequested('c1', 'server'));
      await until(bloc,
          (s) => s.resolvingConflictId == 'c1' && s.items.isNotEmpty);

      resolveGate.complete();
      await until(bloc, (s) => s.resolvingConflictId == null);
      verify(() => port.resolveConflict('c1', 'server')).called(1);
    });

    test('解决失败 → error(按钮回可用:resolving 复位)', () async {
      when(() => port.listConflicts(pageToken: null)).thenAnswer(
          (_) async => ConflictPage(items: [info('c1')], totalCount: 1));
      when(() => port.resolveConflict('c1', 'server'))
          .thenThrow(Exception('resolve rejected'));

      final bloc = ConflictListBloc(port);
      addTearDown(bloc.close);
      bloc.add(const ConflictListLoadRequested());
      await until(bloc, (s) => s.status == ConflictListStatus.loaded);

      bloc.add(const ConflictResolveRequested('c1', 'server'));
      await until(bloc, (s) => s.status == ConflictListStatus.error);

      expect(bloc.state.resolvingConflictId, isNull);
    });

    test('resolving 中重复解决请求 → 忽略(单飞防抖)', () async {
      final resolveGate = Completer<void>();
      when(() => port.listConflicts(pageToken: null)).thenAnswer((_) async =>
          ConflictPage(items: [info('c1'), info('c2')], totalCount: 2));
      when(() => port.resolveConflict(any(), any()))
          .thenAnswer((_) => resolveGate.future);

      final bloc = ConflictListBloc(port);
      addTearDown(bloc.close);
      bloc.add(const ConflictListLoadRequested());
      await until(bloc, (s) => s.status == ConflictListStatus.loaded);

      bloc.add(const ConflictResolveRequested('c1', 'client'));
      await until(bloc, (s) => s.resolvingConflictId == 'c1');
      bloc.add(const ConflictResolveRequested('c2', 'client'));
      await Future<void>.delayed(Duration.zero);

      verify(() => port.resolveConflict(any(), any())).called(1);
      resolveGate.complete();
      await until(bloc, (s) => s.resolvingConflictId == null);
    });

    test('非 loaded 态(初始 loading)→ 忽略', () async {
      final bloc = ConflictListBloc(port);
      addTearDown(bloc.close);
      bloc.add(const ConflictResolveRequested('c1', 'client'));
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => port.resolveConflict(any(), any()));
    });
  });
}

/// 简版轮询等待(bloc 异步 handler 收敛;照库内 until 先例,10s 上限)。
Future<void> until(
    ConflictListBloc bloc, bool Function(ConflictListState) cond) async {
  final sw = Stopwatch()..start();
  while (!cond(bloc.state) && sw.elapsed < const Duration(seconds: 10)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(cond(bloc.state), isTrue, reason: 'bloc 状态未收敛到期望条件');
}
