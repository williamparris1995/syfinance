import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:yucai_client/core/network/auth_interceptor.dart';

void main() {
  test('shouldRetry returns false for non-unauthenticated errors', () {
    expect(AuthInterceptor.shouldRetry(GrpcError.permissionDenied('no')), isFalse);
    expect(AuthInterceptor.shouldRetry(GrpcError.unavailable('down')), isFalse);
    expect(AuthInterceptor.shouldRetry(GrpcError.notFound('gone')), isFalse);
  });

  test('shouldRetry returns true for unauthenticated', () {
    expect(AuthInterceptor.shouldRetry(GrpcError.unauthenticated('expired')), isTrue);
  });

  test('isAuthBypassed true for OIDC bootstrap + RefreshToken', () {
    expect(AuthInterceptor.isAuthBypassed('/yucai.auth.v1.AuthService/RefreshToken'), isTrue);
    expect(AuthInterceptor.isAuthBypassed('/yucai.auth.v1.AuthService/GetOIDCConfig'), isTrue);
    expect(AuthInterceptor.isAuthBypassed('/yucai.auth.v1.AuthService/OIDCExchange'), isTrue);
  });

  test('isAuthBypassed false for protected methods', () {
    expect(AuthInterceptor.isAuthBypassed('/yucai.auth.v1.AuthService/GetProfile'), isFalse);
    expect(AuthInterceptor.isAuthBypassed('/yucai.account.v1.AccountService/ListAccounts'), isFalse);
  });
}
