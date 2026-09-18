import 'package:fixnum/fixnum.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/proto/common/v1/pagination.pb.dart' as common;
import 'package:yucai_client/proto/common/v1/recurrence.pbenum.dart' as pbcommon;
import 'package:yucai_client/proto/template/v1/template.pb.dart' as pb;
import 'package:yucai_client/proto/template/v1/template.pbgrpc.dart' as grpc;
import 'package:yucai_client/template/data/mappers/template_mapper.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';

/// 封装生成的 TransactionTemplateServiceClient。抛 GrpcError(repo 层 catch 映射)。
/// 对齐 TagRemoteDataSource/DebtRemoteDataSource:每 RPC AuthRetryCaller wrap。
@LazySingleton()
class TemplateRemoteDataSource {
  TemplateRemoteDataSource(this._grpcClient, this._retry) {
    _client = grpc.TransactionTemplateServiceClient(
      _grpcClient.channel,
      interceptors: [_grpcClient.authInterceptor],
    );
  }

  final GrpcClient _grpcClient;
  final AuthRetryCaller _retry;
  late final grpc.TransactionTemplateServiceClient _client;

  Future<List<Template>> list({bool? paused}) async {
    return _retry.call(() async {
      final res = await _client.listTransactionTemplates(pb.ListTemplatesRequest(
        page: common.PageRequest(pageSize: 100),
        paused: paused,
      ));
      return res.templates.map(TemplateMapper.toDomain).toList();
    });
  }

  Future<Template> create({
    required String name,
    String description = '',
    required int amountCents,
    TemplateDirection direction = TemplateDirection.unspecified,
    String? sourceAccountId,
    String? destinationAccountId,
    TemplateCycle cycle = TemplateCycle.unspecified,
    int cycleDays = 0,
    int billingDay = 0,
    int interval = 0,
    int weekdayMask = 0,
    int monthlyMode = 0,
    int nth = 0,
    String? startDate,
    String? endDate,
    bool autoRecord = false,
    String? category,
  }) async {
    return _retry.call(() async {
      final res = await _client.createTransactionTemplate(pb.CreateTemplateRequest(
        name: name,
        description: description,
        amountCents: Int64(amountCents),
        direction: TemplateMapper.toPbDirection(direction),
        sourceAccountId: sourceAccountId ?? '',
        destinationAccountId: destinationAccountId ?? '',
        cycle: TemplateMapper.toPbCycle(cycle),
        cycleDays: cycleDays,
        billingDay: billingDay,
        startDate: startDate ?? '',
        endDate: endDate ?? '',
        autoRecord: autoRecord,
        category: category ?? '',
      ));
      return TemplateMapper.toDomain(res.template);
    });
  }

  Future<Template> update({
    required String id,
    required int version,
    String? name,
    String? description,
    int? amountCents,
    TemplateCycle? cycle,
    int? cycleDays,
    int? billingDay,
    int? interval,
    int? weekdayMask,
    int? monthlyMode,
    int? nth,
    String? endDate,
    bool? autoRecord,
  }) async {
    return _retry.call(() async {
      final res = await _client.updateTransactionTemplate(pb.UpdateTemplateRequest(
        id: id,
        name: name ?? '',
        description: description ?? '',
        amountCents: amountCents != null ? Int64(amountCents) : Int64.ZERO,
        // 规则字段整体提交(cycle 0 = 服务端保持现规则;提交时全量带上)。
        cycle: cycle != null ? TemplateMapper.toPbCycle(cycle) : pb.TemplateCycle.CYCLE_UNSPECIFIED,
        cycleDays: cycleDays ?? 0,
        billingDay: billingDay ?? 0,
        interval: interval ?? 0,
        weekdayMask: weekdayMask ?? 0,
        monthlyMode: (monthlyMode ?? 0) == 1
            ? pbcommon.RecurrenceMonthlyMode.MONTHLY_MODE_BY_NTH_WEEKDAY
            : pbcommon.RecurrenceMonthlyMode.MONTHLY_MODE_BY_DATE,
        nth: nth ?? 0,
        endDate: endDate ?? '',
        autoRecord: autoRecord ?? false,
        version: Int64(version),
      ));
      return TemplateMapper.toDomain(res.template);
    });
  }

  Future<void> delete(String id) async {
    return _retry.call(() async {
      await _client.deleteTransactionTemplate(pb.DeleteTemplateRequest(id: id));
    });
  }

  Future<Template> pause(String id) async {
    return _retry.call(() async {
      final res = await _client.pauseTransactionTemplate(pb.PauseTemplateRequest(id: id));
      return TemplateMapper.toDomain(res.template);
    });
  }

  Future<Template> resume(String id) async {
    return _retry.call(() async {
      final res = await _client.resumeTransactionTemplate(pb.ResumeTemplateRequest(id: id));
      return TemplateMapper.toDomain(res.template);
    });
  }

  Future<Template> get(String id) async {
    return _retry.call(() async {
      final res = await _client.getTransactionTemplate(pb.GetTemplateRequest(id: id));
      return TemplateMapper.toDomain(res.template);
    });
  }

  Future<RecordResult> record(String templateId) async {
    return _retry.call(() async {
      final res = await _client.recordTransaction(pb.RecordTemplateRequest(templateId: templateId));
      return TemplateMapper.toRecordResult(res);
    });
  }
}
