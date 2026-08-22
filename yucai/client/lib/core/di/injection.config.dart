// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:uuid/uuid.dart' as _i706;

import '../../account/data/account_local_ds.dart' as _i697;
import '../../account/data/account_remote_ds.dart' as _i414;
import '../../account/data/account_repository_impl.dart' as _i725;
import '../../account/data/mappers/account_mapper.dart' as _i994;
import '../../account/domain/repositories/account_repository.dart' as _i270;
import '../../account/domain/usecases/create_account_usecase.dart' as _i82;
import '../../account/domain/usecases/delete_account_usecase.dart' as _i1051;
import '../../account/domain/usecases/get_account_usecase.dart' as _i500;
import '../../account/domain/usecases/list_accounts_usecase.dart' as _i106;
import '../../account/domain/usecases/update_account_usecase.dart' as _i726;
import '../../account/presentation/bloc/account_bloc.dart' as _i803;
import '../../auth/data/auth_remote_ds.dart' as _i832;
import '../../auth/data/auth_repository_impl.dart' as _i648;
import '../../auth/data/mappers/user_mapper.dart' as _i102;
import '../../auth/data/oidc_authenticator.dart' as _i871;
import '../../auth/data/token_storage.dart' as _i382;
import '../../auth/domain/repositories/auth_repository.dart' as _i937;
import '../../auth/domain/usecases/get_profile_usecase.dart' as _i922;
import '../../auth/domain/usecases/has_stored_credentials_usecase.dart'
    as _i912;
import '../../auth/domain/usecases/logout_usecase.dart' as _i231;
import '../../auth/domain/usecases/oidc_login_usecase.dart' as _i990;
import '../../auth/domain/usecases/refresh_token_usecase.dart' as _i752;
import '../../auth/presentation/bloc/auth_bloc.dart' as _i946;
import '../../backup/data/backup_remote_ds.dart' as _i877;
import '../../backup/data/backup_repository_impl.dart' as _i594;
import '../../backup/domain/repositories/backup_repository.dart' as _i335;
import '../../backup/presentation/bloc/backup_bloc.dart' as _i852;
import '../../backup/presentation/bloc/backup_settings_bloc.dart' as _i86;
import '../../budget/data/budget_local_ds.dart' as _i15;
import '../../budget/data/budget_remote_ds.dart' as _i749;
import '../../budget/data/budget_repository_impl.dart' as _i364;
import '../../budget/domain/repositories/budget_repository.dart' as _i665;
import '../../budget/presentation/bloc/budget_bloc.dart' as _i763;
import '../../currency/data/currency_remote_ds.dart' as _i386;
import '../../currency/data/currency_repository_impl.dart' as _i254;
import '../../currency/data/currency_settings.dart' as _i61;
import '../../currency/data/mappers/currency_mapper.dart' as _i380;
import '../../currency/domain/repositories/currency_repository.dart' as _i108;
import '../../currency/presentation/bloc/currency_bloc.dart' as _i284;
import '../../debt/data/debt_local_ds.dart' as _i464;
import '../../debt/data/debt_remote_ds.dart' as _i243;
import '../../debt/data/debt_repository_impl.dart' as _i1060;
import '../../debt/data/receivables_summary_data_source.dart' as _i536;
import '../../debt/data/receivables_summary_repository_impl.dart' as _i31;
import '../../debt/domain/repositories/debt_repository.dart' as _i670;
import '../../debt/domain/repositories/receivables_summary_repository.dart'
    as _i322;
