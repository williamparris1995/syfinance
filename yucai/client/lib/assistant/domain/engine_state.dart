/// F66 引擎边车 —— 引擎生命周期状态值类型(FR-1/FR-3,ADR-5)。
///
/// sealed 四态:[EngineStopped](未运行)/[EngineStarting](冷启中,F65
/// 加载动效消费)/[EngineReady](健康探测通过,携带 /v1 端点)/
/// [EngineError](失败终态,携带原因)。值语义:同形状态相等 —— 值相等是
/// [ValueListenable] 家法去重通知的前提(见 engine_port.dart);toString
/// 全 English(NFR-3 结构化日志可直接携带,无 CJK)。
library;

/// 引擎失败原因(FR-1)。
enum EngineFailureReason {
  /// 模型文件缺失(FR-2:前置检查不过,不起进程)。
  modelMissing,

  /// 进程崩溃且重启退避超限(单次会话上限 3 次,超限不再自试)。
  crashed,

  /// 启动/健康探测失败(如端口竞态、就绪超时 30s)。
  startFailed,
}

/// llama-server 边车生命周期状态(ADR-5:sealed 四态 + 当前态缓存)。
sealed class EngineState {
  const EngineState();
}

/// 未运行:初始态 / 闲置回收(10 分钟)后 / shutdown 终结后。
class EngineStopped extends EngineState {
  const EngineStopped();

  @override
  String toString() => 'EngineStopped';
}

/// 启动中:进程已拉起、健康探测未过(FR-3:F65 据此渲染引擎加载动效)。
class EngineStarting extends EngineState {
  const EngineStarting();

  @override
  String toString() => 'EngineStarting';
}

/// 就绪:健康探测通过;[endpoint] = OpenAI 兼容 /v1 端点(FR-4 调用面)。
class EngineReady extends EngineState {
  const EngineReady(this.endpoint);

  /// 引擎 OpenAI 兼容端点(127.0.0.1 + 随机空闲端口,ADR-2)。
  final Uri endpoint;

  @override
  bool operator ==(Object other) =>
      other is EngineReady && other.endpoint == endpoint;

  @override
  int get hashCode => Object.hash(EngineReady, endpoint);

  @override
  String toString() => 'EngineReady(endpoint=$endpoint)';
}

/// 失败终态:重试超限后不再自试(FR-1);重新干预后走 ensureReady 复位。
class EngineError extends EngineState {
  const EngineError(this.reason);

  final EngineFailureReason reason;

  @override
  bool operator ==(Object other) =>
      other is EngineError && other.reason == reason;

  @override
  int get hashCode => Object.hash(EngineError, reason);

  @override
  String toString() => 'EngineError(reason=$reason)';
}
