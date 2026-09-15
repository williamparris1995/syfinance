import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/notifications/app_exit_port.dart';

/// exit(0) 哨兵:假 exit 抛出以满足 Never 返回型,同时留下「走到了
/// exit(0)」的可观测证据(不真杀测试进程)。
class _ExitSentinel implements Exception {}

void main() {
  group('TrayAppExit (R8 F22 T1/T4)', () {
    test('implements AppExitPort', () {
      final port = TrayAppExit(() async {});
      expect(port, isA<AppExitPort>());
    });

    test('exitApp awaits the injected onExit before process exit', () async {
      // 不真 exit(0)(会杀掉测试进程本身):onExit 内挂一个永不完成的
      // Completer,验证 exitApp 调用了 onExit 且在 onExit 完成前保持挂起
      // —— 即 exitApp 是 await onExit 而非 fire-and-forget;exit(0) 排在
      // await 之后,由注入点设计保证,不在单测覆盖。
      var onExitStarted = false;
      final release = Completer<void>();
      final port = TrayAppExit(() async {
        onExitStarted = true;
        await release.future;
      });

      final exiting = port.exitApp();
      await Future<void>.delayed(Duration.zero);

      expect(onExitStarted, isTrue);

      var exitAppDone = false;
      unawaited(exiting.then((_) => exitAppDone = true));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(exitAppDone, isFalse); // onExit 未完成 → exitApp 不得先完成
    });

    test('onExit 抛错 → 仍以 exit 收尾(try/finally 语义)', () async {
      // T1 评审遗留:stop 抛错也必退出(fail-safe 到「不留僵尸」)。生产
      // 路径 exit(0) Never 返回,原异常被进程终止吞掉 —— 单测以假 exit
      // 哨兵观察 finally 语义:exit 必被调用,且冒出的是 exit 哨兵而非
      // onExit 的 StateError(即清理错误被 exit 覆盖,不再向上传播)。
      var exitCalls = 0;
      final port = TrayAppExit(
        () async => throw StateError('stop failed'),
        exitFn: () {
          exitCalls++;
          throw _ExitSentinel();
        },
      );

      await expectLater(port.exitApp(), throwsA(isA<_ExitSentinel>()));
      expect(exitCalls, 1); // onExit 抛错也走到了 exit
    });
  });
}
