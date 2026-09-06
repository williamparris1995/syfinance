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
    // 会话旗标状态机(user-acceptance 修复 + F10 FR-2 路由修复):
    // AuthLoading/AuthInitial/AuthError 保持原值 —— 此前 Loading 一律判非
    // Guest,首页面板在鉴权解析窗口期全部打到远端(离线即全灭,且不重试)。
    // - Guest → isGuest=true(guestLocal,本地读写);
    // - Authenticated → isGuest=false + authOffline=false(boundRemote,
    //   远端权威,与 R6 在线路径行为逐位一致);
    // - OfflineAuthenticated(绑定+离线冷启动)→ isGuest=false +
    //   authOffline=true —— 数据路由落 boundOfflineLocal(本地镜像读写,
    //   离线完整功能可用宪法)。F10 修复:旧版与 Authenticated 同置
    //   isGuest=false 而无离线旗标,注释宣称「本地读」但实际全远端,
    //   绑定+离线冷启动读写全红;回网重新解析为 Authenticated 后恢复
    //   在线语义(authOffline 翻回 false)。
    final next = change.nextState;
    if (next is Guest) {
      _sessionMode.isGuest = true;
      _sessionMode.authOffline = false;
    } else if (next is Authenticated) {
      _sessionMode.isGuest = false;
      _sessionMode.authOffline = false;
    } else if (next is OfflineAuthenticated) {
      _sessionMode.isGuest = false;
      _sessionMode.authOffline = true;
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
/// F17-T1:readTenantId 随 BoundMarker 职责单一化一并退役('bound' 仅余
/// 绑定标记语义,deviceId 独立取 clientId)。
class _NoopBoundMarker implements BoundMarker {
  const _NoopBoundMarker();

  @override
  Future<void> markBound(String tenantId) async {}

  @override
  Future<bool> isBound() async => false;

  @override
  Future<void> clear() async {}
}
