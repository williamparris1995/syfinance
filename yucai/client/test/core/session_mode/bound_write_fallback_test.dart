// F10 T1(2026-09-03):写降级助手 writeWithFallback 单测(FR-1b 双保险)。
// 四象限:远端 Right 直返 / NetworkFailure 降级本地 / 其他 Failure 不降级 /
// 双 Left(远端 NetworkFailure + 本地失败)返回本地 Left。
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/session_mode/bound_write_fallback.dart';

void main() {
  test('远端 Right → 直接返回,不触碰本地(在线成功路径逐位不变)', () async {
    var localTouched = false;
    final result = await writeWithFallback(
      () async => const Right(42),
      () async {
        localTouched = true;
        return const Left<Failure, int>(ServerFailure('should not run'));
      },
    );
    expect(result, const Right<Failure, int>(42));
    expect(localTouched, isFalse);
  });

  test('远端 NetworkFailure → 降级执行本地并返回其结果', () async {
    var localCalls = 0;
    final result = await writeWithFallback(
      () async => const Left<Failure, int>(NetworkFailure('grpc unavailable')),
      () async {
        localCalls++;
        return const Right<Failure, int>(7);
      },
    );
    expect(result, const Right<Failure, int>(7));
    expect(localCalls, 1);
  });

  test('远端其他 Failure(校验/权限)→ 不降级,原样 Left 上抛', () async {
    var localTouched = false;
    const failure = ValidationFailure('bad amount');
    final result = await writeWithFallback(
      () async => const Left<Failure, int>(failure),
      () async {
        localTouched = true;
        return const Right<Failure, int>(7);
      },
    );
    expect(result, const Left<Failure, int>(failure));
    expect(localTouched, isFalse);
  });

  test('双 Left:远端 NetworkFailure + 本地失败 → 返回本地的 Left', () async {
    const localFailure = ServerFailure('本地写入失败');
    final result = await writeWithFallback(
      () async => const Left<Failure, int>(NetworkFailure('down')),
      () async => const Left<Failure, int>(localFailure),
    );
    expect(result, const Left<Failure, int>(localFailure));
  });
}
