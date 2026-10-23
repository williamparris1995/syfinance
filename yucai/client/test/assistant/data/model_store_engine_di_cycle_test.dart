import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:yucai_client/assistant/data/engine_manager_impl.dart';
import 'package:yucai_client/assistant/data/http_downloader.dart';
import 'package:yucai_client/assistant/data/model_manager_impl.dart';
import 'package:yucai_client/assistant/data/process_launcher.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/assistant/domain/engine_port.dart';
import 'package:yucai_client/assistant/domain/model_manager_port.dart';
import 'package:yucai_client/assistant/domain/model_state.dart';
import 'package:yucai_client/assistant/domain/model_store_port.dart';

/// F67 DI 构造环打断回归钉(L-3 探针实证,2026-10-24)。
///
/// 事故形态:injection.dart 1m 段 ModelStore 工厂(→ ModelManagerImpl
/// 构造)急取 EngineManager,EngineManager 工厂又急取 ModelStore ——
/// get_it 7.7.0 lazy 工厂无重入保护,首个消费者解析即
/// StackOverflowError。修法 = ModelManager 侧 deferred 取值缝(构造收
/// `EngineManager Function()`,delete() 调用点取值;EngineManagerImpl
/// 持 ModelStore 直接引用不动 —— 环断在一侧即无环)。
///
/// 不 bootstrap 全量 configureDependencies():AssistantSettings 等踩
/// secure-storage 平台通道,与本钉无关。此处用独立最小 GetIt 实例
/// (asNewInstance,不触碰全局 getIt)按 1m 段同序复刻本环三件
/// (ModelStore/ModelManagerPort/EngineManager)+ fake 依赖,断言两个
/// 入口序各自首解析不炸、一体两 as 双注册同实例、deferred 缝经
/// delete() 全链路可用。若把 ModelStore 工厂的引擎参数改回急取
/// `di<EngineManager>()`,前两测即复现 SOF。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 复刻 injection.dart 1m 段环三件的注册序与工厂形状(引擎参数 =
  /// deferred 闭包,与生产同文;[supportDir] 缺省 null = 生产路径缝,
  /// delete() 全链路测注 temp —— 构造期恢复有内部 fail-safe,但
  /// delete() 里的 _targetFile() 无守卫,裸环境会 MissingPlugin)。
  GetIt wire({Future<Directory> Function()? supportDir}) {
    final di = GetIt.asNewInstance();
    di.registerSingleton<AssistantConfig Function()>(
        () => const AssistantConfig());
    di.registerLazySingleton<ModelHttpClient>(_NoopHttpClient.new);
    di.registerLazySingleton<ModelStore>(() => ModelManagerImpl(
          di<ModelHttpClient>(),
          () => di<EngineManager>(),
          supportDirFn: supportDir,
        ));
    di.registerLazySingleton<ModelManagerPort>(
        () => di<ModelStore>() as ModelManagerPort);
    di.registerLazySingleton<ProcessLauncher>(_NoopLauncher.new);
    di.registerLazySingleton<EngineManager>(() => EngineManagerImpl(
          di<ProcessLauncher>(),
          di<ModelStore>(),
          di<AssistantConfig Function()>(),
        ));
    return di;
  }

  test('入口序 A:先解析 ModelStore —— 环两侧首解析不炸 + 双注册同实例',
      () {
    final di = wire();
    final store = di<ModelStore>(); // 事故点:急取互引曾在此 StackOverflowError
    expect(di<EngineManager>(), isA<EngineManagerImpl>()); // 对向首解析
    expect(identical(store, di<ModelManagerPort>()), isTrue,
        reason: 'ModelManagerPort 一体两 as 回读 ModelStore 缓存');
  });

  test('入口序 B:先解析 EngineManager —— 环两侧首解析不炸 + 双注册同实例',
      () {
    final di = wire();
    final engine = di<EngineManager>(); // 对向事故点:入口反转同炸
    expect(di<ModelStore>(), isA<ModelManagerImpl>());
    expect(engine, isA<EngineManagerImpl>());
    expect(identical(di<ModelStore>(), di<ModelManagerPort>()), isTrue);
  });

  test('deferred 缝经 delete() 全链路可用(取容器缓存实例,shutdown 幂等)',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('f67_di_cycle_delete_test');
    addTearDown(() => temp.delete(recursive: true));
    final di = wire(supportDir: () async => temp);
    final port = di<ModelManagerPort>();
    await port.delete(); // _engine() → 容器缓存 EngineManagerImpl → no-op shutdown
    expect(port.state.value, const ModelNotDownloaded());
  });
}

/// 零网络 fake:本测不触发下载(ModelManagerImpl 构造只做磁盘态恢复,
/// 路径缝的平台通道异常由其内部 fail-safe 吞掉)。
class _NoopHttpClient implements ModelHttpClient {
  @override
  Future<ModelHttpResponse> get(Uri url, {int? rangeFrom}) async {
    throw StateError('DI cycle test must not download');
  }
}

/// 零进程 fake:本测不拉起边车(EngineManagerImpl 构造纯赋值)。
class _NoopLauncher implements ProcessLauncher {
  @override
  Future<LaunchedProcess> start({
    required String exe,
    required List<String> args,
  }) async {
    throw StateError('DI cycle test must not start engine');
  }

  @override
  Future<void> killTree(int pid) async {}
}
