import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/auth/data/token_storage.dart';
import 'package:yucai_client/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:yucai_client/core/config/app_config.dart';
import 'package:yucai_client/core/di/injection.config.dart';
import 'package:yucai_client/core/network/auth_interceptor.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';

final getIt = GetIt.instance;

@InjectableInit(preferRelativeImports: true)
Future<void> configureDependencies() async {
  // 1. Manual registration: the gRPC construction cycle.
  getIt.registerSingleton<AppConfig>(AppConfig.fromEnvironment());

  final tokenStorage = TokenStorage();
  getIt.registerSingleton<TokenStorage>(tokenStorage);

  final authInterceptor = AuthInterceptor();
  final grpcClient = GrpcClient(getIt<AppConfig>(), authInterceptor);
  getIt.registerSingleton<GrpcClient>(grpcClient);

  // 1b. AuthRetryCaller is registered manually (its refresher callback is set
  //     after init) so injectable's graph has no cycle.
  final authRetry = AuthRetryCaller();
  getIt.registerSingleton<AuthRetryCaller>(authRetry);

  // 2. Injectable resolves the leaf services (UserMapper, AuthRemoteDataSource,
  //    AuthRepositoryImpl, use cases) via constructor injection.
  getIt.init();

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
