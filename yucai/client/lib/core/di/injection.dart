import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/auth/data/oidc_authenticator.dart';
import 'package:yucai_client/auth/data/token_storage.dart';
import 'package:yucai_client/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/binding/data/grpc_offline_sync_port.dart';
import 'package:yucai_client/binding/data/pending_collector.dart';
import 'package:yucai_client/binding/data/pull_applier.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/binding/presentation/bloc/conflict_list_bloc.dart';
import 'package:yucai_client/binding/presentation/bloc/sync_coordinator_bloc.dart';
import 'package:yucai_client/core/config/app_config.dart';
import 'package:yucai_client/core/connectivity/connectivity_gateway.dart';
import 'package:yucai_client/core/di/injection.config.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/network/auth_interceptor.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/core/theme/theme_settings.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';

final getIt = GetIt.instance;

@InjectableInit(preferRelativeImports: true)
Future<void> configureDependencies() async {
  // 1. Manual registration: the gRPC construction cycle.
  getIt.registerSingleton<AppConfig>(AppConfig.fromEnvironment());

  // 1a. FlutterSecureStorage is a third-party type (no @module in this app),
  //     so register a single shared instance manually. CurrencySettings
  //     (@LazySingleton) constructor-injects it; resolving it here before
  //     getIt.init() lets the generated factory find it. TokenStorage reuses the
  //     same instance (its constructor accepts an optional backend for tests),
  //     so the app backs onto one secure-storage backend instead of two.
  getIt.registerSingleton<FlutterSecureStorage>(const FlutterSecureStorage());

  // 1b. UrlLauncherFn (OIDC browser-launch seam) — function-type typedef, so
  //     register the production launcher manually before getIt.init() resolves
  //     OIDCAuthenticator. Tests bypass getIt and pass a fake directly.
  getIt.registerSingleton<UrlLauncherFn>(defaultUrlLauncher);

  final tokenStorage = TokenStorage(backend: getIt<FlutterSecureStorage>());
  getIt.registerSingleton<TokenStorage>(tokenStorage);

  final authInterceptor = AuthInterceptor();
  final grpcClient = GrpcClient(getIt<AppConfig>(), authInterceptor);
  getIt.registerSingleton<GrpcClient>(grpcClient);

  // 1b. AuthRetryCaller is registered manually (its refresher callback is set
  //     after init) so injectable's graph has no cycle.
  final authRetry = AuthRetryCaller();
  getIt.registerSingleton<AuthRetryCaller>(authRetry);

  // 1c. Local-first store (R6): drift opens lazily on first query, so the
  //     file path (path_provider) resolves without blocking startup. Manual
  //     registration mirrors the other core infra singletons (design ADR-5).
  getIt.registerLazySingleton<AppDatabase>(AppDatabase.new);

  // 1d. Shared connectivity gateway (R6): one instance fans out online/
  //     offline events to UI and the dual-source seam.
  getIt.registerLazySingleton<ConnectivityGateway>(ConnectivityGateway.new);

  // 1e. Session-mode flag (R6 ADR-2): AuthBloc drives it, dual-source
  //     repositories read it — the layering-safe session source in core.
  //     F10 T1:构造注入 ConnectivityGateway —— tracker 自订阅 online 流
  //     维护在线快照(三态路由输入,见 session_mode_tracker.dart 接线注释)。
  //     二者均 lazySingleton 且 gateway 先注册:首次解析 tracker 时按需
  //     resolve,无时序问题。
  getIt.registerLazySingleton<SessionModeTracker>(
      () => SessionModeTracker(getIt<ConnectivityGateway>()));

  // 1g. Startup integrity result holder (R6 F): null = healthy; a message
  //     shows a non-intrusive banner in AppShell.
  getIt.registerSingleton<ValueNotifier<String?>>(ValueNotifier<String?>(null));

  // 1f. Uuid for the local data sources (client-generated IDs, R6 ADR-1):
  //     injectable resolves constructor injection from getIt, and third-party
  //     types without a @module must be registered manually (review C-C1).
  getIt.registerLazySingleton<Uuid>(Uuid.new);

  // 1h. F10 T3 回网同步管线(spec FR-5,design ADR-5):全部手工注册(照
  //     1c/1d 先例,免 build_runner 重生成)。
  //     - OfflineSyncPort:F11 T3 起接 gRPC PushChanges 真实现
  //       GrpcOfflineSyncPort(此前为保 pending 的 Noop 占位——文件保留作
  //       参考/测试替身,NoopOfflineSyncPort);
  //       F17-T1:第三参 = 设备身份缝 ClientIdProvider,tear-off
  //       TokenStorage.readClientId(uuid 安装级,3a 启动生成 —— 函数缝
  //       惯例照 UrlLauncherFn/tokenReader,理由详 domain/offline_sync_port
  //       .dart 的 ClientIdProvider doc;BoundMarker 退役出同步链);
  //       F17-T2:port 增 PullChanges 消费(pull 方法,失败透抛由协调器
  //       容忍);
  //     - PendingCollector:从 8 头表 DAO + 墓碑表收集增量批次(F17-T2
  //       起 holding 台账行按 pending 头行 (account,security) pair 联动
  //       收集,entityType=holding_ledger);
  //     - PullApplier(F17-T2):下行增量应用器(envelope 行 → drift
  //       upsert/硬删;pending 保护);协调器第 8/9 参注入;
  //     - SyncCoordinatorBloc:lazySingleton —— F12 UI 首次消费时构造并
  //       订阅回网流;F17-T2 起注入 applier + ClientIdProvider(拉取编排
  //       生效:回网先拉后推、push 成功后拉、分页循环、own-echo 过滤)。
  getIt.registerLazySingleton<OfflineSyncPort>(() => GrpcOfflineSyncPort(
        getIt<GrpcClient>(),
        getIt<AuthRetryCaller>(),
        getIt<TokenStorage>().readClientId,
      ));
  getIt.registerLazySingleton<PendingCollector>(
      () => PendingCollector(getIt<AppDatabase>()));
  getIt.registerLazySingleton<PullApplier>(
      () => PullApplier(getIt<AppDatabase>()));
  getIt.registerLazySingleton<SyncCoordinatorBloc>(() => SyncCoordinatorBloc(
        getIt<OfflineSyncPort>(),
        getIt<PendingCollector>(),
        getIt<SessionModeTracker>(),
        getIt<AppDatabase>(),
        getIt<ConnectivityGateway>().online,
        getIt<BoundMirror>(),
        null,
        getIt<PullApplier>(),
        getIt<TokenStorage>().readClientId,
      ));
  // F18-T3(FR-5/ADR-5):冲突面板数据面 bloc —— 工厂注册(每次进面板全新
  // 实例,离开路由释放);port 经构造注入(listConflicts/resolveConflict 的
  // 真实现已在上方 GrpcOfflineSyncPort)。
  getIt.registerFactory<ConflictListBloc>(
      () => ConflictListBloc(getIt<OfflineSyncPort>()));

  // 2. Injectable resolves the leaf services (UserMapper, AuthRemoteDataSource,
  //    AuthRepositoryImpl, use cases) via constructor injection.
  getIt.init();

  // 2a. Sync the persisted base currency into CurrencySettings' notifier so
  //     pages reading it (home/performance/detail) start with the right value
  //     and can listen for changes (cross-page refresh).
  await getIt<CurrencySettings>().load();

  // 2b. Sync the persisted theme mode (R8 F1) so MaterialApp starts on the
  //     user's saved light/dark/system instead of the system default.
  await getIt<ThemeSettings>().load();

  // 3. Wire the retry refresher: performs RefreshToken, returns success bool.
  final refreshTokenUseCase = getIt<RefreshTokenUseCase>();
  authRetry.refresher = () async => (await refreshTokenUseCase.call()).isRight();

  // 4. Wire interceptor callbacks AFTER remote DS exists (breaks the cycle).
  final remoteDS = getIt<AuthRemoteDataSource>();

  // 3a. Per-install client identity — generate once, persist, reuse. Lets the
  //     server log distinguish this client from other Flutter apps/instances.
  var clientId = await tokenStorage.readClientId();
  if (clientId == null || clientId.isEmpty) {
    clientId = const Uuid().v4();
    await tokenStorage.saveClientId(clientId);
  }

  authInterceptor
    ..clientId = clientId
    ..appName = 'yucai_client'
    ..appVersion = '1.0.0'
    ..tokenReader = tokenStorage.readTokens
    ..refresher = () async {
        try {
          final existing = await tokenStorage.readTokens();
          if (existing == null) return null;
          return await remoteDS.refreshToken(existing.refreshToken);
        } catch (_) {
          return null;
        }
      }
    ..tokenSaver = tokenStorage.saveTokens;

  // 4. AuthBloc is @injectable-registered (factory) with constructor-injected
  //    use cases. No manual registration needed.
}
