/// F43 财务报告页状态机(T5,ADR-1「bloc 只管期选择/触发生成/渲染」)。
///
/// seam:Event/State 公共 API;bloc 不持有时钟(>300ms 进度延迟判定在
/// 页面侧,见 financial_report_page._ProgressGate 注释——bloc 保持纯状态
/// 机,无需注入 clock 抽象)。
library;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/report/domain/report_assembly_service.dart';
import 'package:yucai_client/report/domain/report_document.dart';

// —— Event ——

abstract class FinancialReportEvent {
  const FinancialReportEvent();
}

/// 请求生成 [period] 报告期报告。
class GenerateRequested extends FinancialReportEvent {
  const GenerateRequested(this.period);
  final ReportPeriod period;
}

/// 错误态重试:重新生成同报告期(FR-8 scenario 3)。
///
/// 命名带 Requested 后缀(对齐本仓 LoadHoldingsRequested 等事件惯例):
/// 裸名 `Retry` 与 flutter_test 传递导出的 test_api `Retry` 撞名,消费方
/// 每次都要加前缀,故取全称。
class RetryRequested extends FinancialReportEvent {
  const RetryRequested();
}

// —— State ——

abstract class FinancialReportState extends Equatable {
  const FinancialReportState();
  @override
  List<Object?> get props => [];
}

class FinancialReportInitial extends FinancialReportState {}

/// 生成中:[phase] 四阶段之一(FR-8 进度契约),[period] 供 UI 回显。
class FinancialReportLoading extends FinancialReportState {
  const FinancialReportLoading(this.phase, this.period);
  final ReportPhase phase;
  final ReportPeriod period;

  @override
  List<Object?> get props => [phase, period];
}

class FinancialReportLoaded extends FinancialReportState {
  const FinancialReportLoaded(this.document);
  final ReportDocument document;

  @override
  List<Object?> get props => [document];
}

class FinancialReportError extends FinancialReportState {
  const FinancialReportError(this.message, this.period);
  final String message;
  final ReportPeriod period;

  @override
  List<Object?> get props => [message, period];
}

@injectable
class FinancialReportBloc
    extends Bloc<FinancialReportEvent, FinancialReportState> {
  FinancialReportBloc(this._assembly) : super(FinancialReportInitial()) {
    on<GenerateRequested>(_onGenerate);
    on<RetryRequested>(_onRetry);
  }

  final ReportAssemblyService _assembly;

  Future<void> _onGenerate(
    GenerateRequested event,
    Emitter<FinancialReportState> emit,
  ) async {
    await _generate(event.period, emit);
  }

  /// Retry 仅在 Error 态生效:取 Error 态携带的报告期重新生成同报告
  /// (FR-8 scenario 3);其他态收到该事件忽略(防误触重复生成)。
  Future<void> _onRetry(
    RetryRequested event,
    Emitter<FinancialReportState> emit,
  ) async {
    final current = state;
    if (current is FinancialReportError) {
      await _generate(current.period, emit);
    }
  }

  /// 统一生成流程:onPhase 回调在 generate await 窗口内同步发出,合法
  /// 使用 handler 的 emitter;任何异常 → 固定中文文案 Error(底层细节不
  /// 上抛 UI)。
  Future<void> _generate(
    ReportPeriod period,
    Emitter<FinancialReportState> emit,
  ) async {
    try {
      final document = await _assembly.generate(
        period,
        onPhase: (phase) => emit(FinancialReportLoading(phase, period)),
      );
      emit(FinancialReportLoaded(document));
    } catch (_) {
      emit(FinancialReportError('报告生成失败,请重试', period));
    }
  }
}
