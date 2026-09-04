// F10 T1(2026-09-03):DataRoute 三态解析矩阵 + ConnectivityGateway 快照接线。
// 矩阵:isGuest × online × authOffline → guestLocal / boundRemote /
// boundOfflineLocal(spec FR-1 / design ADR-1)。
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/connectivity/connectivity_gateway.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';

void main() {
  group('resolveDataRoute 矩阵(F10 FR-1)', () {
    DataRoute routeOf(
        {required bool guest,
        required bool online,
        required bool authOffline}) {
      final tracker = SessionModeTracker()
        ..isGuest = guest
        ..online = online
        ..authOffline = authOffline;
      return tracker.resolveDataRoute();
    }

    test('guest × online → guestLocal(guest 短路,与 R6 语义一致)', () {
      expect(routeOf(guest: true, online: true, authOffline: false),
          DataRoute.guestLocal);
    });

    test('guest × offline → guestLocal', () {
      expect(routeOf(guest: true, online: false, authOffline: false),
          DataRoute.guestLocal);
    });

    test('guest × authOffline=true → guestLocal(isGuest 优先)', () {
      expect(routeOf(guest: true, online: true, authOffline: true),
          DataRoute.guestLocal);
    });

    test('bound × online × authOffline=false → boundRemote', () {
      expect(routeOf(guest: false, online: true, authOffline: false),
          DataRoute.boundRemote);
    });

    test('bound × online × authOffline=true → boundOfflineLocal(离线冷启动 FR-2)', () {
      expect(routeOf(guest: false, online: true, authOffline: true),
          DataRoute.boundOfflineLocal);
    });

    test('bound × offline × authOffline=false → boundOfflineLocal(断网)', () {
      expect(routeOf(guest: false, online: false, authOffline: false),
          DataRoute.boundOfflineLocal);
    });
  });

  group('ConnectivityGateway 接线(构造快照 + online 流订阅)', () {
    late StreamController<List<ConnectivityResult>> source;

    setUp(() =>
        source = StreamController<List<ConnectivityResult>>.broadcast());
    tearDown(() => source.close());

    test('构造期快照 current:冷启动已离线时 tracker 直接本地', () async {
      final gateway = ConnectivityGateway(
        statusStream: source.stream,
        initialCheck: () async => [ConnectivityResult.none],
      );
      await Future<void>.delayed(Duration.zero);
      final tracker = SessionModeTracker(gateway)..isGuest = false;
      expect(tracker.online, isFalse);
      expect(tracker.resolveDataRoute(), DataRoute.boundOfflineLocal);
    });

    test('未注入 gateway 时乐观 online=true(现状语义:插件失败乐观在线)', () {
      final tracker = SessionModeTracker()..isGuest = false;
      expect(tracker.online, isTrue);
      expect(tracker.resolveDataRoute(), DataRoute.boundRemote);
    });

    test('online 流事件更新快照(断网→本地,回网→远端)', () async {
      final gateway = ConnectivityGateway(
        statusStream: source.stream,
        initialCheck: () async => [ConnectivityResult.ethernet],
      );
      final tracker = SessionModeTracker(gateway)..isGuest = false;
      expect(tracker.resolveDataRoute(), DataRoute.boundRemote);

      source.add([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);
      expect(tracker.online, isFalse);
      expect(tracker.resolveDataRoute(), DataRoute.boundOfflineLocal);

      source.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      expect(tracker.online, isTrue);
      expect(tracker.resolveDataRoute(), DataRoute.boundRemote);
    });
  });
}
