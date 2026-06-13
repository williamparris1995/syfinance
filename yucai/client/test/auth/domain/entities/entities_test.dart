import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/entities/auth_tokens.dart';

void main() {
  group('User', () {
    test('constructs with required fields', () {
      final user = User(
        id: 'u1',
        tenantId: 't1',
        email: 'a@b.com',
        displayName: 'Andy',
        avatarUrl: '',
        createdAt: DateTime.parse('2026-06-13T00:00:00Z'),
      );
      expect(user.id, 'u1');
      expect(user.email, 'a@b.com');
    });

    test('equality is value-based', () {
      final a = User(id: 'u1', tenantId: 't1', email: 'a@b.com', displayName: 'A', avatarUrl: '', createdAt: DateTime(2026));
      final b = User(id: 'u1', tenantId: 't1', email: 'a@b.com', displayName: 'A', avatarUrl: '', createdAt: DateTime(2026));
      expect(a, b);
    });
  });

  group('AuthTokens', () {
    test('rejects empty tokens', () {
      expect(() => AuthTokens(accessToken: '', refreshToken: 'r'), throwsA(isA<AssertionError>()));
      expect(() => AuthTokens(accessToken: 'a', refreshToken: ''), throwsA(isA<AssertionError>()));
    });

    test('accepts non-empty tokens', () {
      const t = AuthTokens(accessToken: 'a', refreshToken: 'r');
      expect(t.accessToken, 'a');
      expect(t.refreshToken, 'r');
    });
  });
}
