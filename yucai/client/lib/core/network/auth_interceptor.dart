import 'dart:async';
import 'package:grpc/grpc.dart';
import 'package:yucai_client/auth/domain/entities/auth_tokens.dart';

/// Injects the Bearer access token into outgoing gRPC metadata.
///
/// Callbacks are set in DI (Task 13) to break the construction cycle:
/// - [tokenReader] : read current tokens from TokenStorage
/// - [refresher]   : perform a RefreshToken RPC, return new tokens (or null)
/// - [tokenSaver]  : persist refreshed tokens
///
/// Transparent 401-refresh-and-retry is handled at the repository/bloc layer
/// (catch GrpcError.unauthenticated → refresh → retry), which is more testable
/// than wrapping ResponseFuture streams inside the interceptor.
class AuthInterceptor extends ClientInterceptor {
  AuthInterceptor();

  Future<AuthTokens?> Function()? tokenReader;
  Future<AuthTokens?> Function()? refresher;
  Future<void> Function(AuthTokens)? tokenSaver;

  /// These auth methods carry credentials in the request body, not the header.
  /// gRPC method paths look like "/yucai.auth.v1.AuthService/Register".
  static bool isAuthBypassed(String method) {
    return method.endsWith('AuthService/Register') ||
        method.endsWith('AuthService/Login') ||
        method.endsWith('AuthService/RefreshToken');
  }

  /// True when a gRPC error is a 401 we could recover from via refresh.
  static bool shouldRetry(GrpcError e) => e.code == StatusCode.unauthenticated;

  @override
  ResponseFuture<R> interceptUnary<Q, R>(
    ClientMethod<Q, R> method,
    Q request,
    CallOptions options,
    ClientUnaryInvoker<Q, R> invoker,
  ) {
    final uri = method.path;
    if (isAuthBypassed(uri)) {
      return invoker(method, request, options);
    }
    // Attach a metadata provider that injects the Bearer token at call time.
    final provider = (Map<String, String> metadata, String _) async {
      final tokens = await (tokenReader?.call() ?? Future.value(null));
      if (tokens != null) {
        metadata['authorization'] = 'Bearer ${tokens.accessToken}';
      }
    };
    final enriched = options.mergedWith(CallOptions(providers: [provider]));
    return invoker(method, request, enriched);
  }

  @override
  ResponseStream<R> interceptStreaming<Q, R>(
    ClientMethod<Q, R> method,
    Stream<Q> requests,
    CallOptions options,
    ClientStreamingInvoker<Q, R> invoker,
  ) {
    final uri = method.path;
    if (isAuthBypassed(uri)) {
      return invoker(method, requests, options);
    }
    final provider = (Map<String, String> metadata, String _) async {
      final tokens = await (tokenReader?.call() ?? Future.value(null));
      if (tokens != null) {
        metadata['authorization'] = 'Bearer ${tokens.accessToken}';
      }
    };
    final enriched = options.mergedWith(CallOptions(providers: [provider]));
    return invoker(method, requests, enriched);
  }
}
