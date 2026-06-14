import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:yucai_client/core/network/auth_retry.dart';

void main() {
  late AuthRetryCaller caller;

  // Each test sets caller.refresher to the behavior it wants to exercise.
  setUp(() {
    caller = AuthRetryCaller();
  });

  test('passes through on success (no refresh)', () async {
    final result = await caller.call(() async => 42);
    expect(result, 42);
  });

  test('refreshes once and retries on 401', () async {
    var refreshed = 0;
    caller.refresher = () async {
      refreshed++;
      return true;
    };
    var calls = 0;
    final result = await caller.call(() async {
      calls++;
      if (calls == 1) throw GrpcError.unauthenticated('expired');
      return 'ok';
    });

    expect(result, 'ok');
    expect(calls, 2);
    expect(refreshed, 1);
  });

  test('rethrows non-401 errors (no refresh attempted)', () async {
    caller.refresher = () async => true;
    await expectLater(
      caller.call(() async => throw GrpcError.unavailable('down')),
      throwsA(isA<GrpcError>()),
    );
  });

  test('rethrows 401 when refresh fails (caller will surface logout)', () async {
    caller.refresher = () async => false; // refresh failed
    await expectLater(
      caller.call(() async => throw GrpcError.unauthenticated('expired')),
      throwsA(isA<GrpcError>()),
    );
  });

  test('concurrent 401s share a single refresh (mutex)', () async {
    var refreshCount = 0;
    caller.refresher = () async {
      refreshCount++;
      await Future.delayed(const Duration(milliseconds: 20));
      return true;
    };

    final firstSeen = <int>{};
    Future<String> run(int id) => caller.call(() async {
      if (firstSeen.add(id)) {
        throw GrpcError.unauthenticated('expired');
      }
      return 'ok-$id';
    });

    final results = await Future.wait([run(1), run(2), run(3)]);
    expect(results, ['ok-1', 'ok-2', 'ok-3']);
    expect(refreshCount, 1); // single shared refresh
  });
}
