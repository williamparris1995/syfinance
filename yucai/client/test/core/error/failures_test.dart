import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/error/failures.dart';

void main() {
  test('each failure carries a message', () {
    expect(const ServerFailure('boom').message, 'boom');
    expect(const NetworkFailure('down').message, 'down');
    expect(const AuthFailure('bad token').message, 'bad token');
    expect(const ValidationFailure('empty').message, 'empty');
    expect(const UnexpectedFailure('??').message, '??');
  });

  test('equality is value-based', () {
    expect(const ServerFailure('x'), const ServerFailure('x'));
    expect(const ServerFailure('x') == const ServerFailure('y'), isFalse);
  });

  test('displayMessage is localized', () {
    expect(const NetworkFailure('x').displayMessage, '网络错误：x');
    expect(const AuthFailure('x').displayMessage, '认证失败：x');
  });
}
