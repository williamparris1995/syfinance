import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/config/app_config.dart';

void main() {
  test('uses provided values when set directly', () {
    const config = AppConfig(
      serverHost: '10.0.0.1',
      serverPort: 9999,
      useTls: true,
    );
    expect(config.serverHost, '10.0.0.1');
    expect(config.serverPort, 9999);
    expect(config.useTls, isTrue);
  });

  test('fromEnvironment falls back to defaults', () {
    final config = AppConfig.fromEnvironment();
    expect(config.serverHost, 'localhost');
    expect(config.serverPort, 9090);
    expect(config.useTls, isFalse);
  });
}
