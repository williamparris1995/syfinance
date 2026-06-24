import 'package:injectable/injectable.dart';
import 'package:yucai_client/auth/data/mappers/user_mapper.dart';
import 'package:yucai_client/auth/domain/entities/auth_tokens.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/proto/auth/v1/auth.pb.dart' as pb;
import 'package:yucai_client/proto/auth/v1/auth.pbgrpc.dart' as grpc;

/// Wraps the generated AuthServiceClient. Throws GrpcError on failure
/// (caught and mapped by AuthRepositoryImpl).
@LazySingleton()
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._grpcClient, this._retry, UserMapper mapper)
      : _mapper = mapper {
    _client = grpc.AuthServiceClient(
      _grpcClient.channel,
      interceptors: [_grpcClient.authInterceptor],
    );
  }

  final GrpcClient _grpcClient;
  final AuthRetryCaller _retry;
  final UserMapper _mapper;
  late final grpc.AuthServiceClient _client;

  Future<({User user, AuthTokens tokens})> register(
      String email, String password, String displayName) async {
    final res = await _client.register(pb.RegisterRequest()
      ..email = email
      ..password = password
      ..displayName = displayName);
    return (
      user: _mapper.toDomain(res.user),
      tokens: AuthTokens(accessToken: res.accessToken, refreshToken: res.refreshToken),
    );
  }

  Future<({User user, AuthTokens tokens})> login(String email, String password) async {
    final res = await _client.login(pb.LoginRequest()
      ..email = email
      ..password = password);
    return (
      user: _mapper.toDomain(res.user),
      tokens: AuthTokens(accessToken: res.accessToken, refreshToken: res.refreshToken),
    );
  }

  /// Raw refresh call used by AuthInterceptor (bypasses the Either layer).
  /// Returns new tokens or throws GrpcError.
  Future<AuthTokens> refreshToken(String refreshToken) async {
    final res =
        await _client.refreshToken(pb.RefreshTokenRequest()..refreshToken = refreshToken);
    return AuthTokens(accessToken: res.accessToken, refreshToken: res.refreshToken);
  }

  Future<User> getProfile() async {
    // Wrapped in AuthRetryCaller: a 401 (expired access token) triggers a
    // refresh + single retry, transparent to callers. The fresh token is
    // injected by AuthInterceptor on the retry via the metadata provider.
    return _retry.call(() async {
      final res = await _client.getProfile(pb.GetProfileRequest());
      return _mapper.toDomain(res.user);
    });
  }

  /// Raw preferred-currency read off the user profile (UserDTO field 7).
  /// Returns the code (e.g. "CNY"), or empty string when unset. Used by
  /// CurrencyBloc.LoadPreferencesRequested to populate `preferred`.
  Future<String> getPreferredCurrency() async {
    return _retry.call(() async {
      final res = await _client.getProfile(pb.GetProfileRequest());
      return res.user.preferredCurrency;
    });
  }

  /// Tenant-level rate-sync interval in hours (TenantPreferencesDTO field 2),
  /// read via the GetPreferences RPC. Used by CurrencyBloc.LoadPreferencesRequested
  /// to populate `interval`.
  Future<int> getRateSyncIntervalHours() async {
    return _retry.call(() async {
      final res = await _client.getPreferences(pb.GetPreferencesRequest());
      return res.preferences.rateSyncIntervalHours;
    });
  }
}
