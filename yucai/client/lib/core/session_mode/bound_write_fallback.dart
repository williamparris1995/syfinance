import 'package:dartz/dartz.dart';
import 'package:yucai_client/core/error/failures.dart';

/// F10 FR-1b / design ADR-1:绑定在线态写降级助手(8 个双源 repo 共享)。
///
/// 先执行远端写:
/// - Right → 直接返回(在线成功路径,行为与 R6 逐位一致);
/// - Left 且失败为 [NetworkFailure](grpc unavailable / 断网)→ 降级执行
///   本地写并返回其结果 —— connectivity 探测误报在线时的双保险,
///   数据不丢(离线完整记账宪法);
/// - 其他失败(校验 / 权限 / 服务端错误)不降级,原样 Left 上抛。
///
/// F10 T2:降级落库的 pending 置位由各 repo `_routedWrite` 的本地闭包
/// `local(true)` 承担(与 boundOfflineLocal 分支同语义);回网收集上行
/// 与成功回 synced 在 T3。
Future<Either<Failure, T>> writeWithFallback<T>(
  Future<Either<Failure, T>> Function() remote,
  Future<Either<Failure, T>> Function() local,
) async {
  final result = await remote();
  final failure = result.fold((f) => f, (_) => null);
  if (failure is NetworkFailure) {
    return local();
  }
  return result;
}
