import 'package:dartz/dartz.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';

/// 交易模板仓库接口(domain 层,不 import proto)。8 method 对齐
/// TransactionTemplateService 8 RPC(list/create/update/delete/pause/resume/get/record)。
abstract class TemplateRepository {
  Future<Either<Failure, List<Template>>> list({bool? paused});

  Future<Either<Failure, Template>> create({
    required String name,
    String description,
    required int amountCents,
    TemplateDirection direction,
    String? sourceAccountId,
    String? destinationAccountId,
    TemplateCycle cycle,
    int cycleDays,
    int billingDay,
    String? startDate,
    String? endDate,
    bool autoRecord,
    String? category,
  });

  Future<Either<Failure, Template>> update({
    required String id,
    required int version,
    String? name,
    String? description,
    int? amountCents,
    TemplateCycle? cycle,
    int? cycleDays,
    String? endDate,
    bool? autoRecord,
  });

  Future<Either<Failure, void>> delete(String id);

  Future<Either<Failure, Template>> pause(String id);

  Future<Either<Failure, Template>> resume(String id);

  Future<Either<Failure, Template>> get(String id);

  Future<Either<Failure, RecordResult>> record(String templateId);
}
