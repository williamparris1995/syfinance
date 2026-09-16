import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tray_manager/tray_manager.dart' show MenuItem;
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
    bool showTrayAmounts = true,
  })  : _close = ValueNotifier<TrayCloseBehavior>(closeBehavior),
        _prompted = ValueNotifier<bool>(firstClosePrompted),
        _scan = ValueNotifier<TrayScanInterval>(scanInterval),
        _amounts = ValueNotifier<bool>(showTrayAmounts);

  final ValueNotifier<TrayCloseBehavior> _close;
  final ValueNotifier<bool> _prompted;
  final ValueNotifier<TrayScanInterval> _scan;
  final ValueNotifier<bool> _amounts;
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
  bool get showTrayAmounts => _amounts.value;

  @override
  ValueListenable<bool> get showTrayAmountsListenable => _amounts;

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

  @override
  Future<void> setShowTrayAmounts(bool show) async {
    _amounts.value = show;
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
/// [menus] 额外记录 setContextMenu 下发的 menu JSON(F25 数据头 label
/// 断言面)。
class _ChannelLog {
  final calls = <String>[];
  final menus = <String>[];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ChannelLog windowLog;
  late _ChannelLog trayLog;
  late _ExitSpy exitSpy;
  late List<MethodCall> updaterCalls;
  late bool updaterFailNext;

  Future<ScanResult> scanOk() async => const ScanResult(scanned: 0, sent: 0);

  setUp(() {
    windowLog = _ChannelLog();
    trayLog = _ChannelLog();
    exitSpy = _ExitSpy();
    updaterCalls = [];
    updaterFailNext = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (call) async {
        windowLog.calls.add(call.method);
        // 查询型方法(isMinimized/isVisible 等)需 bool 返回,null 会使
        // window_manager 内部 cast 抛错(F25 记一笔测试首触 show() 路径)。
        return call.method.startsWith('is') ? false : null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('tray_manager'),
      (call) async {
        trayLog.calls.add(call.method);
        if (call.method == 'setContextMenu') {
          trayLog.menus.add(jsonEncode(call.arguments['menu']));
        }
        return null;
      },
    );
    // F24:auto_updater 引擎 channel(「检查更新」菜单项的调用/降级断言面)。
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.leanflutter.plugins/auto_updater'),
      (call) async {
        updaterCalls.add(call);
        if (updaterFailNext) {
          throw PlatformException(code: 'engine-unavailable');
        }
        return null;
      },
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(
          const MethodChannel('window_manager'), null);
      messenger.setMockMethodCallHandler(
          const MethodChannel('tray_manager'), null);
      messenger.setMockMethodCallHandler(
          const MethodChannel('dev.leanflutter.plugins/auto_updater'), null);
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
    TrayHeadProvider? headProvider,
    Future<void> Function()? newTransactionNav,
    Future<String?> Function()? versionProvider,
  }) =>
      TrayController(
        scan: scanOk,
        settings: settings,
        closePrompt: closePrompt,
        contextResolver: contextResolver,
        headProvider: headProvider,
        newTransactionNav: newTransactionNav,
        versionProvider: versionProvider,
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

  group('托盘菜单(FR-6 + F25 数据头/快捷操作 + F24 更新/版本项)', () {
    test('菜单枚举(验收调序):记一笔置顶 + 数据头 + 检查更新/版本 + 退出(无显示御财)',
        () {
      const head = TrayHeadData(
        todayIncomeCents: 123456, // ¥1,234
        todayExpenseCents: 7890, // ¥78
        monthBalanceCents: 12345, // +¥123
      );
      final items = TrayController.buildContextMenu(head: head);

      // 分隔线无 key,非空 key 枚举 = 六个语义项;顺序 = 验收调序拍板。
      final keys =
          items.map((i) => i.key).whereType<String>().toList();
      expect(keys, ['new_transaction', 'head_today', 'head_month', 'check_update', 'version', 'quit']);
      // 「显示御财」已撤(左键单击即显示)。
      expect(keys, isNot(contains('show')));
      expect(items.any((i) => i.type == 'separator'), isTrue);

      // FR-1:数据头两行 disabled(仅速览不可点)+ 金额文案逐字。
      final today = items.firstWhere((i) => i.key == 'head_today');
      expect(today.disabled, isTrue);
      expect(today.label, '今日 收 ¥1,234 · 支 ¥78');
      final month = items.firstWhere((i) => i.key == 'head_month');
      expect(month.disabled, isTrue);
      expect(month.label, '本月结余 +¥123');

      // F24 FR-6:检查更新 enabled;版本项 disabled;两項同置于数据头
      // 之下、显示御财之上(spec FR-6 位置约束)。
      final check = items.firstWhere((i) => i.key == 'check_update');
      expect(check.disabled, isFalse);
      expect(check.label, '检查更新');
      final version = items.firstWhere((i) => i.key == 'version');
      expect(version.disabled, isTrue);
      // 验收调序:记一笔居首,退出居尾,检查更新在版本号前。
      expect(keys.first, 'new_transaction');
      expect(keys.last, 'quit');
      expect(keys.indexOf('check_update'), lessThan(keys.indexOf('version')));

      // FR-2:记一笔(可点,位于数据头与显示御财之间)。
      final newTxn = items.firstWhere((i) => i.key == 'new_transaction');
      expect(newTxn.disabled, isFalse);
      expect(newTxn.label, '记一笔');
      expect(keys.indexOf('head_today'), lessThan(keys.indexOf('quit')));

      // 「立即检查」仍已撤。
      expect(items.map((i) => i.label ?? ''),
          isNot(contains(contains('立即检查'))));
    });

    test('负结余 → -¥;零结余不带符号', () {
      const head = TrayHeadData(
        todayIncomeCents: 0,
        todayExpenseCents: 0,
        monthBalanceCents: -12345,
      );
      final items = TrayController.buildContextMenu(head: head);
      expect(items.firstWhere((i) => i.key == 'head_month').label,
          '本月结余 -¥123');

      const zero = TrayHeadData(
          todayIncomeCents: 0, todayExpenseCents: 0, monthBalanceCents: 0);
      expect(
        TrayController.buildContextMenu(head: zero)
            .firstWhere((i) => i.key == 'head_month')
            .label,
        '本月结余 ¥0',
      );
    });

    test('showAmounts=false → 「金额已隐藏」单行(FR-3 隐藏态)', () {
      const head = TrayHeadData(
          todayIncomeCents: 1, todayExpenseCents: 2, monthBalanceCents: 3);
      final items =
          TrayController.buildContextMenu(head: head, showAmounts: false);
      // 隐藏 → 单行占位(design LLD:单行,不出两行空壳)。
      final keys = items.map((i) => i.key).whereType<String>().toList();
      expect(keys, ['new_transaction', 'head', 'check_update', 'version', 'quit']);
      final headItem = items.firstWhere((i) => i.key == 'head');
      expect(headItem.disabled, isTrue);
      expect(headItem.label, '金额已隐藏');
    });

    test('head=null(查询失败/未注入)→ 「--」占位(FR-4/NFR-1)', () {
      final items = TrayController.buildContextMenu();
      final keys = items.map((i) => i.key).whereType<String>().toList();
      expect(keys, ['new_transaction', 'head', 'check_update', 'version', 'quit']);
      final headItem = items.firstWhere((i) => i.key == 'head');
      expect(headItem.disabled, isTrue);
      expect(headItem.label, '--');
      // 「--」不阻断其余菜单项(NFR-1)。
      expect(keys, containsAll(['new_transaction', 'check_update', 'version', 'quit']));
    });

    test('formatTrayAmount:千分位/整元/负号(F25 金额格式)', () {
      expect(TrayController.formatTrayAmount(0), '¥0');
      expect(TrayController.formatTrayAmount(123456), '¥1,234'); // 分截断
      expect(TrayController.formatTrayAmount(123456789), '¥1,234,567');
      expect(TrayController.formatTrayAmount(100000000), '¥1,000,000');
      expect(TrayController.formatTrayAmount(-12345), '-¥123');
    });

    test('formatTrayBalance:正 +/负 -/零无符号(design LLD)', () {
      expect(TrayController.formatTrayBalance(12345), '+¥123');
      expect(TrayController.formatTrayBalance(-12345), '-¥123');
      expect(TrayController.formatTrayBalance(0), '¥0');
      expect(TrayController.formatTrayBalance(123456789), '+¥1,234,567');
    });
  });

  group('「记一笔」快捷操作(F25 FR-2/ADR-4)', () {
    test('点击 → 显示并聚焦窗口 + 导航闭包调用一次', () async {
      var navCalls = 0;
      final controller = mk(newTransactionNav: () async => navCalls++);
      controller.onTrayMenuItemClick(
          MenuItem(key: 'new_transaction', label: '记一笔'));
      await pump();

      expect(windowLog.calls.where((m) => m == 'show'), isNotEmpty);
      expect(windowLog.calls.where((m) => m == 'focus'), isNotEmpty);
      expect(navCalls, 1);
    });

    test('导航闭包未注入 → 降级仅 show/focus,不炸', () async {
      final controller = mk();
      controller.onTrayMenuItemClick(
          MenuItem(key: 'new_transaction', label: '记一笔'));
      await pump();

      expect(windowLog.calls.where((m) => m == 'show'), isNotEmpty);
      expect(windowLog.calls.where((m) => m == 'focus'), isNotEmpty);
    });

    test('导航闭包抛错(极端时序无 context 等)→ 吞掉不炸', () async {
      final errors = <Object>[];
      final controller = mk(
          newTransactionNav: () async => throw StateError('no context'));
      runZonedGuarded<void>(
          () => controller.onTrayMenuItemClick(
              MenuItem(key: 'new_transaction', label: '记一笔')),
          (e, _) => errors.add(e));
      await pump();

      expect(windowLog.calls.where((m) => m == 'show'), isNotEmpty);
      expect(errors, isEmpty); // 降级不炸(NFR-1)
    });
  });

  group('F24 检查更新 + 版本项(FR-5/FR-6/ADR-5)', () {
    test('formatVersionLabel:御财 vX.Y.Z 组装;null/空 → 降级「御财」', () {
      expect(TrayController.formatVersionLabel('1.2.3'), '御财 v1.2.3');
      expect(TrayController.formatVersionLabel('10.20.30'), '御财 v10.20.30');
      expect(TrayController.formatVersionLabel(null), '御财');
      expect(TrayController.formatVersionLabel(''), '御财');
    });

    test('buildContextMenu(version:) → 版本项带 vX.Y.Z 文案(FR-6)', () {
      final items = TrayController.buildContextMenu(
          head: null, version: '1.2.3');
      expect(items.firstWhere((i) => i.key == 'version').label, '御财 v1.2.3');
    });

    test('点击「检查更新」→ auto_updater 引擎前台检查(channel mock 断言)',
        () async {
      final controller = mk();
      controller.onTrayMenuItemClick(
          MenuItem(key: 'check_update', label: '检查更新'));
      await pump();

      expect(updaterCalls.single.method, 'checkForUpdates');
      expect(updaterCalls.single.arguments, {'inBackground': false});
    });

    test('引擎抛错(未初始化/平台缺失)→ 吞掉不炸(降级,NFR-1)', () async {
      final errors = <Object>[];
      updaterFailNext = true;
      final controller = mk();
      runZonedGuarded<void>(
          () => controller.onTrayMenuItemClick(
              MenuItem(key: 'check_update', label: '检查更新')),
          (e, _) => errors.add(e));
      await pump();

      expect(errors, isEmpty); // 手动检查项恒可点、恒不炸
    });

    test('versionProvider 并入 _refreshMenu 数据流:窗口 show → 菜单带 vX.Y.Z'
        '(刷新触发复用 F25 机制)', () async {
      final controller = mk(
        headProvider: () async => null,
        versionProvider: () async => '1.2.3',
      );
      controller.onWindowEvent('show');
      await pump();

      expect(trayLog.menus.last, contains('御财 v1.2.3'));
    });

    test('版本只取一次缓存:两次刷新 → provider 单次调用', () async {
      var providerCalls = 0;
      final controller = mk(
        headProvider: () async => null,
        versionProvider: () async {
          providerCalls++;
          return '1.2.3';
        },
      );
      controller.onWindowEvent('show');
      await pump();
      controller.onWindowEvent('show');
      await pump();

      expect(providerCalls, 1); // 首刷已缓存,后续刷新直接复用
      expect(trayLog.menus.last, contains('御财 v1.2.3'));
    });

    test('versionProvider 抛错 → 降级「御财」,不炸(NFR-1)', () async {
      final errors = <Object>[];
      final controller = mk(
        headProvider: () async => null,
        versionProvider: () async => throw StateError('package_info missing'),
      );
      runZonedGuarded<void>(
          () => controller.onWindowEvent('show'), (e, _) => errors.add(e));
      await pump();

      expect(errors, isEmpty);
      expect(trayLog.menus.last, contains('"御财"')); // 无版本后缀
    });

    test('versionProvider 未注入 → 版本项降级「御财」(等价改造前无该项能力)',
        () async {
      final controller = mk(headProvider: () async => null);
      controller.onWindowEvent('show');
      await pump();

      expect(trayLog.menus.last, contains('"御财"'));
      expect(trayLog.menus.last, isNot(contains('御财 v')));
    });
  });

  group('菜单刷新三触发(F25 FR-4/ADR-2)', () {
    test('start() 托盘注册成功后即刷首次数据头(先注册后填充,不阻塞就绪)',
        () {
      fakeAsync((async) {
        final controller = TrayController(
          scan: scanOk,
          settings: _FakeTraySettings(),
          traySetup: () async => true,
          headProvider: () async => const TrayHeadData(
              todayIncomeCents: 123456,
              todayExpenseCents: 7890,
              monthBalanceCents: 12345),
          exitFn: exitSpy.exit0,
        );
        unawaited(controller.start());
        async.flushMicrotasks();
        // 查询异步:注册就绪不被 _refreshMenu 阻塞(design LLD 首启顺序)。
        expect(controller.trayReady, isTrue);
        async.flushMicrotasks();
        final sets = trayLog.calls.where((m) => m == 'setContextMenu');
        expect(sets, isNotEmpty);
        expect(trayLog.menus.last, contains('今日 收 ¥1,234 · 支 ¥78'));
        expect(trayLog.menus.last, contains('本月结余 +¥123'));

        unawaited(controller.stop());
        async.flushMicrotasks();
      });
    });

    test('watch 防抖尾随菜单重设(数据变更 → 先扫后刷菜单)', () {
      fakeAsync((async) {
        final sc = StreamController<void>.broadcast();
        var providerCalls = 0;
        final controller = TrayController(
          scan: scanOk,
          settings: _FakeTraySettings(),
          changeTriggers: [sc.stream],
          traySetup: () async => true,
          headProvider: () async {
            providerCalls++;
            return null; // null → 「--」路径同时被覆盖
          },
          exitFn: exitSpy.exit0,
        );
        unawaited(controller.start());
        async.flushMicrotasks();
        final before = trayLog.calls.where((m) => m == 'setContextMenu').length;

        sc.add(null);
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        // 防抖到点:扫描 + 菜单重设(provider 被再次消费)。
        expect(providerCalls, greaterThan(1));
        expect(trayLog.calls.where((m) => m == 'setContextMenu').length,
            greaterThan(before));
        expect(trayLog.menus.last, contains('--'));

        unawaited(controller.stop());
        async.flushMicrotasks();
      });
    });

    test('窗口 show 事件 → 重设菜单;其他事件不触发', () async {
      final controller = mk(headProvider: () async => null);
      final before = trayLog.calls.where((m) => m == 'setContextMenu').length;

      controller.onWindowEvent('focus'); // 非 show 事件:不触发
      await pump();
      expect(trayLog.calls.where((m) => m == 'setContextMenu').length, before);

      controller.onWindowEvent('show');
      await pump();
      expect(trayLog.calls.where((m) => m == 'setContextMenu').length,
          greaterThan(before));
      expect(trayLog.menus.last, contains('--'));
    });

    test('showTrayAmounts 切换即时重设菜单(隐藏 → 「金额已隐藏」)', () {
      fakeAsync((async) {
        final settings = _FakeTraySettings();
        final controller = TrayController(
          scan: scanOk,
          settings: settings,
          traySetup: () async => true,
          headProvider: () async => const TrayHeadData(
              todayIncomeCents: 1, todayExpenseCents: 2, monthBalanceCents: 3),
          exitFn: exitSpy.exit0,
        );
        unawaited(controller.start());
        async.flushMicrotasks();
        expect(trayLog.menus.last, contains('今日 收'));

        // F25 FR-3:切换即时生效(菜单重设)。
        unawaited(settings.setShowTrayAmounts(false));
        async.flushMicrotasks();
        expect(trayLog.menus.last, contains('金额已隐藏'));
        expect(trayLog.menus.last, isNot(contains('今日 收')));

        unawaited(controller.stop());
        async.flushMicrotasks();
      });
    });

    test('provider 抛错 → 「--」占位,不炸(NFR-1)', () async {
      final errors = <Object>[];
      final controller =
          mk(headProvider: () async => throw StateError('db corrupted'));
      runZonedGuarded<void>(
          () => controller.onWindowEvent('show'), (e, _) => errors.add(e));
      await pump();

      expect(errors, isEmpty);
      expect(trayLog.menus.last, contains('--'));
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

/// F23 P1:托盘图标落盘判定 —— 内容不一致即覆盖(升级用户换新图标)。
group('trayIconNeedsWrite (F23 P1)', () {
  test('目标不存在 → 需写入', () async {
    final f = File('${Directory.systemTemp.path}/yc_tray_${DateTime.now().microsecondsSinceEpoch}.ico');
    expect(await TrayController.trayIconNeedsWrite(f, [1, 2, 3]), isTrue);
  });
  test('内容一致 → 跳过;不一致 → 覆盖(升级换图)', () async {
    final f = File('${Directory.systemTemp.path}/yc_tray_${DateTime.now().microsecondsSinceEpoch}.ico');
    await f.writeAsBytes([1, 2, 3], flush: true);
    expect(await TrayController.trayIconNeedsWrite(f, [1, 2, 3]), isFalse);
    expect(await TrayController.trayIconNeedsWrite(f, [1, 2, 4]), isTrue);
    expect(await TrayController.trayIconNeedsWrite(f, [1, 2]), isTrue);
    await f.delete();
  });
});

/// 验收热修(2026-09-16):右键托盘 → Dart 侧主动 popUpContextMenu
/// (tray_manager 0.5.3 原生只发事件不弹菜单,自 R7 起右键从未工作)。
group('onTrayIconRightMouseDown (验收热修)', () {
  test('trayReady → popUpContextMenu 恰一次', () async {
    final tray = mk();
    tray.onTrayIconRightMouseDown();
    await pump();
    expect(trayLog.calls.where((m) => m == 'popUpContextMenu'), hasLength(1));
  });

  test('托盘未就绪 → 不弹', () async {
    final tray = mk()..trayReady = false;
    tray.onTrayIconRightMouseDown();
    await pump();
    expect(trayLog.calls.where((m) => m == 'popUpContextMenu'), isEmpty);
  });
});
}
