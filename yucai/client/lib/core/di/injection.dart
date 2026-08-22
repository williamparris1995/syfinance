import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/auth/data/oidc_authenticator.dart';
import 'package:yucai_client/auth/data/token_storage.dart';
import 'package:yucai_client/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:yucai_client/core/config/app_config.dart';
import 'package:yucai_client/core/connectivity/connectivity_gateway.dart';
import 'package:yucai_client/core/di/injection.config.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/network/auth_interceptor.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
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
  getIt.registerLazySingleton<SessionModeTracker>(SessionModeTracker.new);

  // 1g. Startup integrity result holder (R6 F): null = healthy; a message
  //     shows a non-intrusive banner in AppShell.
  getIt.registerSingleton<ValueNotifier<String?>>(ValueNotifier<String?>(null));

  // 1f. Uuid for the local data sources (client-generated IDs, R6 ADR-1):
  //     injectable resolves constructor injection from getIt, and third-party
  //     types without a @module must be registered manually (review C-C1).
  getIt.registerLazySingleton<Uuid>(Uuid.new);

  // 2. Injectable resolves the leaf services (UserMapper, AuthRemoteDataSource,
  //    AuthRepositoryImpl, use cases) via constructor injection.
  getIt.init();

  // 2a. Sync the persisted base currency into CurrencySettings' notifier so
  //     pages reading it (home/performance/detail) start with the right value
  //     and can listen for changes (cross-page refresh).
  await getIt<CurrencySettings>().load();

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
