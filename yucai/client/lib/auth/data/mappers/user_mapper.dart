import 'package:injectable/injectable.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/proto/auth/v1/auth.pb.dart' as pb;

/// Maps generated proto UserDTO <-> domain User.
@injectable
class UserMapper {
  const UserMapper();

  User toDomain(pb.UserDTO dto) {
    return User(
      id: dto.id,
      tenantId: dto.tenantId,
      email: dto.email,
      displayName: dto.displayName,
      avatarUrl: dto.avatarUrl,
      createdAt: dto.createdAt.isEmpty ? DateTime.now() : DateTime.parse(dto.createdAt),
    );
  }
}
