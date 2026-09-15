import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
import 'package:yucai_client/core/notifications/tray_controller.dart';
import 'package:yucai_client/core/notifications/tray_settings.dart';

/// Fake TraySettings(照 settings_page_test._FakeTraySettings 范式):
/// ValueNotifier 驱动,记录 setFirstClosePrompted 调用(决策树三态断言面)。
class _FakeTraySettings implements TraySettings {
  _FakeTraySettings({
    TrayCloseBehavior closeBehavior = TrayCloseBehavior.hide,
    bool firstClosePrompted = false,
    TrayScanInterval scanInterval = TrayScanInterval.minutes30,
  })  : _close = ValueNotifier<TrayCloseBehavior>(closeBehavior),
        _prompted = ValueNotifier<bool>(firstClosePrompted),
        _scan = ValueNotifier<TrayScanInterval>(scanInterval);

  final ValueNotifier<TrayCloseBehavior> _close;
  final ValueNotifier<bool> _prompted;
  final ValueNotifier<TrayScanInterval> _scan;
  final List<bool> promptedCalls = [];

  @override
  TrayCloseBehavior get closeBehavior => _close.value;

  @override
  ValueListenable<TrayCloseBehavior> get closeBehaviorListenable => _close;

  @override
  bool get firstClosePrompted => _prompted.value;

  @override
  ValueListenable<bool> get firstClosePromptedListenable => _prompted;

  @override
  TrayScanInterval get scanInterval => _scan.value;

  @override
  ValueListenable<TrayScanInterval> get scanIntervalListenable => _scan;

  @override
  Future<void> load() async {}

  @override
  Future<void> setCloseBehavior(TrayCloseBehavior behavior) async {
    _close.value = behavior;
  }

  @override
  Future<void> setScanInterval(TrayScanInterval interval) async {
    _scan.value = interval;
  }

  @override
  Future<void> setFirstClosePrompted(bool prompted) async {
    promptedCalls.add(prompted);
    _prompted.value = prompted;
  }
}

class _MockBuildContext extends Mock implements BuildContext {}

/// exit(0) 哨兵:假 exit 抛出以满足 Never 返回型,同时留下「走到了
/// exit(0)」的可观测证据(不真杀测试进程)。
class _ExitSentinel implements Exception {}

class _ExitSpy {
  final calls = <int>[];

  Never exit0() {
    calls.add(0);
    throw _ExitSentinel();
  }
}

/// window_manager / tray_manager 两 MethodChannel 的调用记录
/// (既有插件单例无法注入,以 channel mock 手法观测 hide/destroy 等)。
class _ChannelLog {
  final calls = <String>[];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ChannelLog windowLog;
  late _ChannelLog trayLog;
  late _ExitSpy exitSpy;

  Future<ScanResult> scanOk() async => const ScanResult(scanned: 0, sent: 0);

