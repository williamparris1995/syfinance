import 'package:equatable/equatable.dart';

/// Sealed failure hierarchy. Returned as the Left of Either<Failure, T>.
sealed class Failure extends Equatable {
  const Failure(this.message);
  final String message;

  /// User-facing Chinese message for UI.
  String get displayMessage => message;

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
  @override
  String get displayMessage => '网络错误：$message';
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
  @override
  String get displayMessage => '认证失败：$message';
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
  @override
  String get displayMessage => '输入有误：$message';
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
  @override
  String get displayMessage => '发生未知错误：$message';
}
