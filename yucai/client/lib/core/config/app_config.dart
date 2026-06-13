/// Server connection configuration. Values injected via --dart-define.
class AppConfig {
  const AppConfig({
    required this.serverHost,
    required this.serverPort,
    required this.useTls,
  });

  /// Reads from --dart-define, falling back to local-dev defaults.
  /// dart-define keys: SERVER_HOST, SERVER_PORT, USE_TLS
  AppConfig.fromEnvironment()
      : serverHost = const String.fromEnvironment('SERVER_HOST', defaultValue: 'localhost'),
        serverPort = const int.fromEnvironment('SERVER_PORT', defaultValue: 9090),
        useTls = const bool.fromEnvironment('USE_TLS', defaultValue: false);

  final String serverHost;
  final int serverPort;
  final bool useTls;
}
