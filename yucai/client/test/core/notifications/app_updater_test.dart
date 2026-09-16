import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/notifications/app_updater.dart';

/// F24 T2:客户端自动更新接入(app_updater = WinSparkle,ADR-1/4)。
///
/// 引擎经方法通道 `dev.leanflutter.plugins/auto_updater` 下发(channel mock
/// 手法照 tray_controller_test 先例);降级路径以「引擎抛错 → 不冒泡」断言
/// (NFR-1:更新子系统任一环节失败不阻断 app 启动与既有功能)。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late bool failNext;

  setUp(() {
    calls = [];
    failNext = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.leanflutter.plugins/auto_updater'),
      (call) async {
        calls.add(call);
        if (failNext) {
          throw PlatformException(code: 'engine-unavailable');
        }
        return null;
      },
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(
          const MethodChannel('dev.leanflutter.plugins/auto_updater'), null);
    });
  });

  group('常量(FR-2/FR-3)', () {
    test('feedUrl = latest release appcast 恒定地址(URL 稳定,零基础设施)',
        () {
      expect(
        AppUpdater.feedUrl,
        'https://github.com/williamparris1995/syfinance/releases/latest/download/appcast.xml',
      );
    });

    test('公钥占位标记(D-1 真钥接入后为 false,防演练带占位发版)', () {
      expect(AppUpdater.publicKeyIsPlaceholder, isFalse);
    });
  });

  group('initialize(FR-4:引擎 wiring)', () {
    test('setFeedURL 下发 feed 常量(native 侧 win_sparkle_init 即启动默认 1 天调度)',
        () async {
      await AppUpdater.initialize();

      expect(calls.single.method, 'setFeedURL');
      expect(calls.single.arguments, {'feedURL': AppUpdater.feedUrl});
    });
  });

  group('checkForUpdates(FR-5:手动检查入口)', () {
    test('前台检查 = 引擎 UI(win_sparkle_check_update_with_ui)', () async {
      await AppUpdater.checkForUpdates();

      expect(calls.single.method, 'checkForUpdates');
      expect(calls.single.arguments, {'inBackground': false});
    });
  });

  group('bootstrapAppUpdater 降级(ADR-4/NFR-1,挂 bootstrap 末尾)', () {
    test('引擎抛错 → 吞掉不冒泡(附属降级,不阻断 app 启动)', () async {
      failNext = true;

      // 不抛即降级成立:更新子系统失败绝不阻断启动。
      await bootstrapAppUpdater();
    });

    test('正常路径走 setFeedURL(feed 常量单源)', () async {
      await bootstrapAppUpdater();

      expect(calls.map((c) => c.method), contains('setFeedURL'));
    });
  });
}
