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
import 'package:yucai_client/core/session_mode/bound_marker.dart';
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
    this._boundMarker = const _NoopBoundMarker(),
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
  final BoundMarker _boundMarker;

  /// Single-point sync into the core-layer session flag consumed by the
  /// dual-source seam (R6 ADR-2) — data-layer repos never read this bloc.
  @override
  void onChange(Change<AuthState> change) {
    super.onChange(change);
    // 会话旗标状态机(user-acceptance 修复):AuthLoading/AuthInitial 保持
    // 原值 —— 此前 Loading 一律判非 Guest,首页面板在鉴权解析窗口期全部
    // 打到远端(离线即全灭,且不重试)。OfflineAuthenticated(绑定+离线)
    // 切本地读:离线完整功能可用(宪法),回网 Online 后恢复 server 权威。
    final next = change.nextState;
    if (next is Guest) {
      _sessionMode.isGuest = true;
    } else if (next is Authenticated || next is OfflineAuthenticated) {
      _sessionMode.isGuest = false;
    }
    // AuthLoading / AuthInitial / AuthError:保持上次值。
    // Login-refresh (BOUND devices only, review H-W4): an unbound guest
    // logging into an empty account is the FIRST-BINDING flow — refreshing
    // there would wipe the local store before the upload wizard runs.
    // BindingBloc mirrors after its own upload instead.
    if (change.nextState is Authenticated) {
      unawaited(() async {
        if (await _boundMarker.isBound()) {
          await _mirror?.refreshAll();
        }
      }());
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
    // Best-effort terminal refresh (tokens may already be dead — try/catch,
    // ADR-3). Matches the LogoutRequested path.
    if (_mirror != null) {
      try {
        await _mirror.refreshAll();
      } catch (_) {}
    }
    await _logout.call();
    emit(Guest());
  }
}


/// Const default for tests that construct AuthBloc without a marker.
class _NoopBoundMarker implements BoundMarker {
  const _NoopBoundMarker();

  @override
  Future<void> markBound(String tenantId) async {}

  @override
  Future<bool> isBound() async => false;

  @override
  Future<void> clear() async {}
}
