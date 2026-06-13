import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/auth/data/mappers/user_mapper.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/proto/auth/v1/auth.pb.dart' as pb;

void main() {
  test('maps proto UserDTO to domain User', () {
    final dto = pb.UserDTO()
      ..id = 'u1'
      ..tenantId = 't1'
      ..email = 'a@b.com'
      ..displayName = 'Andy'
      ..avatarUrl = 'http://x.png'
      ..createdAt = '2026-06-13T10:00:00Z';

    final user = const UserMapper().toDomain(dto);

    expect(user, isA<User>());
    expect(user.id, 'u1');
    expect(user.email, 'a@b.com');
    expect(user.createdAt, DateTime.parse('2026-06-13T10:00:00Z'));
  });

  test('maps to domain User with empty avatar', () {
    final dto = pb.UserDTO()
      ..id = 'u2'
      ..tenantId = 't2'
      ..email = 'c@d.com'
      ..displayName = 'C'
      ..avatarUrl = ''
      ..createdAt = '2026-01-01T00:00:00Z';
    final user = const UserMapper().toDomain(dto);
    expect(user.avatarUrl, '');
    expect(user.id, 'u2');
  });
}
