import 'package:dartz/dartz.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/debt/domain/entities/receivables_summary.dart';

/// 应收债权汇总仓储(receivables 对齐,Task 8)。
/// Task 9-11 presentation / bloc 消费此接口取 summary。
abstract class ReceivablesSummaryRepository {
  Future<Either<Failure, ReceivablesSummary>> fetch();
}
