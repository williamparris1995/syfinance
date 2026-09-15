import 'dart:io';

/// 进程退出缝(照 DataResetController.ExitFn 先例):生产 = `exit(0)`;
/// 测试注入抛哨兵/记录调用的假实现,避免单测真杀测试进程。返回 [Never]
/// 表达「不回来」。
typedef AppExitFn = Never Function();

/// 应用退出 port(F22 FR-1):设置页退出按钮消费的抽象出口。
///
/// 跨模块 port 模式:消费方(settings 页)只依赖本抽象,不 import
/// tray_controller 具体类。绑定态/guest 均可用 —— 退出是纯本地动作,
/// 不涉及同步与登录态。
abstract class AppExitPort {
  /// 清理并退出进程;实现保证退出前完成清理,且**清理抛错也必退出**
  /// (见 [TrayAppExit] 的 try/finally 语义)。
  Future<void> exitApp();
}

/// [AppExitPort] 生产实现:先 await 清理回调 [onExit](即
/// TrayController.stop —— 以函数注入避免依赖具体类),完成后 exit(0)
/// 真正结束进程(spec NFR:不留僵尸)。
///
/// try/finally 语义(T1 评审遗留):[onExit] 抛错时 finally 仍执行
/// exit(0) —— stop 失败不得把进程留成托盘僵尸;生产路径 exit Never
/// 返回,原异常被进程终止吞掉,调用方不会看到清理错误冒出。
///
/// exit(0) 的进程终止由 [AppExitFn] 缝的注入点设计保证,单测经假
/// exit 观察 finally 路径(真 exit 会杀掉测试进程本身,不真调);注册时点在
/// bootstrap 接线(T4,手工单例,照 injection.dart 手工注册先例)。
class TrayAppExit implements AppExitPort {
  TrayAppExit(this.onExit, {AppExitFn? exitFn})
      : _exit = exitFn ?? _defaultExit;

  /// 清理入口(构造注入;生产 = TrayController.stop)。
  final Future<void> Function() onExit;

  final AppExitFn _exit;

  static Never _defaultExit() => exit(0);

  @override
  Future<void> exitApp() async {
    try {
      await onExit();
    } finally {
      // 清理抛错也必退出:fail-safe 到「不留僵尸」。
      _exit();
    }
  }
}
