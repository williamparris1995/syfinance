import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yucai_client/core/notifications/window_state.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// window_manager channel 调用记录(照 tray_controller_test channel mock
/// 范式:插件单例无法注入,以 MethodChannel mock 观测 setBounds/maximize
/// 及其**调用顺序** —— F30 恢复排序断言面)。
class _ChannelLog {
  final calls = <String>[];
  final arguments = <String, Object?>{};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockSecureStorage storage;
  late _ChannelLog windowLog;
  late List<MethodCall> storageWrites;
  Rect boundsNow = const Rect.fromLTWH(0, 0, 0, 0);
  bool maximizedNow = false;

  /// 单屏 1920×1080 逻辑坐标(注入 screen ranges 缝,断言出屏回退)。
  List<Rect> oneScreen() =>
      [const Rect.fromLTWH(0, 0, 1920, 1080)];

  setUpAll(() => registerFallbackValue(''));

  setUp(() {
    storage = _MockSecureStorage();
    windowLog = _ChannelLog();
    storageWrites = [];
    boundsNow = const Rect.fromLTWH(100, 50, 800, 600);
    maximizedNow = false;
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((inv) async {
      storageWrites.add(MethodCall(
          inv.namedArguments[const Symbol('key')] as String,
          inv.namedArguments[const Symbol('value')]));
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (call) async {
        windowLog.calls.add(call.method);
        windowLog.arguments[call.method] = call.arguments;
        switch (call.method) {
          case 'isMaximized':
            return maximizedNow;
          case 'getBounds':
            // Rect.fromLTWH 参数为 double:返回 int 会在运行期 cast 抛错。
            return {
              'x': boundsNow.left,
              'y': boundsNow.top,
              'width': boundsNow.width,
              'height': boundsNow.height,
            };
          default:
            return null;
        }
      },
    );
    addTearDown(() => messenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'), null));
  });

  WindowStateController mk({ScreenRangesFn? screenRanges}) =>
      WindowStateController(storage,
          screenRanges: screenRanges ?? (() async => oneScreen()));

  /// 从 storage.write 记录解析出落盘的 WindowState(json)。
  WindowState? lastPersisted() => storageWrites.isEmpty
      ? null
      : WindowState.decode(
          storageWrites.last.arguments as String?);

  // ── S1:编解码(纯逻辑) ────────────────────────────────────────────
  group('WindowState codec (S1)', () {
    test('encode → decode 往返:常规态', () {
      const s = WindowState(x: 12.5, y: -8, w: 1024, h: 768, maximized: false);
      final back = WindowState.decode(s.encode());
      expect(back, isNotNull);
      expect(back!.x, 12.5);
      expect(back.y, -8);
      expect(back.w, 1024);
      expect(back.h, 768);
      expect(back.maximized, isFalse);
    });

    test('encode → decode 往返:最大化态(负坐标多屏合法)', () {
      const s = WindowState(x: -1920, y: 0, w: 400, h: 300, maximized: true);
      final back = WindowState.decode(s.encode());
      expect(back, isNotNull);
      expect(back!.maximized, isTrue);
      expect(back.rect, const Rect.fromLTWH(-1920, 0, 400, 300));
    });

    test('json 内 int 值与 double 同解码(编码侧 double 反序列化回 num)',
        () {
      final back = WindowState.decode(
          '{"x":10,"y":20,"w":640,"h":480,"maximized":false}');
      expect(back, isNotNull);
      expect(back!.rect, const Rect.fromLTWH(10, 20, 640, 480));
    });

    test('null / 空串 → 回落默认(null)', () {
      expect(WindowState.decode(null), isNull);
      expect(WindowState.decode(''), isNull);
    });

    test('非法 json / 非 map / 缺字段 / 字段类型错 → null', () {
      expect(WindowState.decode('not json'), isNull);
      expect(WindowState.decode('[1,2,3]'), isNull);
      expect(WindowState.decode('{"x":1}'), isNull);
      expect(
          WindowState.decode(
              '{"x":"a","y":2,"w":500,"h":400,"maximized":false}'),
          isNull);
      expect(
          WindowState.decode(
              '{"x":1,"y":2,"w":500,"h":400,"maximized":"yes"}'),
          isNull);
    });

    test('编码格式:secure_storage 键 window_state 下的 json 五字段', () {
      const s = WindowState(x: 1, y: 2, w: 640, h: 480, maximized: true);
      final map = jsonDecode(s.encode()) as Map<String, dynamic>;
      expect(map.keys.toSet(), {'x', 'y', 'w', 'h', 'maximized'});
    });
  });

  // ── S2:最小尺寸钳制(纯逻辑;review 修正:钳制保留 x/y,不丢弃) ──
  group('min-size clamp (S2)', () {
    test('w < 400 → 钳到 400,x/y 保留(review:丢弃会致启动复位循环)', () {
      final back = WindowState.decode(
          '{"x":12,"y":34,"w":399.5,"h":600,"maximized":false}');
      expect(back, isNotNull);
      expect(back!.rect, const Rect.fromLTWH(12, 34, 400, 600));
    });

    test('h < 300 → 钳到 300,w 与 x/y 保留', () {
      final back = WindowState.decode(
          '{"x":5,"y":6,"w":600,"h":299,"maximized":false}');
      expect(back, isNotNull);
      expect(back!.rect, const Rect.fromLTWH(5, 6, 600, 300));
    });

    test('恰好 400×300 边界值合法', () {
      final back = WindowState.decode(
          '{"x":0,"y":0,"w":400,"h":300,"maximized":false}');
      expect(back, isNotNull);
      expect(back!.rect, const Rect.fromLTWH(0, 0, 400, 300));
    });
  });

  // ── S2:出屏检测(注入 screen ranges,纯逻辑) ──────────────────────
  group('off-screen detection (S2)', () {
    test('bounds 在屏内 → 可见', () {
      const s = WindowState(x: 0, y: 0, w: 800, h: 600, maximized: false);
      expect(s.visibleOnAnyScreen(oneScreen()), isTrue);
    });

    test('跨双屏(负坐标副屏)→ 可见', () {
      final screens = [
        const Rect.fromLTWH(0, 0, 1920, 1080),
        const Rect.fromLTWH(-1920, 0, 1920, 1080),
      ];
      const s = WindowState(x: -2000, y: 100, w: 800, h: 600, maximized: false);
      expect(s.visibleOnAnyScreen(screens), isTrue);
    });

    test('完全出屏右侧(副屏已拔)→ 不可见 → 丢弃回默认', () {
      const s = WindowState(x: 2500, y: 0, w: 800, h: 600, maximized: false);
      expect(s.visibleOnAnyScreen(oneScreen()), isFalse);
    });

    test('完全出屏左侧 → 不可见', () {
      const s = WindowState(x: -3000, y: 0, w: 800, h: 600, maximized: false);
      expect(s.visibleOnAnyScreen(oneScreen()), isFalse);
    });

    test('仅边缘相接(零面积交集)→ 不可见', () {
      const s = WindowState(x: 1920, y: 0, w: 800, h: 600, maximized: false);
      expect(s.visibleOnAnyScreen(oneScreen()), isFalse);
    });

    test('空屏幕列表 → 不可见(fail-safe 回默认)', () {
      const s = WindowState(x: 0, y: 0, w: 800, h: 600, maximized: false);
      expect(s.visibleOnAnyScreen(const []), isFalse);
    });
  });

  // ── S1:恢复(顺序 = setBounds 先于 maximize;channel mock) ────────
  group('restore (S1, 恢复排序断言)', () {
    Future<void> seedStorage(String raw) async {
      when(() => storage.read(key: 'window_state'))
          .thenAnswer((_) async => raw);
    }

    test('常规态:仅 setBounds 一次,无 maximize', () async {
      await seedStorage(
          '{"x":100,"y":50,"w":800,"h":600,"maximized":false}');
      final controller = mk();
      await controller.restore();

      expect(windowLog.calls.where((m) => m == 'setBounds'), hasLength(1));
      expect(windowLog.calls.where((m) => m == 'maximize'), isEmpty);
      // setBounds 参数与保存几何一致(logical 坐标直传)。
      final args = windowLog.arguments['setBounds'] as Map;
      expect(args['x'], 100);
      expect(args['y'], 50);
      expect(args['width'], 800);
      expect(args['height'], 600);
    });

    test('最大化态:调用序 setBounds → maximize(次序断言)', () async {
      await seedStorage(
          '{"x":100,"y":50,"w":800,"h":600,"maximized":true}');
      final controller = mk();
      await controller.restore();

      final order = windowLog.calls
          .where((m) => m == 'setBounds' || m == 'maximize')
          .toList();
      expect(order, ['setBounds', 'maximize']); // 先几何后最大化,不可倒
    });

    test('出屏(显示器已拔):不 setBounds 不 maximize → runner 默认居中',
        () async {
      await seedStorage(
          '{"x":5000,"y":0,"w":800,"h":600,"maximized":true}');
      final controller = mk();
      await controller.restore();

      expect(windowLog.calls.where((m) => m == 'setBounds'), isEmpty);
      expect(windowLog.calls.where((m) => m == 'maximize'), isEmpty);
    });

    test('非法 json / 无存储:零调用回落默认(尺寸过小已改钳制恢复,见 min-size 组)', () async {
      for (final raw in [
        'corrupt',
      ]) {
        windowLog.calls.clear();
        await seedStorage(raw);
        await mk().restore();
        expect(windowLog.calls.where((m) => m == 'setBounds'), isEmpty,
            reason: raw);
      }

      when(() => storage.read(key: 'window_state')).thenAnswer((_) async => null);
      windowLog.calls.clear();
      await mk().restore();
      expect(windowLog.calls.where((m) => m == 'setBounds'), isEmpty);
      expect(windowLog.calls.where((m) => m == 'maximize'), isEmpty);
    });

    test('restore 与 load 竞态:读未完成前不 setBounds,完成后恢复', () async {
      final gate = Completer<String?>();
      when(() => storage.read(key: 'window_state')).thenAnswer((_) => gate.future);
      final controller = mk();
      final restoring = controller.restore();
      await Future<void>.delayed(Duration.zero);

      // 读未决:不得提前恢复(默认几何也不该被碰)。
      expect(windowLog.calls.where((m) => m == 'setBounds'), isEmpty);

      gate.complete('{"x":100,"y":50,"w":800,"h":600,"maximized":false}');
      await restoring;
      expect(windowLog.calls.where((m) => m == 'setBounds'), hasLength(1));
    });

    test('窗口 API 抛错 → 静默降级不炸(NFR 附属功能)', () async {
      await seedStorage(
          '{"x":100,"y":50,"w":800,"h":600,"maximized":false}');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (call) async => throw PlatformException(code: 'boom'),
      );
      final controller = mk();
      await controller.restore(); // 不得抛
      expect(controller, isNotNull);
    });

    test('load 幂等:重复调用不重复读 storage', () async {
      var reads = 0;
      when(() => storage.read(key: 'window_state')).thenAnswer((_) async {
        reads++;
        return '{"x":1,"y":2,"w":640,"h":480,"maximized":false}';
      });
      final controller = mk();
      await controller.load();
      await controller.load();
      await controller.restore();
      expect(reads, 1);
    });
  });

  // ── S2:生产屏幕矩形派生(screen_retriever channel mock) ──────────
  group('defaultScreenRanges (S2)', () {
    test('Display(visiblePosition/visibleSize)→ Rect 映射;缺省回落全屏',
        () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.leanflutter.plugins/screen_retriever'),
        (call) async {
          expect(call.method, 'getAllDisplays');
          return {
            'displays': [
              {
                'id': 'primary',
                'size': {'width': 1920.0, 'height': 1080.0},
                'visiblePosition': {'dx': 0.0, 'dy': 0.0},
                'visibleSize': {'width': 1920.0, 'height': 1040.0},
              },
              {
                'id': 'secondary-left',
                'size': {'width': 1280.0, 'height': 720.0},
                'visiblePosition': {'dx': -1280.0, 'dy': 40.0},
                // 无 visibleSize → 回落 size 全屏。
              },
            ],
          };
        },
      );
      addTearDown(() => messenger.setMockMethodCallHandler(
          const MethodChannel('dev.leanflutter.plugins/screen_retriever'),
          null));

      final ranges = await WindowStateController.defaultScreenRanges();
      expect(ranges, [
        const Rect.fromLTWH(0, 0, 1920, 1040), // 工作区
        const Rect.fromLTWH(-1280, 40, 1280, 720), // 负坐标副屏,全屏回落
      ]);
    });

    test('查询失败/空列表 → 空表(fail-safe:交集恒假 → 回默认)', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.leanflutter.plugins/screen_retriever'),
        (call) async => {'displays': []}, // 空表被插件抛错 → 语义同失败
      );
      addTearDown(() => messenger.setMockMethodCallHandler(
          const MethodChannel('dev.leanflutter.plugins/screen_retriever'),
          null));

      expect(await WindowStateController.defaultScreenRanges(), isEmpty);
    });
  });

  // ── S1:保存(防抖 500ms 合流;最大化不覆盖常规 bounds) ────────────
  group('save debounce (S1)', () {
    test('move×3 防抖合流为 1 次落盘;窗口内(499ms)不写', () {
      fakeAsync((async) {
        final controller = mk();
        controller.start();

        controller.onWindowMove();
        controller.onWindowMove();
        controller.onWindowResize();
        async.elapse(const Duration(milliseconds: 499));
        expect(storageWrites, isEmpty); // 防抖窗口内未落盘

        async.elapse(const Duration(milliseconds: 2));
        expect(storageWrites, hasLength(1)); // 3 事件合流 1 次
        final persisted = lastPersisted()!;
        // flush 时捕获 getBounds + isMaximized=false 的真值。
        expect(persisted.rect, const Rect.fromLTWH(100, 50, 800, 600));
        expect(persisted.maximized, isFalse);

        controller.stop();
        async.flushMicrotasks();
      });
    });

    test('新事件重置防抖窗口(tray watch 防抖同款语义)', () {
      fakeAsync((async) {
        final controller = mk();
        controller.start();

        controller.onWindowMove();
        async.elapse(const Duration(milliseconds: 400));
        controller.onWindowMove(); // 重置
        async.elapse(const Duration(milliseconds: 400));
        expect(storageWrites, isEmpty); // 距末次事件不足 500ms
        async.elapse(const Duration(milliseconds: 100));
        expect(storageWrites, hasLength(1));

        controller.stop();
        async.flushMicrotasks();
      });
    });

    test('onWindowEvent 只认 maximize/unmaximize;其他事件不触发', () {
      fakeAsync((async) {
        final controller = mk();
        controller.start();

        controller.onWindowEvent('focus');
        controller.onWindowEvent('move'); // move 走专用钩子,此处不重复算
        async.elapse(const Duration(seconds: 2));
        expect(storageWrites, isEmpty);

        controller.onWindowEvent('maximize');
        async.elapse(const Duration(milliseconds: 500));
        expect(storageWrites, hasLength(1));

        controller.stop();
        async.flushMicrotasks();
      });
    });

    test('最大化:保留已存常规 bounds 只翻 flag(还原后 unmaximize 回原几何)',
        () {
      fakeAsync((async) {
        // 预置已存常规几何 800×600。
        when(() => storage.read(key: 'window_state')).thenAnswer((_) async =>
            '{"x":100,"y":50,"w":800,"h":600,"maximized":false}');
        final controller = mk();
        // ignore: unawaited_futures
        controller.load();
        async.flushMicrotasks();

        // 用户最大化:flush 时 isMaximized=true、getBounds 已是最大化帧
        // (-8,-8,1936,1056)—— 不得用它覆盖常规 bounds。
        maximizedNow = true;
        boundsNow = const Rect.fromLTWH(-8, -8, 1936, 1056);
        controller.start();
        controller.onWindowEvent('maximize');
        async.elapse(const Duration(milliseconds: 500));

        expect(storageWrites, hasLength(1));
        final persisted = lastPersisted()!;
        expect(persisted.rect, const Rect.fromLTWH(100, 50, 800, 600));
        expect(persisted.maximized, isTrue);

        controller.stop();
        async.flushMicrotasks();
      });
    });

    test('取消最大化:捕获新常规几何 + flag=false', () {
      fakeAsync((async) {
        when(() => storage.read(key: 'window_state')).thenAnswer((_) async =>
            '{"x":100,"y":50,"w":800,"h":600,"maximized":true}');
        final controller = mk();
        // ignore: unawaited_futures
        controller.load();
        async.flushMicrotasks();

        maximizedNow = false;
        boundsNow = const Rect.fromLTWH(240, 120, 900, 700);
        controller.start();
        controller.onWindowEvent('unmaximize');
        async.elapse(const Duration(milliseconds: 500));

        final persisted = lastPersisted()!;
        expect(persisted.rect, const Rect.fromLTWH(240, 120, 900, 700));
        expect(persisted.maximized, isFalse);

        controller.stop();
        async.flushMicrotasks();
      });
    });

    test('首启即最大化(无既有 bounds):仍捕获当前几何落盘(不丢偏好)',
        () {
      fakeAsync((async) {
        maximizedNow = true;
        boundsNow = const Rect.fromLTWH(-8, -8, 1936, 1056);
        final controller = mk();
        controller.start();
        controller.onWindowEvent('maximize');
        async.elapse(const Duration(milliseconds: 500));

        expect(storageWrites, hasLength(1));
        expect(lastPersisted()!.maximized, isTrue);

        controller.stop();
        async.flushMicrotasks();
      });
    });

    test('落盘键 = window_state,值为 json 编码', () {
      fakeAsync((async) {
        final controller = mk();
        controller.start();
        controller.onWindowMove();
        async.elapse(const Duration(milliseconds: 500));

        expect(storageWrites.single.arguments, isA<String>());
        final map = jsonDecode(storageWrites.single.arguments as String)
            as Map<String, dynamic>;
        expect(map.keys.toSet(), {'x', 'y', 'w', 'h', 'maximized'});

        controller.stop();
        async.flushMicrotasks();
      });
    });

    test('stop():撤插件监听 + 取消在途防抖(不落盘)', () {
      fakeAsync((async) {
        final controller = mk();
        controller.start();
        controller.onWindowMove();
        controller.stop();
        async.elapse(const Duration(seconds: 5));
        expect(storageWrites, isEmpty); // 在途防抖已取消
      });
    });
  });
}
