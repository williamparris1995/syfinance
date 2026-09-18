import 'package:equatable/equatable.dart';

import 'package:yucai_client/template/domain/entities/template_entity.dart';

abstract class TemplateEvent extends Equatable {
  const TemplateEvent();
  @override
  List<Object?> get props => [];
}

class LoadTemplatesRequested extends TemplateEvent {}

class CreateTemplateRequested extends TemplateEvent {
  const CreateTemplateRequested({
    required this.name,
    required this.description,
    required this.amountCents,
    required this.direction,
    this.sourceAccountId,
    this.destinationAccountId,
    required this.cycle,
    required this.cycleDays,
    required this.billingDay,
    this.interval = 0,
    this.weekdayMask = 0,
    this.monthlyMode = 0,
    this.nth = 0,
    this.startDate,
    this.endDate,
    required this.autoRecord,
    this.category,
  });

  final String name;
  final String description;
  final int amountCents;
  final TemplateDirection direction;
  final String? sourceAccountId;
  final String? destinationAccountId;
  final TemplateCycle cycle;
  final int cycleDays;
  final int billingDay;
  final int interval;
  final int weekdayMask;
  final int monthlyMode;
  final int nth;
  final String? startDate;
  final String? endDate;
  final bool autoRecord;
  final String? category;

  @override
  List<Object?> get props => [
        name,
        description,
        amountCents,
        direction,
        sourceAccountId,
        destinationAccountId,
        cycle,
        cycleDays,
        billingDay,
        startDate,
        endDate,
        autoRecord,
        category,
      ];
}

class UpdateTemplateRequested extends TemplateEvent {
  const UpdateTemplateRequested({
    required this.id,
    required this.version,
    this.name,
    this.description,
    this.amountCents,
    this.cycle,
    this.cycleDays,
    this.billingDay,
    this.interval,
    this.weekdayMask,
    this.monthlyMode,
    this.nth,
    this.endDate,
    this.autoRecord,
  });

  final String id;
  final int version;
  final String? name;
  final String? description;
  final int? amountCents;
  final TemplateCycle? cycle;
  final int? cycleDays;
  final int? billingDay;
  final int? interval;
  final int? weekdayMask;
  final int? monthlyMode;
  final int? nth;
  final String? endDate;
  final bool? autoRecord;

  @override
  List<Object?> get props => [
        id,
        version,
        name,
        description,
        amountCents,
        cycle,
        cycleDays,
        billingDay,
        interval,
        weekdayMask,
        monthlyMode,
        nth,
        endDate,
        autoRecord,
      ];
}

class DeleteTemplateRequested extends TemplateEvent {
  const DeleteTemplateRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class PauseTemplateRequested extends TemplateEvent {
  const PauseTemplateRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class ResumeTemplateRequested extends TemplateEvent {
  const ResumeTemplateRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class RecordTemplateRequested extends TemplateEvent {
  const RecordTemplateRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}
