import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/auth/data/token_storage.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/core/config/app_config.dart';
import 'package:yucai_client/core/di/injection.config.dart';
import 'package:yucai_client/core/network/auth_interceptor.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/login_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/register_usecase.dart';

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

  // 2. Injectable resolves the leaf services (UserMapper, AuthRemoteDataSource,
  //    AuthRepositoryImpl, use cases) via constructor injection.
  getIt.init();

  // 3. Wire interceptor callbacks AFTER remote DS exists (breaks the cycle).
  final remoteDS = getIt<AuthRemoteDataSource>();
  authInterceptor
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

  // 4. AuthBloc — manual (lifecycle managed by the widget tree via BlocProvider).
  getIt.registerSingleton<AuthBloc>(AuthBloc(
    getIt<LoginUseCase>(),
    getIt<RegisterUseCase>(),
    getIt<GetProfileUseCase>(),
    getIt<LogoutUseCase>(),
  ));
}