import '../../debt/presentation/bloc/debt_bloc.dart' as _i383;
import '../../goal/data/goal_local_ds.dart' as _i94;
import '../../goal/data/goal_remote_ds.dart' as _i628;
import '../../goal/data/goal_repository_impl.dart' as _i425;
import '../../goal/domain/repositories/goal_repository.dart' as _i835;
import '../../goal/presentation/bloc/goal_bloc.dart' as _i703;
import '../../holding/data/goal_view_ds.dart' as _i616;
import '../../holding/data/holding_local_ds.dart' as _i898;
import '../../holding/data/holding_remote_ds.dart' as _i620;
import '../../holding/data/holding_repository_impl.dart' as _i427;
import '../../holding/data/networth_ds.dart' as _i600;
import '../../holding/domain/repositories/holding_repository.dart' as _i255;
import '../../holding/presentation/bloc/holding_bloc.dart' as _i255;
import '../../holding/presentation/bloc/performance_bloc.dart' as _i493;
import '../../tag/data/tag_remote_ds.dart' as _i648;
import '../../tag/data/tag_repository_impl.dart' as _i603;
import '../../tag/domain/repositories/tag_repository.dart' as _i585;
import '../../tag/presentation/bloc/tag_bloc.dart' as _i847;
import '../../template/data/template_local_ds.dart' as _i97;
import '../../template/data/template_remote_ds.dart' as _i889;
import '../../template/data/template_repository_impl.dart' as _i554;
import '../../template/domain/repositories/template_repository.dart' as _i74;
import '../../template/presentation/bloc/template_bloc.dart' as _i933;
import '../../transaction/data/mappers/transaction_mapper.dart' as _i667;
import '../../transaction/data/transaction_local_ds.dart' as _i991;
import '../../transaction/data/transaction_remote_ds.dart' as _i666;
import '../../transaction/data/transaction_repository_impl.dart' as _i733;
import '../../transaction/domain/repositories/transaction_repository.dart'
    as _i822;
