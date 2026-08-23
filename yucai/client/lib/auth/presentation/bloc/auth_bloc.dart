import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/has_stored_credentials_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/oidc_login_usecase.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_event.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';

@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(
    this._oidcLogin,
    this._getProfile,
    this._logout,
    this._hasCredentials,
    this._sessionMode, [
    this._mirror,
  ]) : super(AuthInitial()) {
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
  final SessionModeTracker _sessionMode;
  final BoundMirror? _mirror;

  /// Single-point sync into the core-layer session flag consumed by the
  /// dual-source seam (R6 ADR-2) — data-layer repos never read this bloc.
  @override
  void onChange(Change<AuthState> change) {
    super.onChange(change);
    _sessionMode.isGuest = change.nextState is Guest;
    // Login-refresh: entering Authenticated mirrors all modules so the
    // logout-into-guest experience works immediately (R6 H, ADR-3).
    if (change.nextState is Authenticated) {
      unawaited(_mirror?.refreshAll() ?? Future<void>.value());
    }
  }

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
    // Terminal mirror refresh while tokens are still valid (offline → catch,
    // fall back to the existing mirror). R6 H, design ADR-3.
    if (_mirror != null) {
      try {
        await _mirror.refreshAll();
      } catch (_) {}
    }
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
