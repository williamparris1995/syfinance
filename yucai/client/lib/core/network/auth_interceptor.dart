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

  // Client identity — sent on EVERY call so the server log can distinguish
  // between different Flutter clients / instances.
  String? clientId;
  String? appName;
  String? appVersion;

  void applyIdentity(Map<String, String> metadata) {
    if (clientId != null) metadata['x-client-id'] = clientId!;
    if (appName != null) metadata['x-app-name'] = appName!;
    if (appVersion != null) metadata['x-app-version'] = appVersion!;
  }

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
    final provider = (Map<String, String> metadata, String _) async {
      // Client identity is attached on EVERY call (incl. Register/Login).
      applyIdentity(metadata);
      if (isAuthBypassed(method.path)) return;
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
    final provider = (Map<String, String> metadata, String _) async {
      applyIdentity(metadata);
      if (isAuthBypassed(method.path)) return;
      final tokens = await (tokenReader?.call() ?? Future.value(null));
      if (tokens != null) {
        metadata['authorization'] = 'Bearer ${tokens.accessToken}';
      }
    };
    final enriched = options.mergedWith(CallOptions(providers: [provider]));
    return invoker(method, requests, enriched);
  }
}
