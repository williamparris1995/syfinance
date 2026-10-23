import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/app/nav_settings.dart';
import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/auth/data/oidc_authenticator.dart';
import 'package:yucai_client/auth/data/token_storage.dart';
import 'package:yucai_client/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:yucai_client/assistant/data/agent_loop_impl.dart';
import 'package:yucai_client/assistant/data/assistant_settings_store.dart';
import 'package:yucai_client/assistant/data/audit_log.dart';
import 'package:yucai_client/assistant/data/engine_manager_impl.dart';
import 'package:yucai_client/assistant/data/llm_stream_client_impl.dart';
import 'package:yucai_client/assistant/data/http_downloader.dart';
import 'package:yucai_client/assistant/data/model_manager_impl.dart';
import 'package:yucai_client/assistant/data/process_launcher.dart';
import 'package:yucai_client/assistant/data/tools/accounts_list_tool.dart';
import 'package:yucai_client/assistant/data/tools/debts_list_tool.dart';
import 'package:yucai_client/assistant/data/tools/networth_snapshot_tool.dart';
import 'package:yucai_client/assistant/domain/agent_loop.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/assistant/domain/engine_port.dart';
import 'package:yucai_client/assistant/domain/model_manager_port.dart';
import 'package:yucai_client/assistant/domain/model_store_port.dart';
import 'package:yucai_client/assistant/domain/tool_registry.dart';
import 'package:yucai_client/backup/data/archive_importer.dart';
import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/binding/data/grpc_offline_sync_port.dart';
import 'package:yucai_client/binding/data/pending_collector.dart';
import 'package:yucai_client/binding/data/pull_applier.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/binding/presentation/bloc/binding_bloc.dart';
import 'package:yucai_client/binding/presentation/bloc/conflict_list_bloc.dart';
import 'package:yucai_client/binding/presentation/bloc/sync_coordinator_bloc.dart';
import 'package:yucai_client/backup/data/local_snapshot_exporter.dart';
import 'package:yucai_client/core/config/app_config.dart';
import 'package:yucai_client/core/connectivity/connectivity_gateway.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/core/di/base_currency_source_adapter.dart';
import 'package:yucai_client/core/di/injection.config.dart';
import 'package:yucai_client/core/di/networth_snapshot_source_adapter.dart';
import 'package:yucai_client/core/form_leave_gate.dart';
import 'package:yucai_client/core/shell_detail_title.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/network/auth_interceptor.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/core/llm/llm_settings.dart';
import 'package:yucai_client/core/notifications/tray_settings.dart';
import 'package:yucai_client/core/session_mode/bound_marker.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/core/theme/theme_settings.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/report/data/llm/llm_http.dart';
import 'package:yucai_client/report/data/llm/llm_mda_narrator.dart';
import 'package:yucai_client/settings/data/data_reset_controller.dart';
import 'package:yucai_client/settings/data/local_snapshot_service.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

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

  // 1j. F46 (2026-09-28): LlmHttpFn (LLM 出站 HTTP 缝,唯一 dart:io 平台
  //     文件 llm_http.dart)——函数类型 typedef 照 1b UrlLauncherFn 先例,
  //     getIt.init() 解析 LlmMdaNarrator(MdaNarrator 主绑定)前手工注册;
  //     测试绕开 getIt 直接注入 fake。API Key 只经请求头从此处出站,
  //     任何日志/错误零携带(FR-5)。
  getIt.registerSingleton<LlmHttpFn>(llmHttpPost);

  // 1m. F64 (2026-10-23): 助手服务装配(全部手工注册,照 1h/F21 先例;
  //     code-plan T6 = core/di 手工绑定 LlmStreamClient/AgentLoopService)。
  //     缘由:build_runner regen 在本仓不可用 —— injectable_generator 无法
  //     解析 impl 构造参数的内联函数类型 `AssistantConfig Function()`
  //     (报 "Can not resolve function type, try using an alias"),T2/T4/T5
  //     的 @LazySingleton 注解进不了生成图,生产绑定由此段承担。
  //     - AssistantConfig Function():配置取值缝,函数类型照 1j LlmHttpFn
  //       先例手工注册;工厂读 AssistantSettings 当前值,每次 send 取最新
  //       (F66-T1 收窄后仅 AgentLoopService 消费)。测试绕开 getIt
  //       直接传闭包。
  //     - AssistantSettings:注入 1a 共享 secure-storage 后端(单实例家法);
  //       load 挂 2f。
  //     - AssistantAuditLog:默认缝 = debugPrint(English 结构化日志)。
  //     - ModelStore(F67-T2 换绑):ModelManagerImpl 双面实现(ADR-2;
  //       @LazySingleton(as: ModelStore) 注解仅文档,实际绑定在此)——
  //       下载管理(Range 续传/进度节流/sha256 校验/源回落/删除联动
  //       shutdown)+ F66 port 面不变;F66 简版 ModelStoreImpl 退役删除。
  //       ModelManagerPort 同实例第二注册(F65 消费 state 流;lazy 工厂
  //       回读 getIt<ModelStore> 缓存,一体两 as 手工段家法)。
  //     - ModelHttpClient(F67-T2):IoModelHttpClient dart:io 生产实现
  //       (生成图不可 regen,同样手工注册;单测绕开 getIt 注入 mock)。
  //     - LlmStreamClient(F66-T3 起构造注入 EngineManager:chat 前置
  //       ensureReady 兜底 + Ready 端点作 baseUrl,ADR-1/ADR-8)/
  //       AgentLoopService(经取值缝闭包构造;持内存态单会话,lazySingleton
  //       语义照注解本意)。
  //     - EngineManager + ProcessLauncher(F66-T2,2026-10-23):边车生命周期
  //       编排 + dart:io 进程缝(NFR-2)。EngineManagerImpl 构造缝(延时/
  //       健康探测/端口扫描/exe 路径/闲置 Timer/日志)全走生产缺省,
  //       仅注入 ProcessLauncher/ModelStore/取值缝三件;lazy resolution,
  //       首消费(T3 接线后的 LlmStreamClient / F65 UI)远晚于 bootstrap,
  //       时序安全。退出钩子侧(notifications_bootstrap)以 isRegistered 守卫。
  //     工具注册表(其构造依赖)在 init 后的 2g 装配;本组全部 lazy,
  //       首次消费(F65 UI)远晚于 bootstrap,时序安全。
  getIt.registerSingleton<AssistantConfig Function()>(
      () => getIt<AssistantSettings>().value);
  getIt.registerLazySingleton<AssistantSettings>(
      () => AssistantSettings(storage: getIt<FlutterSecureStorage>()));
  getIt.registerLazySingleton<AssistantAuditLog>(AssistantAuditLog.new);
  getIt.registerLazySingleton<ModelHttpClient>(IoModelHttpClient.new);
  getIt.registerLazySingleton<ModelStore>(() => ModelManagerImpl(
        getIt<ModelHttpClient>(),
        getIt<EngineManager>(),
      ));
  getIt.registerLazySingleton<ModelManagerPort>(
      () => getIt<ModelStore>() as ModelManagerPort);
  getIt.registerLazySingleton<LlmStreamClient>(
      () => LlmStreamClientImpl(getIt<EngineManager>()));
  getIt.registerLazySingleton<AgentLoopService>(() => AgentLoopServiceImpl(
        getIt<LlmStreamClient>(),
        getIt<AssistantToolRegistry>(),
        getIt<AssistantAuditLog>(),
        getIt<AssistantConfig Function()>(),
      ));
  getIt.registerLazySingleton<ProcessLauncher>(ProcessLauncherImpl.new);
  getIt.registerLazySingleton<EngineManager>(() => EngineManagerImpl(
        getIt<ProcessLauncher>(),
        getIt<ModelStore>(),
        getIt<AssistantConfig Function()>(),
      ));

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

  // F19-T1(ADR-1/ADR-3):绑定向导 bloc —— 手工注册(照 ConflictListBloc
  // 先例;构造依赖 PendingCollector —— 1h 手工注册件,injectable 图不可
  // 见,故不入 config)。统一合并 push 链在 bloc 内联:markAllPending →
  // 拆批 push → 回写 → refreshAll → markBound → registerDevice;向导不再
  // 调用 uploadBackup/exporter(类保留在 lib 中,F20 评估)。
  getIt.registerFactory<BindingBloc>(() => BindingBloc(
        getIt<AccountRepository>(),
        getIt<TransactionRepository>(),
        getIt<HoldingRepository>(),
        getIt<AppDatabase>(),
        getIt<BoundMarker>(),
        getIt<OfflineSyncPort>(),
        getIt<PendingCollector>(),
      ));

  // F21-T1(2026-09-14):清空数据控制器(设置页「清空数据重新开始」:备份
  // 先行 fail-closed → 关库 → 删库文件 → exit)——手工注册(照上方 1h 先例,
  // 免 build_runner 重生成;依赖均为既有注册件:AppDatabase(1c)+
  // LocalSnapshotExporter(injectable 图,备份复用导出存档链))。
  getIt.registerLazySingleton<DataResetController>(() => DataResetController(
        database: getIt<AppDatabase>(),
        exporter: getIt<LocalSnapshotExporter>(),
      ));

  // F39 (2026-09-19): guest local snapshot loop — manual registration per the
  // 1h/F21 precedent (avoids a build_runner regen; see local_snapshot_service
  // class doc for the file-home rationale). Dependencies are all registered
  // above: AppDatabase (1c) + LocalSnapshotExporter / ArchiveImporter
  // (injectable graph). Consumed by the startup daily hook in main.dart and
  // the settings page "本地快照" section.
  getIt.registerLazySingleton<LocalSnapshotService>(() => LocalSnapshotService(
        database: getIt<AppDatabase>(),
        exporter: getIt<LocalSnapshotExporter>(),
        importer: getIt<ArchiveImporter>(),
      ));

  // 1i. Hotfix(导入存档后 dashboard 全零):数据整批替换后的全局刷新通知器
  //     —— 手工注册 lazySingleton(照 1h/F21 先例,免 build_runner 重生成;
  //     无构造依赖)。fire 点 = 设置页导入存档成功;listen 点 = 长期驻留
  //     IndexedStack 分支的页面级缓存(HomePage),见 core/data_refresh.dart。
  getIt.registerLazySingleton<DataRefreshNotifier>(DataRefreshNotifier.new);

  // 1j. ⑨ 导航增强 A(2026-09-29):侧栏分组展开态记忆 —— 手工注册
  //     lazySingleton(照 1i 先例,免 build_runner 重生成;构造依赖 =
  //     1a 的 FlutterSecureStorage const 实例)。消费点 = AppShell 侧栏
  //     (guarded getIt);load 挂 2e。
  getIt.registerLazySingleton<NavSettings>(
      () => NavSettings(getIt<FlutterSecureStorage>()));

  // 1k. F58 壳层导航地基(ADR-1/ADR-3):两 port —— 手工注册 lazySingleton
  //     (照 1i/1j 先例,免 build_runner 重生成;均无构造依赖)。
  //     - ShellDetailTitle:详情页 → 顶栏面包屑当前级标题通道(detail 页
  //       set/clear,shell 顶栏 ValueListenableBuilder 消费 + location-diff
  //       清零双保险,见 core/shell_detail_title.dart);
  //     - FormLeaveGate:脏表单离开问询闸门(面包屑 page 级 onTap 先
  //       mayLeave 再 go;表单页 FormLeaveGuard 注册 veto + PopScope 兜底,
  //       见 core/form_leave_gate.dart / core/widgets/form_leave_guard.dart)。
  getIt.registerLazySingleton<ShellDetailTitle>(ShellDetailTitle.new);
  getIt.registerLazySingleton<FormLeaveGate>(FormLeaveGate.new);

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

  // 2c. Sync the persisted tray/close-behavior prefs (R8 F22) so the close
  //     button decision tree (TrayController, bootstrapNotifications) and the
  //     settings page read persisted truth synchronously on the hot path.
  await getIt<TraySettings>().load();

  // 2d. F46 (2026-09-28): sync the persisted BYOK LLM config (ThemeSettings
  //     家法镜像) so the report page entry visibility (LlmSettings.ready) and
  //     the settings card read persisted truth synchronously. Default
  //     off = zero behavior change (Migration Plan).
  await getIt<LlmSettings>().load();

  // 2e. ⑨ 导航增强 A (2026-09-29): sync the persisted sidebar collapsed-group
  //     set (NavSettings, ThemeSettings 家法镜像) so the shell sidebar starts
  //     on the user's saved expand/collapse state. Default empty = all groups
  //     expanded (zero behavior change for first run).
  await getIt<NavSettings>().load();

  // 2f. F64 (2026-10-23): sync the persisted assistant endpoint config
  //     (AssistantSettings, LlmSettings 家法镜像 ADR-4) so the loop's
  //     not-ready gate and future F65 entry read persisted truth
  //     synchronously. Default off = zero behavior change (Migration Plan).
  await getIt<AssistantSettings>().load();

  // 2g. F64 助手地基:工具注册表启动装配(FR-1;registry 单例 + 三只读
  //     工具集中此一段,勿散落)。工具构造依赖均为既有注册件:
  //     AccountRepository / DebtRepository(assistant 跨模块只 import
  //     domain port,ADR-2)、CurrencySettings(2a 同源本位币,经
  //     BaseCurrencySourceAdapter 转 BaseCurrencySource 微 port —— 评审
  //     fixlist M1:assistant 不 import currency/data)、
  //     NetWorthLocalDataSource(生成图)经 core/di 适配件转
  //     NetWorthSnapshotSource(ADR-2:assistant 不 import holding/data,
  //     与 home 净资产大卡同源,NFR-1)。
  final assistantTools = AssistantToolRegistry();
  assistantTools.register(NetWorthSnapshotTool(
    NetWorthSnapshotSourceAdapter(getIt<NetWorthLocalDataSource>()),
    BaseCurrencySourceAdapter(getIt<CurrencySettings>()),
  ));
  assistantTools.register(AccountsListTool(
    getIt<AccountRepository>(),
    getIt<DebtRepository>(),
  ));
  assistantTools.register(DebtsListTool(getIt<DebtRepository>()));
  getIt.registerSingleton<AssistantToolRegistry>(assistantTools);

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
