import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/login_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/register_usecase.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_event.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';

@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(
    this._login,
    this._register,
    this._getProfile,
    this._logout,
  ) : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLogin);
    on<RegisterRequested>(_onRegister);
    on<LogoutRequested>(_onLogout);
    on<TokenRefreshFailed>(_onTokenRefreshFailed);
  }

  final LoginUseCase _login;
  final RegisterUseCase _register;
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

  Future<void> _onLogin(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await _login.call(LoginParams(email: event.email, password: event.password));
    result.fold(
      (failure) => emit(AuthError(failure.displayMessage)),
      (user) => emit(Authenticated(user)),
    );
  }

  Future<void> _onRegister(RegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await _register.call(RegisterParams(
      email: event.email,
      password: event.password,
      displayName: event.displayName,
    ));
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
