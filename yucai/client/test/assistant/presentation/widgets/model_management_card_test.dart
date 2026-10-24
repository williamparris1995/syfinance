// F65 T4(2026-10-24):「AI 助手」端侧模型管理卡 widget 测试(spec FR-3 两
// 场景;文案照 prototype v19 ui/assistant-chat-states.html「AI 助手 · 端侧
// 模型管理」卡措辞基调)。
//
// seam = ModelManagementCard 公共构造三注入缝(AssistantSettings /
// ModelManagerPort / EngineManager 全 fake)。覆盖:ModelState 五态
// (notDownloaded 引导/downloading 进度+暂停/paused 续传/error 双因区分
// 文案+重试/ready 就绪+占用+删除确认门)/EngineState 四态(stopped /
// starting 转圈 / ready 运行中 / error 可重试)/启用开关落盘(行内直改
// 零弹窗)/fake 状态流转驱动重渲染/守门硬约束。
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/assistant/data/assistant_settings_store.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/assistant/domain/engine_port.dart';
import 'package:yucai_client/assistant/domain/engine_state.dart';
import 'package:yucai_client/assistant/domain/model_manager_port.dart';
import 'package:yucai_client/assistant/domain/model_state.dart';
import 'package:yucai_client/assistant/presentation/widgets/model_management_card.dart';

/// Fake AssistantSettings(照 llm_settings_card_test._FakeLlmSettings 范式):
/// notifier 驱动开关选中态;记录全部 setConfig 调用供落盘断言。
class _FakeAssistantSettings extends Fake implements AssistantSettings {
  _FakeAssistantSettings(AssistantConfig initial)
      : _notifier = ValueNotifier(initial);
  final ValueNotifier<AssistantConfig> _notifier;
  final List<AssistantConfig> saved = [];

  @override
  AssistantConfig get value => _notifier.value;

  @override
  ValueListenable<AssistantConfig> get listenable => _notifier;

  @override
  Future<void> setConfig(AssistantConfig config) async {
    saved.add(config);
    _notifier.value = config;
  }
}

/// Fake ModelManagerPort:ValueNotifier 直驱状态流转;计数全部用户动作。
class _FakeModelManager implements ModelManagerPort {
  _FakeModelManager(ModelState initial) : state = ValueNotifier(initial);

  @override
  final ValueNotifier<ModelState> state;

  int downloadCalls = 0;
  int pauseCalls = 0;
  int cancelCalls = 0;
  int deleteCalls = 0;

  /// diskUsageBytes() 回值(默认 = manifest 实值)。
  int usageBytes = kModelManifest.totalBytes;

  @override
  Future<void> download() async {
    downloadCalls++;
  }

  @override
  void pause() {
    pauseCalls++;
  }

  @override
  void cancel() {
    cancelCalls++;
  }

  @override
  Future<void> delete() async {
    deleteCalls++;
  }

  @override
  Future<int> diskUsageBytes() async => usageBytes;

  @override
  ModelManifest get manifest => kModelManifest;
}

/// Fake EngineManager:ValueNotifier 直驱引擎态;计数 ensureReady 重试。
class _FakeEngineManager implements EngineManager {
  _FakeEngineManager(EngineState initial) : state = ValueNotifier(initial);

  @override
  final ValueNotifier<EngineState> state;

  int ensureReadyCalls = 0;

  @override
  Future<void> ensureReady() async {
    ensureReadyCalls++;
  }

  @override
  Future<void> shutdown() async {}

  @override
  void beginActivity() {}

  @override
  void endActivity() {}
}

/// 渲染型用 host(交互断言用例在测试体内自建 fake 持引用)。
Widget _host({
  required ModelState model,
  required EngineState engine,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(children: [
        ModelManagementCard(
          settings: _FakeAssistantSettings(const AssistantConfig(enabled: true)),
          modelManager: _FakeModelManager(model),
          engineManager: _FakeEngineManager(engine),
        ),
      ]),
    ),
  );
}

/// manifest 总量字面(kModelManifest.totalBytes = 2497281120;实例 getter
/// 不能进 const 表达式,测试内以 const 字面钉同值)。
const int _totalBytes = 2497281120;

/// 演示数据(照 v19:1.2GB / 2.5GB · 48%)。received 1.2e9 → 48.05% → 48%。
const _downloading = ModelDownloading(
  receivedBytes: 1200000000,
  totalBytes: _totalBytes,
  bytesPerSec: 8200000,
);

