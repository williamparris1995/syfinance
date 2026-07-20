import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/oidc_login_usecase.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_event.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';

@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(
    this._oidcLogin,
    this._getProfile,
    this._logout,
  ) : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<OIDCLoginRequested>(_onOIDCLogin);
    on<LogoutRequested>(_onLogout);
    on<TokenRefreshFailed>(_onTokenRefreshFailed);
  }

  final OidcLoginUseCase _oidcLogin;
  final GetProfileUseCase _getProfile;
  final LogoutUseCase _logout;

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await _getProfile.call();
    result.fold(
      (_) => emit(Unauthenticated()),
      (user) => emit(Authenticated(user)),
    );
  }

  Future<void> _onOIDCLogin(OIDCLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await _oidcLogin.call(event.provider);
    result.fold(
      (failure) => emit(AuthError(failure.displayMessage)),
      (user) => emit(Authenticated(user)),
    );
  }

  Future<void> _onLogout(LogoutRequested event, Emitter<AuthState> emit) async {
    await _logout.call();
    emit(Unauthenticated());
  }

  Future<void> _onTokenRefreshFailed(TokenRefreshFailed event, Emitter<AuthState> emit) async {
    await _logout.call();
    emit(Unauthenticated());
  }
}
