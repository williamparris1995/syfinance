import 'package:equatable/equatable.dart';

/// Authenticated user. Pure domain — no proto or Flutter imports.
class User extends Equatable {
  const User({
    required this.id,
    required this.tenantId,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String email;
  final String displayName;
  final String avatarUrl;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, tenantId, email, displayName, avatarUrl, createdAt];
}