void main() {
  group('卡结构(ready 全景,v19 逐字基调)', () {
    testWidgets('标题 + 启用行 + 模型行(已就绪/占用) + 引擎行(运行中) + 隐私行',
        (tester) async {
      await tester.pumpWidget(_host(
        model: const ModelReady(),
        engine: EngineReady(Uri.parse('http://127.0.0.1:1/v1')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('AI 助手'), findsOneWidget); // 卡标题(与 F46 并列独立卡)
      // 启用行(v19 ready 卡):模型就绪 → 只读问答说明。
      expect(find.text('启用 AI 助手'), findsOneWidget);
      expect(find.text('浮层问答 · 本机运行 · 只读查询(v1)'), findsOneWidget);
      // 模型行(v19:「Qwen3-4B · 占用 2.5GB · v1」+ chip 已就绪)。
      expect(find.text('模型'), findsOneWidget);
      expect(find.text('Qwen3-4B · 占用 2.5GB · v1'), findsOneWidget);
      expect(find.text('已就绪'), findsOneWidget);
      expect(find.byKey(const ValueKey('assistantDeleteModelButton')),
          findsOneWidget, reason: 'ready 态出删除按钮(destructive)');
      // 引擎行(v19:「本机引擎 · 随应用启动」+ chip 运行中)。
      expect(find.text('引擎'), findsOneWidget);
      expect(find.text('本机引擎 · 随应用启动'), findsOneWidget);
      expect(find.text('运行中'), findsOneWidget);
      // 隐私行(v19:数据全程不出本机;零账号零密钥 + chip 纯端侧)。
      expect(find.text('数据与隐私'), findsOneWidget);
      expect(find.text('数据全程不出本机;零账号零密钥'), findsOneWidget);
      expect(find.text('纯端侧'), findsOneWidget);
    });
  });

  group('模型行 · notDownloaded(空态 = 首跑引导,FR-3 场景一)', () {
    testWidgets('「下载模型(约 2.5GB)」按钮 + 数据不出本机说明;点击真调 port.download',
        (tester) async {
      final settings = _FakeAssistantSettings(const AssistantConfig());
      final model = _FakeModelManager(const ModelNotDownloaded());
      final engine = _FakeEngineManager(const EngineStopped());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [
            ModelManagementCard(
                settings: settings, modelManager: model, engineManager: engine)
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('未下载'), findsOneWidget);
      expect(find.text('数据全程不出本机'), findsOneWidget);
      // 尺寸取 kModelManifest.totalBytes(2497281120 → 2.5GB,与 v19 一致;
      // 简报草案「约 2.4GB」为估写,以 T1 钉死清单实值为准)。
      expect(find.text('下载模型(约 2.5GB)'), findsOneWidget);
      expect(model.downloadCalls, 0);
      await tester.tap(find.byKey(const ValueKey('assistantDownloadButton')));
      await tester.pumpAndSettle();
      expect(model.downloadCalls, 1, reason: '按钮真调 fake port');
    });
  });

  group('模型行 · downloading(v19 对照卡逐字)', () {
    testWidgets('进度条 meta(已收/总量+百分比+速度)+ 暂停按钮 + 启用行切换为下载后说明',
        (tester) async {
      await tester.pumpWidget(_host(
        model: _downloading,
        engine: const EngineStopped(),
      ));
      await tester.pumpAndSettle();
      expect(find.text('下载中'), findsOneWidget);
      expect(find.text('Qwen3-4B · 2.5GB · v1'), findsOneWidget);
      expect(find.text('正在下载模型'), findsOneWidget);
      expect(find.text('1.2GB / 2.5GB · 48% · 8.2MB/s'), findsOneWidget,
          reason: 'received/total + 百分比 + 速度');
      expect(find.text('可断点续传 · 下载完成后即可离线使用'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
          find.byKey(const ValueKey('assistantModelProgress')));
      expect(bar.value, closeTo(1200000000 / kModelManifest.totalBytes, 0.001));
      // 启用行说明切换为 v19 下载卡措辞。
      expect(find.text('下载完成后自动进入问答'), findsOneWidget);
    });

    testWidgets('暂停按钮真调 port.pause', (tester) async {
      final settings = _FakeAssistantSettings(const AssistantConfig());
      final model = _FakeModelManager(_downloading);
      final engine = _FakeEngineManager(const EngineStopped());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [
            ModelManagementCard(
                settings: settings, modelManager: model, engineManager: engine)
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assistantPauseButton')));
      await tester.pumpAndSettle();
      expect(model.pauseCalls, 1);
    });
  });

  group('模型行 · paused(断点续传)', () {
    testWidgets('已暂停 chip + 已收进度 + 「继续下载」真调 port.download', (tester) async {
      final settings = _FakeAssistantSettings(const AssistantConfig());
      final model = _FakeModelManager(const ModelPaused(
        receivedBytes: 1200000000,
        totalBytes: _totalBytes,
      ));
      final engine = _FakeEngineManager(const EngineStopped());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [
            ModelManagementCard(
                settings: settings, modelManager: model, engineManager: engine)
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('已暂停'), findsOneWidget);
      expect(find.text('已下载 1.2GB / 2.5GB · 可断点续传'), findsOneWidget);
      expect(find.byKey(const ValueKey('assistantResumeButton')), findsOneWidget);
      expect(find.text('继续下载'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('assistantResumeButton')));
      await tester.pumpAndSettle();
      expect(model.downloadCalls, 1, reason: '继续下载 = download()(Range 续传)');
    });
  });

  group('模型行 · error(双因文案区分,corrupt 重试 = 从零)', () {
    testWidgets('network:网络中断文案 + 「重试」(可续传)真调 download', (tester) async {
      final settings = _FakeAssistantSettings(const AssistantConfig());
      final model =
          _FakeModelManager(const ModelError(ModelFailureReason.network));
      final engine = _FakeEngineManager(const EngineStopped());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [
            ModelManagementCard(
                settings: settings, modelManager: model, engineManager: engine)
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('下载失败'), findsOneWidget);
      expect(find.text('网络中断 · 断点已保留,重试可续传'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('assistantModelRetryButton')));
      await tester.pumpAndSettle();
      expect(model.downloadCalls, 1);
    });

    testWidgets('corrupt:校验失败文案 + 「重新下载」(从零)与 network 文案区分',
        (tester) async {
      final settings = _FakeAssistantSettings(const AssistantConfig());
      final model =
          _FakeModelManager(const ModelError(ModelFailureReason.corrupt));
      final engine = _FakeEngineManager(const EngineStopped());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [
            ModelManagementCard(
                settings: settings, modelManager: model, engineManager: engine)
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('下载失败'), findsOneWidget);
      expect(find.text('文件校验失败 · 重试将从零重新下载'), findsOneWidget);
      expect(find.text('重新下载'), findsOneWidget);
      expect(find.text('重试'), findsNothing, reason: 'corrupt 按钮文案区分');
      await tester.tap(find.byKey(const ValueKey('assistantModelRetryButton')));
      await tester.pumpAndSettle();
      expect(model.downloadCalls, 1,
          reason: '删 .part 从零整段重下由 impl.download() 承担(ADR-3)');
    });
  });

  group('ready 删除确认门(destructive)', () {
    testWidgets('取消:零删除调用', (tester) async {
      final settings = _FakeAssistantSettings(const AssistantConfig());
      final model = _FakeModelManager(const ModelReady());
      final engine = _FakeEngineManager(const EngineStopped());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [
            ModelManagementCard(
                settings: settings, modelManager: model, engineManager: engine)
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assistantDeleteModelButton')));
      await tester.pumpAndSettle();
      expect(find.text('删除模型?'), findsOneWidget, reason: '删除必经确认');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(model.deleteCalls, 0);
    });

    testWidgets('确认:真调 port.delete(引擎联动 shutdown 由 impl 承担)', (tester) async {
      final settings = _FakeAssistantSettings(const AssistantConfig());
      final model = _FakeModelManager(const ModelReady());
      final engine = _FakeEngineManager(const EngineStopped());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [
            ModelManagementCard(
                settings: settings, modelManager: model, engineManager: engine)
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assistantDeleteModelButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(model.deleteCalls, 1);
    });
  });

  group('启用开关(AssistantSettings.setConfig 落盘,行内直改零弹窗)', () {
    testWidgets('开 → setConfig(enabled:true) 落盘,全程无对话框', (tester) async {
      final settings = _FakeAssistantSettings(const AssistantConfig());
      final model = _FakeModelManager(const ModelReady());
      final engine = _FakeEngineManager(const EngineStopped());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [
            ModelManagementCard(
                settings: settings, modelManager: model, engineManager: engine)
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Switch>(find.byKey(const ValueKey('assistantEnableSwitch'))).value,
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('assistantEnableSwitch')));
      await tester.pumpAndSettle();
      // 中文行内确认无需弹窗(简报):全程零 Dialog(F46 首启用免责流不适用)。
      expect(find.byType(Dialog), findsNothing);
      expect(settings.saved, hasLength(1));
      expect(settings.saved.single.enabled, isTrue);
      expect(settings.saved.single.model, AssistantConfig.defaultModel,
          reason: 'copyWith 只改 enabled,模型 id 不动');
      expect(
        tester.widget<Switch>(find.byKey(const ValueKey('assistantEnableSwitch'))).value,
        isTrue,
      );
    });

    testWidgets('关 → setConfig(enabled:false)', (tester) async {
      final settings =
          _FakeAssistantSettings(const AssistantConfig(enabled: true));
      final model = _FakeModelManager(const ModelReady());
      final engine = _FakeEngineManager(const EngineStopped());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [
            ModelManagementCard(
                settings: settings, modelManager: model, engineManager: engine)
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assistantEnableSwitch')));
      await tester.pumpAndSettle();
      expect(settings.saved.single.enabled, isFalse);
    });
  });

  group('引擎行 · EngineState 四态(FR-3 场景二)', () {
    testWidgets('stopped → 未运行;starting → 启动中 + 转圈动效;ready → 运行中',
        (tester) async {
      await tester.pumpWidget(_host(
        model: const ModelReady(),
        engine: const EngineStopped(),
      ));
      await tester.pumpAndSettle();
      expect(find.text('未运行'), findsOneWidget);
      // starting:小转圈(F66 拍板:冷启 3-8s 须显动效)。indeterminate 动画
      // 不停 → 不能 pumpAndSettle,只 pump 推帧。
      await tester.pumpWidget(_host(
        model: const ModelReady(),
        engine: const EngineStarting(),
      ));
      await tester.pump();
      expect(find.text('启动中'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget,
          reason: 'starting 态运行中转圈小图标');
      await tester.pumpWidget(_host(
        model: const ModelReady(),
        engine: EngineReady(Uri.parse('http://127.0.0.1:1/v1')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('运行中'), findsOneWidget);
    });

    testWidgets('error(crashed) → 异常 chip + 原因文案 + 「重试」真调 ensureReady',
        (tester) async {
      final settings = _FakeAssistantSettings(const AssistantConfig());
      final model = _FakeModelManager(const ModelReady());
      final engine =
          _FakeEngineManager(const EngineError(EngineFailureReason.crashed));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [
            ModelManagementCard(
                settings: settings, modelManager: model, engineManager: engine)
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('异常'), findsOneWidget);
      expect(find.text('引擎进程异常退出'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('assistantEngineRetryButton')));
      await tester.pumpAndSettle();
      expect(engine.ensureReadyCalls, 1, reason: '异常退出可重试(FR-3 场景二)');
    });

    testWidgets('error(modelMissing) → 前置缺失文案引导先下载', (tester) async {
      await tester.pumpWidget(_host(
        model: const ModelNotDownloaded(),
        engine: const EngineError(EngineFailureReason.modelMissing),
      ));
      await tester.pumpAndSettle();
      expect(find.text('模型文件缺失,请先完成模型下载'), findsOneWidget);
    });
  });

  group('fake 状态流转(ValueNotifier 驱动重渲染)', () {
    testWidgets('notDownloaded → downloading → paused → ready 全程切换',
        (tester) async {
      final settings = _FakeAssistantSettings(const AssistantConfig());
      final model = _FakeModelManager(const ModelNotDownloaded());
      final engine = _FakeEngineManager(const EngineStopped());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [
            ModelManagementCard(
                settings: settings, modelManager: model, engineManager: engine)
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('未下载'), findsOneWidget);
      // → downloading:进度行出现,引导按钮消失。
      model.state.value = _downloading;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('assistantModelProgress')), findsOneWidget);
      expect(find.byKey(const ValueKey('assistantDownloadButton')), findsNothing);
      // → paused:继续下载出现,进度行收起。
      model.state.value = const ModelPaused(
        receivedBytes: 1200000000,
        totalBytes: _totalBytes,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('assistantResumeButton')), findsOneWidget);
      expect(find.byKey(const ValueKey('assistantModelProgress')), findsNothing);
      // → ready:已就绪 + 占用(FutureBuilder) + 删除按钮。
      model.state.value = const ModelReady();
      await tester.pumpAndSettle();
      expect(find.text('已就绪'), findsOneWidget);
      expect(find.text('Qwen3-4B · 占用 2.5GB · v1'), findsOneWidget);
      expect(find.byKey(const ValueKey('assistantDeleteModelButton')),
          findsOneWidget);
      // 启用行说明随之切到就绪措辞。
      expect(find.text('浮层问答 · 本机运行 · 只读查询(v1)'), findsOneWidget);
    });
  });

  group('守门(硬约束,NFR-2)', () {
    test('源码静态检查:无裸色/无 AppColors/不 import data 层实现', () {
      final src = File(
              'lib/assistant/presentation/widgets/model_management_card.dart')
          .readAsStringSync();
      expect(src.contains('Color(0x'), isFalse, reason: '禁裸色:走 context.yucai');
      expect(src.contains('AppColors'), isFalse, reason: 'legacy 色禁用');
      expect(src.contains('engine_manager_impl'), isFalse,
          reason: 'presentation 不 import 引擎实现(经 EngineManager port)');
      expect(src.contains('model_manager_impl'), isFalse,
          reason: 'presentation 不 import 下载实现(经 ModelManagerPort)');
      expect(src.contains('http_downloader'), isFalse,
          reason: 'presentation 不 import 下载内核');
    });
  });
}
