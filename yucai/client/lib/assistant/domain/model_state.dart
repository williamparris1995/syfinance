/// F67 端侧模型管理 —— 模型下载/就绪状态值类型(FR-1..4,ADR-7)。
///
/// sealed 五态:[ModelNotDownloaded](未下载/已删除)/[ModelDownloading]
/// (下载中,携带进度三元组)/[ModelPaused](用户暂停,.part 保留可续传)/
/// [ModelReady](sha256 校验通过、原子落地完成)/[ModelError](失败终态,
/// 携带原因)。照 EngineState 家法:值相等是 [ValueListenable] 去重通知
/// 的前提(见 model_manager_port.dart);toString 全 English(NFR-3
/// 结构化日志可直接携带,无 CJK)。
library;

/// 模型下载/校验失败原因(FR-1)。
///
/// 无 canceled 值:用户取消的终态语义是 [ModelNotDownloaded](cancel =
/// 断流 + 删 .part,LLD),不走 error 态。
enum ModelFailureReason {
  /// 网络/源失败(连接错、超时、404/416 —— 官方源一次回落镜像后仍败,
  /// ADR-4)。error(network) 态可再 download() 经 .part 续传。
  network,

  /// sha256 校验不符(源文件漂移,ADR-3:.part 保留供排查;重试须删
  /// .part 从零整段重下)。
  corrupt,
}

/// 端侧模型(.gguf)下载/就绪生命周期(ADR-7:sealed 五态 + 当前态缓存)。
sealed class ModelState {
  const ModelState();
}

/// 未下载:初始态 / cancel 删 .part 后 / delete 终结后。
class ModelNotDownloaded extends ModelState {
  const ModelNotDownloaded();

  @override
  String toString() => 'ModelNotDownloaded';
}

/// 下载中:[receivedBytes]/[totalBytes] 供 F65 进度渲染,
/// [bytesPerSec] 为滑动窗速度(ADR-6,进度 200ms 节流携带)。
class ModelDownloading extends ModelState {
  const ModelDownloading({
    required this.receivedBytes,
    required this.totalBytes,
    required this.bytesPerSec,
  });

  /// 已收字节(含此前 .part 续传基数)。
  final int receivedBytes;

  /// 总字节(kModelManifest.totalBytes 钉死值)。
  final int totalBytes;

  /// 当前速度(字节/秒,滑动窗估计,design 参数)。
  final int bytesPerSec;

  @override
  bool operator ==(Object other) =>
      other is ModelDownloading &&
      other.receivedBytes == receivedBytes &&
      other.totalBytes == totalBytes &&
      other.bytesPerSec == bytesPerSec;

  @override
  int get hashCode =>
      Object.hash(ModelDownloading, receivedBytes, totalBytes, bytesPerSec);

  @override
  String toString() =>
      'ModelDownloading(receivedBytes=$receivedBytes, '
      'totalBytes=$totalBytes, bytesPerSec=$bytesPerSec)';
}

/// 用户暂停:断流保 .part(receivedBytes 为 .part 已收字节);
/// 再 download() 自动走 Range 续传(LLD)。
class ModelPaused extends ModelState {
  const ModelPaused({required this.receivedBytes, required this.totalBytes});

  /// 暂停时已收字节(= .part 大小,恢复请求的 Range 基数)。
  final int receivedBytes;

  /// 总字节(kModelManifest.totalBytes 钉死值)。
  final int totalBytes;

  @override
  bool operator ==(Object other) =>
      other is ModelPaused &&
      other.receivedBytes == receivedBytes &&
      other.totalBytes == totalBytes;

  @override
  int get hashCode =>
      Object.hash(ModelPaused, receivedBytes, totalBytes);

  @override
  String toString() =>
      'ModelPaused(receivedBytes=$receivedBytes, totalBytes=$totalBytes)';
}

/// 就绪:sha256 流式校验通过 + 原子 rename 落地(ADR-3),
/// ModelStore.isReady()=true(引擎侧 ensureReady 直接过)。
class ModelReady extends ModelState {
  const ModelReady();

  @override
  String toString() => 'ModelReady';
}

/// 失败终态:[reason] 区分可续传的网络败与须整段重下的校验败;
/// 用户重新干预(重试/删除)后复位。
class ModelError extends ModelState {
  const ModelError(this.reason);

  final ModelFailureReason reason;

  @override
  bool operator ==(Object other) =>
      other is ModelError && other.reason == reason;

  @override
  int get hashCode => Object.hash(ModelError, reason);

  @override
  String toString() => 'ModelError(reason=$reason)';
}