  setUp(() {
    windowLog = _ChannelLog();
    trayLog = _ChannelLog();
    exitSpy = _ExitSpy();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (call) async {
        windowLog.calls.add(call.method);
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('tray_manager'),
      (call) async {
        trayLog.calls.add(call.method);
        return null;
      },
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(
          const MethodChannel('window_manager'), null);
      messenger.setMockMethodCallHandler(
          const MethodChannel('tray_manager'), null);
    });
  });

  /// onWindowClose 是 async void(插件回调签名),错误经 zone 冒出:
  /// 以 runZonedGuarded 捕获,返回可继续追加的 errors 列表引用。
  List<Object> startCloseGuarded(TrayController controller) {
    final errors = <Object>[];
    runZonedGuarded<void>(() {
      controller.onWindowClose();
    }, (e, _) => errors.add(e));
    return errors;
  }

  Future<void> pump([int times = 4]) async {
    for (var i = 0; i < times; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  TrayController mk({
    TraySettings? settings,
    Future<FirstCloseChoice?> Function(BuildContext)? closePrompt,
    BuildContext? Function()? contextResolver,
  }) =>
      TrayController(
        scan: scanOk,
        settings: settings,
        closePrompt: closePrompt,
        contextResolver: contextResolver,
        exitFn: exitSpy.exit0,
      )..trayReady = true;

  group('onWindowClose 决策树(FR-2/3,NFR-1)', () {
    test('分支① trayReady=false → exit(0),绝不隐藏(防僵尸窗口)', () async {
      final controller = mk()..trayReady = false;
      final errors = startCloseGuarded(controller);
      await pump();

      expect(exitSpy.calls, [0]); // fail-safe 真退出
      expect(windowLog.calls.where((m) => m == 'hide'), isEmpty);
      expect(errors.single, isA<_ExitSentinel>());
    });

    test('分支② closeBehavior=exit → stop()+exit(0),不 hide', () async {
      final controller = mk(
        settings:
            _FakeTraySettings(closeBehavior: TrayCloseBehavior.exit),
      );
      final errors = startCloseGuarded(controller);
      await pump();

      expect(trayLog.calls, contains('destroy')); // stop() 清理托盘
      expect(exitSpy.calls, [0]);
      expect(windowLog.calls.where((m) => m == 'hide'), isEmpty);
      expect(errors.single, isA<_ExitSentinel>());
    });

    test('分支② 快速双 X:并发守卫,只一次 stop/exit(防御性)', () async {
      // 评审 R3:quit 挂起期间(stop 的 destroy 未返回)第二次 close 不得
      // 再入 —— 否则并发双 stop/destroy。以 gate 卡住 destroy 观察窗口。
      final controller = mk(
        settings:
            _FakeTraySettings(closeBehavior: TrayCloseBehavior.exit),
      );
      final destroyGate = Completer<void>();
      final trayCalls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('tray_manager'),
        (call) async {
          trayCalls.add(call.method);
          if (call.method == 'destroy') await destroyGate.future;
          return null;
        },
      );

      final errors = <Object>[];
      runZonedGuarded<void>(
          () => controller.onWindowClose(), (e, _) => errors.add(e));
      await pump();
      runZonedGuarded<void>(
          () => controller.onWindowClose(), (e, _) => errors.add(e));
      await pump();

      expect(trayCalls.where((m) => m == 'destroy'),
          hasLength(1)); // 双击只一次 stop(第二次被守卫忽略)
      expect(exitSpy.calls, isEmpty); // 仍挂在 gate,未到 exit
      expect(errors, isEmpty); // 第二次 close 静默忽略,无异常

      destroyGate.complete();
      await pump();
      expect(trayCalls.where((m) => m == 'destroy'), hasLength(1));
      expect(exitSpy.calls, [0]); // 首次 close 走完 stop → exit 一次
      expect(errors.whereType<_ExitSentinel>(), hasLength(1));
    });

    test('分支③ firstClosePrompted=true → 直接 hide,不弹不退', () async {
      var promptCalls = 0;
      final controller = mk(
        settings: _FakeTraySettings(firstClosePrompted: true),
        closePrompt: (_) {
          promptCalls++;
          return Completer<FirstCloseChoice?>().future;
        },
        contextResolver: () => _MockBuildContext(),
      );
      final errors = startCloseGuarded(controller);
      await pump();

      expect(windowLog.calls.where((m) => m == 'hide'), hasLength(1));
      expect(promptCalls, 0);
      expect(exitSpy.calls, isEmpty);
      expect(errors, isEmpty);
    });

    test('settings 未注入(null)→ 等价改造前:直接 hide,绝不弹', () async {
      var promptCalls = 0;
      final controller = mk(
        closePrompt: (_) {
          promptCalls++;
          return Completer<FirstCloseChoice?>().future;
        },
        contextResolver: () => _MockBuildContext(),
      );
      final errors = startCloseGuarded(controller);
      await pump();

      expect(windowLog.calls.where((m) => m == 'hide'), hasLength(1));
      expect(promptCalls, 0); // 无持久化面 → 视同已提示,不弹
      expect(exitSpy.calls, isEmpty);
      expect(errors, isEmpty);
    });
  });

  group('分支④ 首关对话框三态(FR-3)', () {
    test('minimize → hide + setFirstClosePrompted(true) 各一次', () async {
      final settings = _FakeTraySettings();
      final result = Completer<FirstCloseChoice?>();
      var promptCalls = 0;
      final controller = mk(
        settings: settings,
        closePrompt: (_) {
          promptCalls++;
          return result.future;
        },
        contextResolver: () => _MockBuildContext(),
      );
      final errors = startCloseGuarded(controller);
      await pump();

      expect(promptCalls, 1);
      expect(windowLog.calls.where((m) => m == 'hide'),
          isEmpty); // 对话框未决前不动窗口

      result.complete(FirstCloseChoice.minimize);
      await pump();

      expect(windowLog.calls.where((m) => m == 'hide'), hasLength(1));
      expect(settings.promptedCalls, [true]);
      expect(exitSpy.calls, isEmpty);
      expect(errors, isEmpty);
    });

    test('quit → setFirstClosePrompted(true) + stop() + exit(0),不 hide',
        () async {
      final settings = _FakeTraySettings();
      final result = Completer<FirstCloseChoice?>();
      final controller = mk(
        settings: settings,
        closePrompt: (_) => result.future,
        contextResolver: () => _MockBuildContext(),
      );
      final errors = startCloseGuarded(controller);
      await pump();

      result.complete(FirstCloseChoice.quit);
      await pump();

      expect(settings.promptedCalls, [true]);
      expect(trayLog.calls, contains('destroy')); // stop()
      expect(exitSpy.calls, [0]);
      expect(windowLog.calls.where((m) => m == 'hide'), isEmpty);
      expect(errors.single, isA<_ExitSentinel>());
    });

    test('null(取消)→ 不 hide 不标记,窗口保留', () async {
      final settings = _FakeTraySettings();
      final result = Completer<FirstCloseChoice?>();
      final controller = mk(
        settings: settings,
        closePrompt: (_) => result.future,
        contextResolver: () => _MockBuildContext(),
      );
      final errors = startCloseGuarded(controller);
      await pump();

      result.complete(null);
      await pump();

      expect(windowLog.calls.where((m) => m == 'hide'), isEmpty);
      expect(settings.promptedCalls, isEmpty);
      expect(exitSpy.calls, isEmpty);
      expect(errors, isEmpty);
    });

    test('重入守卫:对话框进行中二次 close 直接忽略;取消后守卫释放',
        () async {
      final settings = _FakeTraySettings();
      final result = Completer<FirstCloseChoice?>();
      var promptCalls = 0;
      final controller = mk(
        settings: settings,
        closePrompt: (_) {
          promptCalls++;
          return result.future;
        },
        contextResolver: () => _MockBuildContext(),
      );
      startCloseGuarded(controller);
      await pump();

      controller.onWindowClose(); // 进行中再点 X
      await pump();
      expect(promptCalls, 1); // 只弹一次

      result.complete(null); // 取消 → 守卫释放
      await pump();
      controller.onWindowClose();
      await pump();
      expect(promptCalls, 2); // 释放后可再弹
      expect(windowLog.calls.where((m) => m == 'hide'), isEmpty);
      expect(settings.promptedCalls, isEmpty);
    });

    test('contextResolver 取不到 context → 兜底 hide(fail-open)', () async {
      var promptCalls = 0;
      final controller = mk(
        settings: _FakeTraySettings(),
        closePrompt: (_) {
          promptCalls++;
          return Completer<FirstCloseChoice?>().future;
        },
        contextResolver: () => null,
      );
      final errors = startCloseGuarded(controller);
      await pump();

      expect(windowLog.calls.where((m) => m == 'hide'), hasLength(1));
      expect(promptCalls, 0);
      expect(exitSpy.calls, isEmpty);
      expect(errors, isEmpty);
    });

    test('closePrompt 未注入 → 兜底 hide(fail-open 到既有行为)', () async {
      final controller = mk(settings: _FakeTraySettings());
      final errors = startCloseGuarded(controller);
      await pump();

      expect(windowLog.calls.where((m) => m == 'hide'), hasLength(1));
      expect(exitSpy.calls, isEmpty);
      expect(errors, isEmpty);
    });
  });

  group('quit()(FR-1:AppExitPort 落点)', () {
    test('stop() + exit(0)', () async {
      final controller = mk();
      await expectLater(controller.quit(), throwsA(isA<_ExitSentinel>()));
      expect(trayLog.calls, contains('destroy'));
      expect(exitSpy.calls, [0]);
    });
  });

  group('托盘菜单(FR-6)', () {
    test('仅 显示御财/退出 两项,「立即检查」已撤', () {
      final items = TrayController.buildContextMenu();
      expect(items.map((i) => i.key), ['show', 'quit']);
      expect(items.map((i) => i.label), isNot(contains(contains('立即检查'))));
    });
  });

  group('drift watch 变更即扫(FR-4,ADR-1)', () {
    test('3 事件防抖 500ms 合流为 1 次扫描;新事件重置防抖', () {
      fakeAsync((async) {
        final sc = StreamController<void>.broadcast();
        var scanCalls = 0;
        final controller = TrayController(
          scan: () async {
            scanCalls++;
            return const ScanResult(scanned: 0, sent: 0);
          },
          settings: _FakeTraySettings(),
          changeTriggers: [sc.stream],
          // 托盘 setup 缝:fakeAsync 下真实 dart:io/FFI I/O 永不完成,
          // 注入降级实现(等价托盘失败路径,不影响 watch 接线)。
          traySetup: () async => false,
        );
        unawaited(controller.start());
        async.flushMicrotasks();

        sc.add(null);
        sc.add(null);
        sc.add(null);
        async.elapse(const Duration(milliseconds: 499));
        expect(scanCalls, 0); // 防抖窗口内未扫
        async.elapse(const Duration(milliseconds: 2));
        expect(scanCalls, 1); // 3 事件合流为 1 次

        sc.add(null); // 新窗口
        async.elapse(const Duration(milliseconds: 700));
        expect(scanCalls, 2);

        unawaited(controller.stop());
        async.flushMicrotasks();
      });
    });

    test('watch 流吐错(DB 损坏类):吞错不炸,周期 tick 兜底仍扫', () {
      // 评审 R1:drift watch 流吐错若不 onError → 未捕获 zone 异常 + 订阅
      // 静默死亡。断言:错误被吞(无未捕获)+ 周期 tick 照常扫描兜底。
      final zoneErrors = <Object>[];
      runZonedGuarded(() {
        fakeAsync((async) {
          final sc = StreamController<void>.broadcast();
          var scanCalls = 0;
          final controller = TrayController(
            scan: () async {
              scanCalls++;
              return const ScanResult(scanned: 0, sent: 0);
            },
            settings: _FakeTraySettings(),
            changeTriggers: [sc.stream],
            traySetup: () async => false,
          );
          unawaited(controller.start());
          async.flushMicrotasks();

          sc.addError(StateError('db corrupted'));
          async.elapse(const Duration(seconds: 10));
          expect(scanCalls, 1); // 启动首扫不受流错误影响
          async.elapse(const Duration(minutes: 30));
          expect(scanCalls, 2); // 周期 tick 兜底:变更即扫失效仍有扫

          unawaited(controller.stop());
          async.flushMicrotasks();
        });
      }, (e, _) => zoneErrors.add(e));
      expect(zoneErrors, isEmpty); // 流错误被 onError 吞,未冒泡成未捕获
    });

    test('stop():撤 watch 订阅/防抖/首扫与间隔 listener', () {
      fakeAsync((async) {
        final sc = StreamController<void>.broadcast();
        final settings = _FakeTraySettings();
        var scanCalls = 0;
        final controller = TrayController(
          scan: () async {
            scanCalls++;
            return const ScanResult(scanned: 0, sent: 0);
          },
          settings: settings,
          changeTriggers: [sc.stream],
          traySetup: () async => true, // 就绪态,验 stop 复位 trayReady
        );
        unawaited(controller.start());
        async.flushMicrotasks();
        expect(controller.trayReady, isTrue);
        unawaited(controller.stop());
        async.flushMicrotasks();
        // 评审 R2:stop 复位 trayReady —— stop 后再 onWindowClose 不得
        // hide 进已销毁托盘(防御性;当前生产 stop 后必 exit,不可达)。
        expect(controller.trayReady, isFalse);

        sc.add(null); // 订阅已撤 → 不触发
        async.elapse(const Duration(seconds: 30)); // >10s 首扫窗口(已撤)
        expect(scanCalls, 0);

        settings.setScanInterval(TrayScanInterval.minutes15); // listener 已撤
        async.elapse(const Duration(minutes: 15));
        expect(scanCalls, 0); // 不重臂
      });
    });
  });

  group('周期扫描间隔重臂(FR-5,ADR-5)', () {
    test('启动 +10s 首扫;间隔变更 cancel+重建;周期 tick 无条件重扫', () {
      fakeAsync((async) {
        final settings =
            _FakeTraySettings(scanInterval: TrayScanInterval.minutes60);
        var scanCalls = 0;
        final controller = TrayController(
          scan: () async {
            scanCalls++;
            return const ScanResult(scanned: 0, sent: 0);
          },
          settings: settings,
          traySetup: () async => false,
        );
        unawaited(controller.start());
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 10));
        expect(scanCalls, 1); // ADR-5:启动延迟首扫保留

        async.elapse(const Duration(minutes: 15)); // 60min 周期未到点
        expect(scanCalls, 1);

        settings.setScanInterval(TrayScanInterval.minutes15); // → re-arm
        async.elapse(Duration.zero);
        async.elapse(const Duration(minutes: 15));
        expect(scanCalls, 2); // 新 15min Timer 到点(旧 60min 已 cancel)

        async.elapse(const Duration(minutes: 15));
        expect(scanCalls, 3); // 周期性:每个间隔无条件重扫(撤跨日门槛)

        unawaited(controller.stop());
        async.flushMicrotasks();
      });
    });
  });
}
