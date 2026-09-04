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
/// TODO-F10T2:降级写本地后需置 pending 并在回网后上行(本任务 T1 不做,
/// 此处为锚点;镜像刷新的 pending 保护在 T2/T3)。
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