import '../../transaction/presentation/bloc/category_bloc.dart' as _i159;
import '../localdb/app_database.dart' as _i581;
import '../network/auth_retry.dart' as _i763;
import '../network/grpc_client.dart' as _i160;
import '../session_mode/session_mode_tracker.dart' as _i781;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.factory<_i994.AccountMapper>(() => const _i994.AccountMapper());
    gh.factory<_i102.UserMapper>(() => const _i102.UserMapper());
    gh.factory<_i380.CurrencyMapper>(() => const _i380.CurrencyMapper());
    gh.factory<_i667.TransactionMapper>(() => const _i667.TransactionMapper());
    gh.lazySingleton<_i697.AccountLocalDataSource>(
      () => _i697.AccountLocalDataSource(
        gh<_i581.AppDatabase>(),
        uuid: gh<_i706.Uuid>(),
      ),
    );
    gh.lazySingleton<_i832.AuthRemoteDataSource>(
      () => _i832.AuthRemoteDataSource(
        gh<_i160.GrpcClient>(),
        gh<_i763.AuthRetryCaller>(),
        gh<_i102.UserMapper>(),
      ),
    );
    gh.lazySingleton<_i386.CurrencyRemoteDataSource>(
      () => _i386.CurrencyRemoteDataSource(
        gh<_i160.GrpcClient>(),
        gh<_i763.AuthRetryCaller>(),
        gh<_i380.CurrencyMapper>(),
      ),
    );
    gh.lazySingleton<_i666.TransactionRemoteDataSource>(
      () => _i666.TransactionRemoteDataSource(
        gh<_i160.GrpcClient>(),
        gh<_i763.AuthRetryCaller>(),
        gh<_i667.TransactionMapper>(),
      ),
    );
    gh.lazySingleton<_i414.AccountRemoteDataSource>(
      () => _i414.AccountRemoteDataSource(
        gh<_i160.GrpcClient>(),
        gh<_i763.AuthRetryCaller>(),
        gh<_i994.AccountMapper>(),
      ),
    );
    gh.lazySingleton<_i270.AccountRepository>(
      () => _i725.AccountRepositoryImpl(
        gh<_i414.AccountRemoteDataSource>(),
        gh<_i697.AccountLocalDataSource>(),
        gh<_i781.SessionModeTracker>(),
      ),
    );
    gh.lazySingleton<_i254.CurrencyLocalDataSource>(
      () => _i254.CurrencyLocalDataSource(gh<_i581.AppDatabase>()),
    );
    gh.lazySingleton<_i898.NetWorthLocalDataSource>(
      () => _i898.NetWorthLocalDataSource(gh<_i581.AppDatabase>()),
    );
    gh.lazySingleton<_i61.CurrencySettings>(
      () => _i61.CurrencySettings(gh<_i558.FlutterSecureStorage>()),
    );
    gh.lazySingleton<_i937.AuthRepository>(
      () => _i648.AuthRepositoryImpl(
        gh<_i832.AuthRemoteDataSource>(),
        gh<_i382.TokenStorage>(),
      ),
    );
    gh.lazySingleton<_i877.BackupRemoteDataSource>(
      () => _i877.BackupRemoteDataSource(
        gh<_i160.GrpcClient>(),
        gh<_i763.AuthRetryCaller>(),
      ),
    );
    gh.lazySingleton<_i749.BudgetRemoteDataSource>(
      () => _i749.BudgetRemoteDataSource(
        gh<_i160.GrpcClient>(),
        gh<_i763.AuthRetryCaller>(),
      ),
    );
    gh.lazySingleton<_i243.DebtRemoteDataSource>(
      () => _i243.DebtRemoteDataSource(
        gh<_i160.GrpcClient>(),
        gh<_i763.AuthRetryCaller>(),
      ),
    );
    gh.lazySingleton<_i536.ReceivablesSummaryDataSource>(
      () => _i536.ReceivablesSummaryDataSource(
        gh<_i160.GrpcClient>(),
        gh<_i763.AuthRetryCaller>(),
      ),
    );
    gh.lazySingleton<_i628.GoalRemoteDataSource>(
      () => _i628.GoalRemoteDataSource(
        gh<_i160.GrpcClient>(),
        gh<_i763.AuthRetryCaller>(),
      ),
    );
    gh.lazySingleton<_i616.GoalViewDataSource>(
      () => _i616.GoalViewDataSource(
        gh<_i160.GrpcClient>(),
        gh<_i763.AuthRetryCaller>(),
      ),
    );
    gh.lazySingleton<_i620.HoldingRemoteDataSource>(
      () => _i620.HoldingRemoteDataSource(
        gh<_i160.GrpcClient>(),
        gh<_i763.AuthRetryCaller>(),
      ),
    );
    gh.lazySingleton<_i648.TagRemoteDataSource>(
      () => _i648.TagRemoteDataSource(
        gh<_i160.GrpcClient>(),
        gh<_i763.AuthRetryCaller>(),
      ),
    );
    gh.lazySingleton<_i889.TemplateRemoteDataSource>(
      () => _i889.TemplateRemoteDataSource(
        gh<_i160.GrpcClient>(),
        gh<_i763.AuthRetryCaller>(),
      ),
    );
    gh.lazySingleton<_i15.BudgetLocalDataSource>(
      () => _i15.BudgetLocalDataSource(
        gh<_i581.AppDatabase>(),
        uuid: gh<_i706.Uuid>(),
      ),
    );
    gh.lazySingleton<_i94.GoalLocalDataSource>(
      () => _i94.GoalLocalDataSource(
        gh<_i581.AppDatabase>(),
        uuid: gh<_i706.Uuid>(),
      ),
    );
    gh.lazySingleton<_i603.TagLocalDataSource>(
      () => _i603.TagLocalDataSource(
        gh<_i581.AppDatabase>(),
        uuid: gh<_i706.Uuid>(),
      ),
    );
    gh.lazySingleton<_i991.TransactionLocalDataSource>(
      () => _i991.TransactionLocalDataSource(
        gh<_i581.AppDatabase>(),
        uuid: gh<_i706.Uuid>(),
      ),
    );
    gh.lazySingleton<_i871.OIDCAuthenticator>(
      () => _i871.OIDCAuthenticator(launcher: gh<_i871.UrlLauncherFn>()),
    );
    gh.lazySingleton<_i835.GoalRepository>(
      () => _i425.GoalRepositoryImpl(
        gh<_i628.GoalRemoteDataSource>(),
        gh<_i94.GoalLocalDataSource>(),
        gh<_i781.SessionModeTracker>(),
      ),
    );
    gh.lazySingleton<_i108.CurrencyRepository>(
      () => _i254.CurrencyRepositoryImpl(
        gh<_i386.CurrencyRemoteDataSource>(),
        gh<_i254.CurrencyLocalDataSource>(),
        gh<_i781.SessionModeTracker>(),
      ),
    );
    gh.lazySingleton<_i322.ReceivablesSummaryRepository>(
      () => _i31.ReceivablesSummaryRepositoryImpl(
        gh<_i536.ReceivablesSummaryDataSource>(),
      ),
    );
    gh.lazySingleton<_i822.TransactionRepository>(
      () => _i733.TransactionRepositoryImpl(
        gh<_i666.TransactionRemoteDataSource>(),
        gh<_i991.TransactionLocalDataSource>(),
        gh<_i781.SessionModeTracker>(),
      ),
    );
    gh.factory<_i82.CreateAccountUseCase>(
      () => _i82.CreateAccountUseCase(gh<_i270.AccountRepository>()),
    );
    gh.factory<_i1051.DeleteAccountUseCase>(
      () => _i1051.DeleteAccountUseCase(gh<_i270.AccountRepository>()),
    );
    gh.factory<_i500.GetAccountUseCase>(
      () => _i500.GetAccountUseCase(gh<_i270.AccountRepository>()),
    );
    gh.factory<_i106.ListAccountsUseCase>(
      () => _i106.ListAccountsUseCase(gh<_i270.AccountRepository>()),
    );
    gh.factory<_i726.UpdateAccountUseCase>(
      () => _i726.UpdateAccountUseCase(gh<_i270.AccountRepository>()),
    );
    gh.factory<_i990.OidcLoginUseCase>(
      () => _i990.OidcLoginUseCase(
        gh<_i937.AuthRepository>(),
        gh<_i871.OIDCAuthenticator>(),
      ),
    );
    gh.lazySingleton<_i600.NetWorthDataSource>(
      () => _i600.NetWorthDataSource(
        gh<_i160.GrpcClient>(),
        gh<_i763.AuthRetryCaller>(),
        gh<_i898.NetWorthLocalDataSource>(),
        gh<_i781.SessionModeTracker>(),
      ),
    );
    gh.factory<_i284.CurrencyBloc>(
      () => _i284.CurrencyBloc(
        gh<_i108.CurrencyRepository>(),
        gh<_i832.AuthRemoteDataSource>(),
        gh<_i781.SessionModeTracker>(),
        gh<_i61.CurrencySettings>(),
      ),
    );
    gh.lazySingleton<_i97.TemplateLocalDataSource>(
      () => _i97.TemplateLocalDataSource(
        gh<_i581.AppDatabase>(),
        gh<_i991.TransactionLocalDataSource>(),
        uuid: gh<_i706.Uuid>(),
      ),
    );
    gh.factory<_i159.CategoryBloc>(
      () => _i159.CategoryBloc(
        gh<_i106.ListAccountsUseCase>(),
        gh<_i82.CreateAccountUseCase>(),
        gh<_i1051.DeleteAccountUseCase>(),
        gh<_i726.UpdateAccountUseCase>(),
      ),
    );
    gh.lazySingleton<_i464.DebtLocalDataSource>(
      () => _i464.DebtLocalDataSource(
        gh<_i581.AppDatabase>(),
        gh<_i991.TransactionLocalDataSource>(),
        uuid: gh<_i706.Uuid>(),
      ),
    );
    gh.lazySingleton<_i898.HoldingLocalDataSource>(
      () => _i898.HoldingLocalDataSource(
        gh<_i581.AppDatabase>(),
        gh<_i991.TransactionLocalDataSource>(),
        uuid: gh<_i706.Uuid>(),
      ),
    );
    gh.lazySingleton<_i585.TagRepository>(
      () => _i603.TagRepositoryImpl(
        gh<_i648.TagRemoteDataSource>(),
        gh<_i603.TagLocalDataSource>(),
        gh<_i781.SessionModeTracker>(),
      ),
    );
    gh.lazySingleton<_i255.HoldingRepository>(
      () => _i427.HoldingRepositoryImpl(
        gh<_i620.HoldingRemoteDataSource>(),
        gh<_i898.HoldingLocalDataSource>(),
        gh<_i781.SessionModeTracker>(),
        gh<_i616.GoalViewDataSource>(),
      ),
    );
    gh.factory<_i703.GoalBloc>(
      () => _i703.GoalBloc(gh<_i835.GoalRepository>()),
    );
    gh.lazySingleton<_i335.BackupRepository>(
      () => _i594.BackupRepositoryImpl(gh<_i877.BackupRemoteDataSource>()),
    );
    gh.factory<_i922.GetProfileUseCase>(
      () => _i922.GetProfileUseCase(gh<_i937.AuthRepository>()),
    );
    gh.factory<_i912.HasStoredCredentialsUseCase>(
      () => _i912.HasStoredCredentialsUseCase(gh<_i937.AuthRepository>()),
    );
    gh.factory<_i231.LogoutUseCase>(
      () => _i231.LogoutUseCase(gh<_i937.AuthRepository>()),
    );
    gh.factory<_i752.RefreshTokenUseCase>(
      () => _i752.RefreshTokenUseCase(gh<_i937.AuthRepository>()),
    );
    gh.lazySingleton<_i74.TemplateRepository>(
      () => _i554.TemplateRepositoryImpl(
        gh<_i889.TemplateRemoteDataSource>(),
        gh<_i97.TemplateLocalDataSource>(),
        gh<_i781.SessionModeTracker>(),
      ),
    );
    gh.factory<_i946.AuthBloc>(
      () => _i946.AuthBloc(
        gh<_i990.OidcLoginUseCase>(),
        gh<_i922.GetProfileUseCase>(),
        gh<_i231.LogoutUseCase>(),
        gh<_i912.HasStoredCredentialsUseCase>(),
        gh<_i781.SessionModeTracker>(),
      ),
    );
    gh.factory<_i803.AccountBloc>(
      () => _i803.AccountBloc(
        gh<_i106.ListAccountsUseCase>(),
        gh<_i82.CreateAccountUseCase>(),
        gh<_i1051.DeleteAccountUseCase>(),
        gh<_i500.GetAccountUseCase>(),
        gh<_i726.UpdateAccountUseCase>(),
      ),
    );
    gh.factory<_i255.HoldingBloc>(
      () => _i255.HoldingBloc(gh<_i255.HoldingRepository>()),
    );
    gh.factory<_i493.PerformanceBloc>(
      () => _i493.PerformanceBloc(gh<_i255.HoldingRepository>()),
    );
    gh.lazySingleton<_i665.BudgetRepository>(
      () => _i364.BudgetRepositoryImpl(
        gh<_i749.BudgetRemoteDataSource>(),
        gh<_i15.BudgetLocalDataSource>(),
        gh<_i781.SessionModeTracker>(),
      ),
    );
    gh.factory<_i847.TagBloc>(() => _i847.TagBloc(gh<_i585.TagRepository>()));
    gh.lazySingleton<_i670.DebtRepository>(
      () => _i1060.DebtRepositoryImpl(
        gh<_i243.DebtRemoteDataSource>(),
        gh<_i464.DebtLocalDataSource>(),
        gh<_i781.SessionModeTracker>(),
      ),
    );
    gh.factory<_i852.BackupBloc>(
      () => _i852.BackupBloc(gh<_i335.BackupRepository>()),
    );
    gh.factory<_i86.BackupSettingsBloc>(
      () => _i86.BackupSettingsBloc(gh<_i335.BackupRepository>()),
    );
    gh.factory<_i763.BudgetBloc>(
      () => _i763.BudgetBloc(gh<_i665.BudgetRepository>()),
    );
    gh.factory<_i933.TemplateBloc>(
      () => _i933.TemplateBloc(gh<_i74.TemplateRepository>()),
    );
    gh.factory<_i383.DebtBloc>(
      () => _i383.DebtBloc(gh<_i670.DebtRepository>()),
    );
    return this;
  }
}
