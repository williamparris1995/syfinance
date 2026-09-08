import 'package:flutter/foundation.dart';

import 'package:yucai_client/binding/domain/offline_sync_port.dart';

/// F10 T3(spec FR-5,design ADR-5):OfflineSyncPort 的保 pending 占位实现。
///
/// **F11 T3 后退出生产接线**:injection.dart 1h 已改注册
/// GrpcOfflineSyncPort(gRPC PushChanges 真实现);本类保留作参考与测试
/// 替身(需要「push 恒失败、pending 原样保留」场景的测试可直接复用)。
///
/// 语义:push 恒失败(原因「同步服务未接入」)—— 绝不能返回成功:成功会
/// 触发协调器回写 synced + 清墓碑 + 镜像刷新,把从未真正上行的 pending 行
/// 抹成「已同步」造成永久丢失;失败则 pending 保留,待真实现接入后首次
/// 触发自然补上行。
class NoopOfflineSyncPort implements OfflineSyncPort {
  @override
  Future<SyncResult> push(SyncBatch batch) async {
    debugPrint(
        '[offline-sync] F11 gRPC port not implemented yet; push skipped '
        '(${batch.changeCount} changes kept pending)');
    return const SyncResult.failure('同步服务未接入（F11）');
  }

  /// F17-T1:占位实现同语义 —— 注册无副作用(未接真实现前不建设备行);
  /// 静默成功即可(调用方 BindingBloc 对注册失败本就 fire-and-forget 容错,
  /// 此处不产生额外噪音)。
  @override
  Future<void> registerDevice(String deviceName) async {}

  /// F17-T2:占位实现 —— 未接真实现前无下行语义,恒空页(since 原样回,
  /// frontier 无推进,hasMore=false 不续拉);协调器拿到空批即无应用动作,
  /// 幂等无害。真实现见 GrpcOfflineSyncPort.pull(生产 DI 已注册)。
  @override
  Future<PullBatch> pull(int sinceVersion,
      {List<String>? entityTypes, int? pageSize}) async {
    return PullBatch(
      changes: const [],
      latestVersion: sinceVersion,
      hasMore: false,
    );
  }

  /// F18-T2:占位实现 —— 冲突解决面空页(无待解决冲突;面板 bloc 拿到
  /// 空列表即空态,幂等无害)。真实现见 GrpcOfflineSyncPort.listConflicts
  /// (生产 DI 已注册)。
  @override
  Future<ConflictPage> listConflicts({String? pageToken}) async {
    return const ConflictPage(items: [], totalCount: 0);
  }

  /// F18-T2:占位实现 —— 未接真实现前无解决副作用,静默成功即可(调用方
  /// 是面板 bloc,resolve 后重取列表拿到恒空页,状态自洽)。
  @override
  Future<void> resolveConflict(String conflictId, String resolution,
      {List<int>? mergedPayload}) async {}
}
