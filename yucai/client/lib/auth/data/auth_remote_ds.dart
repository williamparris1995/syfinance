import 'package:injectable/injectable.dart';
import 'package:yucai_client/auth/data/mappers/user_mapper.dart';
import 'package:yucai_client/auth/domain/entities/auth_tokens.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/proto/auth/v1/auth.pb.dart' as pb;
import 'package:yucai_client/proto/auth/v1/auth.pbgrpc.dart' as grpc;

/// Wraps the generated AuthServiceClient. Throws GrpcError on failure
/// (caught and mapped by AuthRepositoryImpl).
@LazySingleton()
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._grpcClient, UserMapper mapper) : _mapper = mapper {
    _client = grpc.AuthServiceClient(
      _grpcClient.channel,
      interceptors: [_grpcClient.authInterceptor],
    );
  }

  final GrpcClient _grpcClient;
  final UserMapper _mapper;
  late final grpc.AuthServiceClient _client;

  Future<User> register(String email, String password, String displayName) async {
    final res = await _client.register(pb.RegisterRequest()
      ..email = email
      ..password = password
      ..displayName = displayName);
    return _mapper.toDomain(res.user);
  }

  Future<User> login(String email, String password) async {
    final res = await _client.login(pb.LoginRequest()
      ..email = email
      ..password = password);
    return _mapper.toDomain(res.user);
  }

  /// Raw refresh call used by AuthInterceptor (bypasses the Either layer).
  /// Returns new tokens or throws GrpcError.
  Future<AuthTokens> refreshToken(String refreshToken) async {
    final res =
        await _client.refreshToken(pb.RefreshTokenRequest()..refreshToken = refreshToken);
    return AuthTokens(accessToken: res.accessToken, refreshToken: res.refreshToken);
  }

  Future<User> getProfile() async {
    final res = await _client.getProfile(pb.GetProfileRequest());
    return _mapper.toDomain(res.user);
  }
}
