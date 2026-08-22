import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/has_stored_credentials_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/oidc_login_usecase.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_event.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/core/error/failures.dart';

@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(
    this._oidcLogin,
    this._getProfile,
    this._logout,
    this._hasCredentials,
  ) : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<OIDCLoginRequested>(_onOIDCLogin);
    on<SkipLoginRequested>(_onSkipLogin);
    on<LogoutRequested>(_onLogout);
    on<TokenRefreshFailed>(_onTokenRefreshFailed);
  }

  final OidcLoginUseCase _oidcLogin;
  final GetProfileUseCase _getProfile;
  final LogoutUseCase _logout;
  final HasStoredCredentialsUseCase _hasCredentials;

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    // Token precheck first: without credentials go straight to guest — no
    // doomed profile RPC, and an offline NetworkFailure can't be mistaken
    // for a kept session (design ADR-2).
    if (!await _hasCredentials.call()) {
      emit(Guest());
      return;
    }
    final result = await _getProfile.call();
    result.fold(
      (failure) => emit(
        failure is NetworkFailure ? OfflineAuthenticated() : Unauthenticated(),
      ),
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

  Future<void> _onSkipLogin(SkipLoginRequested event, Emitter<AuthState> emit) async {
    emit(Guest());
  }

  Future<void> _onLogout(LogoutRequested event, Emitter<AuthState> emit) async {
    await _logout.call();
    // Binding is the user's free choice (R6 M2): logout lands in guest mode,
    // not the login page.
    emit(Guest());
  }

  Future<void> _onTokenRefreshFailed(TokenRefreshFailed event, Emitter<AuthState> emit) async {
    await _logout.call();
    emit(Guest());
  }
}
