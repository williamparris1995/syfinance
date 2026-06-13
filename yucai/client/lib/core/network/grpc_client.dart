import 'package:grpc/grpc.dart';
import 'package:yucai_client/core/config/app_config.dart';
import 'package:yucai_client/core/network/auth_interceptor.dart';

/// Holds the gRPC ClientChannel and the shared AuthInterceptor.
/// Manually registered in DI (network cycle — see Task 13).
class GrpcClient {
  GrpcClient(this.config, this.authInterceptor);

  final AppConfig config;
  final AuthInterceptor authInterceptor;

  late final ClientChannel channel = ClientChannel(
    config.serverHost,
    port: config.serverPort,
    options: ChannelOptions(
      credentials: config.useTls
          ? const ChannelCredentials.secure()
          : const ChannelCredentials.insecure(),
    ),
  );

  Future<void> shutdown() => channel.shutdown();
}
