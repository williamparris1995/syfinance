// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../../auth/data/auth_remote_ds.dart' as _i832;
import '../../auth/data/auth_repository_impl.dart' as _i648;
import '../../auth/data/mappers/user_mapper.dart' as _i102;
import '../../auth/data/token_storage.dart' as _i382;
import '../../auth/domain/repositories/auth_repository.dart' as _i937;
import '../../auth/domain/usecases/get_profile_usecase.dart' as _i922;
import '../../auth/domain/usecases/login_usecase.dart' as _i442;
import '../../auth/domain/usecases/logout_usecase.dart' as _i231;
import '../../auth/domain/usecases/refresh_token_usecase.dart' as _i752;
import '../../auth/domain/usecases/register_usecase.dart' as _i246;
import '../../auth/presentation/bloc/auth_bloc.dart' as _i946;
import '../network/auth_retry.dart' as _i763;
import '../network/grpc_client.dart' as _i160;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.factory<_i102.UserMapper>(() => const _i102.UserMapper());
    gh.lazySingleton<_i832.AuthRemoteDataSource>(
      () => _i832.AuthRemoteDataSource(
        gh<_i160.GrpcClient>(),
        gh<_i763.AuthRetryCaller>(),
        gh<_i102.UserMapper>(),
      ),
    );
    gh.lazySingleton<_i937.AuthRepository>(
      () => _i648.AuthRepositoryImpl(
        gh<_i832.AuthRemoteDataSource>(),
        gh<_i382.TokenStorage>(),
      ),
    );
    gh.factory<_i922.GetProfileUseCase>(
      () => _i922.GetProfileUseCase(gh<_i937.AuthRepository>()),
    );
    gh.factory<_i442.LoginUseCase>(
      () => _i442.LoginUseCase(gh<_i937.AuthRepository>()),
    );
    gh.factory<_i231.LogoutUseCase>(
      () => _i231.LogoutUseCase(gh<_i937.AuthRepository>()),
    );
    gh.factory<_i752.RefreshTokenUseCase>(
      () => _i752.RefreshTokenUseCase(gh<_i937.AuthRepository>()),
    );
    gh.factory<_i246.RegisterUseCase>(
      () => _i246.RegisterUseCase(gh<_i937.AuthRepository>()),
    );
    gh.factory<_i946.AuthBloc>(
      () => _i946.AuthBloc(
        gh<_i442.LoginUseCase>(),
        gh<_i246.RegisterUseCase>(),
        gh<_i922.GetProfileUseCase>(),
        gh<_i231.LogoutUseCase>(),
      ),
    );
    return this;
  }
}
