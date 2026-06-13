import 'package:equatable/equatable.dart';

/// Access + refresh token pair. Both must be non-empty.
class AuthTokens extends Equatable {
  const AuthTokens({required this.accessToken, required this.refreshToken})
      : assert(accessToken != ''),
        assert(refreshToken != '');

  final String accessToken;
  final String refreshToken;

  @override
  List<Object?> get props => [accessToken, refreshToken];
}
