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
}
