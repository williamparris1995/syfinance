import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yucai_client/auth/data/token_storage.dart';
import 'package:yucai_client/auth/domain/entities/auth_tokens.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage backend;
  late TokenStorage storage;

  setUp(() {
    backend = _MockSecureStorage();
    storage = TokenStorage(backend: backend);
    registerFallbackValue('');
  });

  test('readTokens returns null when no tokens stored', () async {
    when(() => backend.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    expect(await storage.readTokens(), isNull);
  });

  test('saveTokens then readTokens round-trips', () async {
    final stored = <String, String>{};
    when(() => backend.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((inv) async => stored[inv.namedArguments[#key] as String] =
            inv.namedArguments[#value] as String);
    when(() => backend.read(key: any(named: 'key')))
        .thenAnswer((inv) async => stored[inv.namedArguments[#key] as String]);

    const tokens = AuthTokens(accessToken: 'acc', refreshToken: 'ref');
    await storage.saveTokens(tokens);
    expect(await storage.readTokens(), tokens);
  });

  test('clearTokens deletes both keys', () async {
    when(() => backend.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    await storage.clearTokens();
    verify(() => backend.delete(key: 'yucai.access_token')).called(1);
    verify(() => backend.delete(key: 'yucai.refresh_token')).called(1);
  });
}
