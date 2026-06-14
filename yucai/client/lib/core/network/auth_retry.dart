import 'dart:async';
import 'package:grpc/grpc.dart';

/// Transparently refreshes the access token on a 401 and retries the call once.
///
/// Why a repo-layer helper (not interceptor-level): grpc Dart's
/// `interceptUnary` must return a `ResponseFuture<R>` synchronously, so it
/// can't await a 401 then retry. This helper wraps each protected remote call
/// instead — a one-liner per data-source method.
///
/// The [refresher] callback (set in DI, NOT a constructor dep) performs the
/// RefreshToken RPC and returns whether it succeeded. Keeping it as a callback
/// breaks the static dependency cycle that would otherwise form:
///   AuthRemoteDataSource → AuthRetryCaller → RefreshTokenUseCase
///   → AuthRepository → AuthRepositoryImpl → AuthRemoteDataSource  (cycle)
/// so injectable_generator can topologically sort the graph.
///
/// Guarantees:
///   - Catches `GrpcError(unauthenticated)` only; other errors propagate.
///   - Refresh is mutex-guarded: concurrent 401s share a single refresh.
///   - Retries the original call **once** after a successful refresh (the
///     AuthInterceptor re-reads the fresh token from storage at call time).
///   - On refresh failure, the 401 is rethrown so the AuthBloc logs the user
///     out cleanly (AppStarted → Unauthenticated).
///
/// Do NOT wrap `AuthService.RefreshToken` itself (recursion).
class AuthRetryCaller {
  AuthRetryCaller();

  /// Performs the refresh; returns true on success. Set in DI after the
  /// RefreshTokenUseCase is available.
  Future<bool> Function()? refresher;

  Completer<bool>? _refreshInFlight;

  Future<T> call<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on GrpcError catch (e) {
      if (e.code != StatusCode.unauthenticated) rethrow;
      final refreshed = await _refreshOnce();
      if (!refreshed) rethrow; // refresh failed → propagate 401 → logout
      return op(); // retry once with the fresh access token
    }
  }

  Future<bool> _refreshOnce() async {
    // Mutex: concurrent 401s await the same in-flight refresh.
    if (_refreshInFlight != null) return _refreshInFlight!.future;
    final c = Completer<bool>();
    _refreshInFlight = c;
    try {
      final ok = await (refresher?.call() ?? Future.value(false));
      c.complete(ok);
    } catch (_) {
      c.complete(false);
    } finally {
      _refreshInFlight = null;
    }
    return c.future;
  }
}
