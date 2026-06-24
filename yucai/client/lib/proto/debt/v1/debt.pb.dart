// This is a generated file - do not edit.
//
// Generated from debt/v1/debt.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $2;

import '../../common/v1/pagination.pb.dart' as $3;
import 'debt.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'debt.pbenum.dart';

class DebtDTO extends $pb.GeneratedMessage {
  factory DebtDTO({
    $core.String? id,
    $core.String? accountId,
    $core.String? counterparty,
    $core.double? interestRate,
    AmortizationMethod? amortizationMethod,
    $core.String? startDate,
    $core.String? dueDate,
    $fixnum.Int64? totalPrincipalCents,
    $fixnum.Int64? remainingPrincipalCents,
    $fixnum.Int64? version,
    $2.Timestamp? createdAt,
    $2.Timestamp? updatedAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (accountId != null) result.accountId = accountId;
    if (counterparty != null) result.counterparty = counterparty;
    if (interestRate != null) result.interestRate = interestRate;
    if (amortizationMethod != null)
      result.amortizationMethod = amortizationMethod;
    if (startDate != null) result.startDate = startDate;
    if (dueDate != null) result.dueDate = dueDate;
    if (totalPrincipalCents != null)
      result.totalPrincipalCents = totalPrincipalCents;
    if (remainingPrincipalCents != null)
      result.remainingPrincipalCents = remainingPrincipalCents;
    if (version != null) result.version = version;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  DebtDTO._();

  factory DebtDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DebtDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DebtDTO',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'accountId')
    ..aOS(3, _omitFieldNames ? '' : 'counterparty')
    ..aD(4, _omitFieldNames ? '' : 'interestRate')
    ..aE<AmortizationMethod>(5, _omitFieldNames ? '' : 'amortizationMethod',
        enumValues: AmortizationMethod.values)
    ..aOS(6, _omitFieldNames ? '' : 'startDate')
    ..aOS(7, _omitFieldNames ? '' : 'dueDate')
    ..aInt64(8, _omitFieldNames ? '' : 'totalPrincipalCents')
    ..aInt64(9, _omitFieldNames ? '' : 'remainingPrincipalCents')
    ..aInt64(10, _omitFieldNames ? '' : 'version')
    ..aOM<$2.Timestamp>(11, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(12, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DebtDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DebtDTO copyWith(void Function(DebtDTO) updates) =>
      super.copyWith((message) => updates(message as DebtDTO)) as DebtDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DebtDTO create() => DebtDTO._();
  @$core.override
  DebtDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DebtDTO getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DebtDTO>(create);
  static DebtDTO? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get accountId => $_getSZ(1);
  @$pb.TagNumber(2)
  set accountId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAccountId() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccountId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get counterparty => $_getSZ(2);
  @$pb.TagNumber(3)
  set counterparty($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCounterparty() => $_has(2);
  @$pb.TagNumber(3)
  void clearCounterparty() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get interestRate => $_getN(3);
  @$pb.TagNumber(4)
  set interestRate($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasInterestRate() => $_has(3);
  @$pb.TagNumber(4)
  void clearInterestRate() => $_clearField(4);

  @$pb.TagNumber(5)
  AmortizationMethod get amortizationMethod => $_getN(4);
  @$pb.TagNumber(5)
  set amortizationMethod(AmortizationMethod value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasAmortizationMethod() => $_has(4);
  @$pb.TagNumber(5)
  void clearAmortizationMethod() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get startDate => $_getSZ(5);
  @$pb.TagNumber(6)
  set startDate($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStartDate() => $_has(5);
  @$pb.TagNumber(6)
  void clearStartDate() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get dueDate => $_getSZ(6);
  @$pb.TagNumber(7)
  set dueDate($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDueDate() => $_has(6);
  @$pb.TagNumber(7)
  void clearDueDate() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get totalPrincipalCents => $_getI64(7);
  @$pb.TagNumber(8)
  set totalPrincipalCents($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTotalPrincipalCents() => $_has(7);
  @$pb.TagNumber(8)
  void clearTotalPrincipalCents() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get remainingPrincipalCents => $_getI64(8);
  @$pb.TagNumber(9)
  set remainingPrincipalCents($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasRemainingPrincipalCents() => $_has(8);
  @$pb.TagNumber(9)
  void clearRemainingPrincipalCents() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get version => $_getI64(9);
  @$pb.TagNumber(10)
  set version($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasVersion() => $_has(9);
  @$pb.TagNumber(10)
  void clearVersion() => $_clearField(10);

  @$pb.TagNumber(11)
  $2.Timestamp get createdAt => $_getN(10);
  @$pb.TagNumber(11)
  set createdAt($2.Timestamp value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasCreatedAt() => $_has(10);
  @$pb.TagNumber(11)
  void clearCreatedAt() => $_clearField(11);
  @$pb.TagNumber(11)
  $2.Timestamp ensureCreatedAt() => $_ensure(10);

  @$pb.TagNumber(12)
  $2.Timestamp get updatedAt => $_getN(11);
  @$pb.TagNumber(12)
  set updatedAt($2.Timestamp value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasUpdatedAt() => $_has(11);
  @$pb.TagNumber(12)
  void clearUpdatedAt() => $_clearField(12);
  @$pb.TagNumber(12)
  $2.Timestamp ensureUpdatedAt() => $_ensure(11);
}

class PaymentEntryDTO extends $pb.GeneratedMessage {
  factory PaymentEntryDTO({
    $core.String? id,
    $core.String? paymentDate,
    $fixnum.Int64? principalCents,
    $fixnum.Int64? interestCents,
    $fixnum.Int64? totalCents,
    $core.bool? paid,
    $fixnum.Int64? paidCents,
    $core.String? transactionId,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (paymentDate != null) result.paymentDate = paymentDate;
    if (principalCents != null) result.principalCents = principalCents;
    if (interestCents != null) result.interestCents = interestCents;
    if (totalCents != null) result.totalCents = totalCents;
    if (paid != null) result.paid = paid;
    if (paidCents != null) result.paidCents = paidCents;
    if (transactionId != null) result.transactionId = transactionId;
    return result;
  }

  PaymentEntryDTO._();

  factory PaymentEntryDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PaymentEntryDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PaymentEntryDTO',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'paymentDate')
    ..aInt64(3, _omitFieldNames ? '' : 'principalCents')
    ..aInt64(4, _omitFieldNames ? '' : 'interestCents')
    ..aInt64(5, _omitFieldNames ? '' : 'totalCents')
    ..aOB(6, _omitFieldNames ? '' : 'paid')
    ..aInt64(7, _omitFieldNames ? '' : 'paidCents')
    ..aOS(8, _omitFieldNames ? '' : 'transactionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaymentEntryDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaymentEntryDTO copyWith(void Function(PaymentEntryDTO) updates) =>
      super.copyWith((message) => updates(message as PaymentEntryDTO))
          as PaymentEntryDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaymentEntryDTO create() => PaymentEntryDTO._();
  @$core.override
  PaymentEntryDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PaymentEntryDTO getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PaymentEntryDTO>(create);
  static PaymentEntryDTO? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get paymentDate => $_getSZ(1);
  @$pb.TagNumber(2)
  set paymentDate($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPaymentDate() => $_has(1);
  @$pb.TagNumber(2)
  void clearPaymentDate() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get principalCents => $_getI64(2);
  @$pb.TagNumber(3)
  set principalCents($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPrincipalCents() => $_has(2);
  @$pb.TagNumber(3)
  void clearPrincipalCents() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get interestCents => $_getI64(3);
  @$pb.TagNumber(4)
  set interestCents($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasInterestCents() => $_has(3);
  @$pb.TagNumber(4)
  void clearInterestCents() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get totalCents => $_getI64(4);
  @$pb.TagNumber(5)
  set totalCents($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTotalCents() => $_has(4);
  @$pb.TagNumber(5)
  void clearTotalCents() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get paid => $_getBF(5);
  @$pb.TagNumber(6)
  set paid($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPaid() => $_has(5);
  @$pb.TagNumber(6)
  void clearPaid() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get paidCents => $_getI64(6);
  @$pb.TagNumber(7)
  set paidCents($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPaidCents() => $_has(6);
  @$pb.TagNumber(7)
  void clearPaidCents() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get transactionId => $_getSZ(7);
  @$pb.TagNumber(8)
  set transactionId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTransactionId() => $_has(7);
  @$pb.TagNumber(8)
  void clearTransactionId() => $_clearField(8);
}

class DebtDetailDTO extends $pb.GeneratedMessage {
  factory DebtDetailDTO({
    DebtDTO? debt,
    $core.Iterable<PaymentEntryDTO>? schedule,
  }) {
    final result = create();
    if (debt != null) result.debt = debt;
    if (schedule != null) result.schedule.addAll(schedule);
    return result;
  }

  DebtDetailDTO._();

  factory DebtDetailDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DebtDetailDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DebtDetailDTO',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..aOM<DebtDTO>(1, _omitFieldNames ? '' : 'debt', subBuilder: DebtDTO.create)
    ..pPM<PaymentEntryDTO>(2, _omitFieldNames ? '' : 'schedule',
        subBuilder: PaymentEntryDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DebtDetailDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DebtDetailDTO copyWith(void Function(DebtDetailDTO) updates) =>
      super.copyWith((message) => updates(message as DebtDetailDTO))
          as DebtDetailDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DebtDetailDTO create() => DebtDetailDTO._();
  @$core.override
  DebtDetailDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DebtDetailDTO getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DebtDetailDTO>(create);
  static DebtDetailDTO? _defaultInstance;

  @$pb.TagNumber(1)
  DebtDTO get debt => $_getN(0);
  @$pb.TagNumber(1)
  set debt(DebtDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasDebt() => $_has(0);
  @$pb.TagNumber(1)
  void clearDebt() => $_clearField(1);
  @$pb.TagNumber(1)
  DebtDTO ensureDebt() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<PaymentEntryDTO> get schedule => $_getList(1);
}

class CreateDebtRequest extends $pb.GeneratedMessage {
  factory CreateDebtRequest({
    $core.String? accountId,
    $core.String? counterparty,
    $core.double? interestRate,
    AmortizationMethod? amortizationMethod,
    $core.String? startDate,
    $core.String? dueDate,
    $fixnum.Int64? totalPrincipalCents,
  }) {
    final result = create();
    if (accountId != null) result.accountId = accountId;
    if (counterparty != null) result.counterparty = counterparty;
    if (interestRate != null) result.interestRate = interestRate;
    if (amortizationMethod != null)
      result.amortizationMethod = amortizationMethod;
    if (startDate != null) result.startDate = startDate;
    if (dueDate != null) result.dueDate = dueDate;
    if (totalPrincipalCents != null)
      result.totalPrincipalCents = totalPrincipalCents;
    return result;
  }

  CreateDebtRequest._();

  factory CreateDebtRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateDebtRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateDebtRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'accountId')
    ..aOS(2, _omitFieldNames ? '' : 'counterparty')
    ..aD(3, _omitFieldNames ? '' : 'interestRate')
    ..aE<AmortizationMethod>(4, _omitFieldNames ? '' : 'amortizationMethod',
        enumValues: AmortizationMethod.values)
    ..aOS(5, _omitFieldNames ? '' : 'startDate')
    ..aOS(6, _omitFieldNames ? '' : 'dueDate')
    ..aInt64(7, _omitFieldNames ? '' : 'totalPrincipalCents')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateDebtRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateDebtRequest copyWith(void Function(CreateDebtRequest) updates) =>
      super.copyWith((message) => updates(message as CreateDebtRequest))
          as CreateDebtRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateDebtRequest create() => CreateDebtRequest._();
  @$core.override
  CreateDebtRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateDebtRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateDebtRequest>(create);
  static CreateDebtRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get accountId => $_getSZ(0);
  @$pb.TagNumber(1)
  set accountId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccountId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccountId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get counterparty => $_getSZ(1);
  @$pb.TagNumber(2)
  set counterparty($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCounterparty() => $_has(1);
  @$pb.TagNumber(2)
  void clearCounterparty() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get interestRate => $_getN(2);
  @$pb.TagNumber(3)
  set interestRate($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasInterestRate() => $_has(2);
  @$pb.TagNumber(3)
  void clearInterestRate() => $_clearField(3);

  @$pb.TagNumber(4)
  AmortizationMethod get amortizationMethod => $_getN(3);
  @$pb.TagNumber(4)
  set amortizationMethod(AmortizationMethod value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasAmortizationMethod() => $_has(3);
  @$pb.TagNumber(4)
  void clearAmortizationMethod() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get startDate => $_getSZ(4);
  @$pb.TagNumber(5)
  set startDate($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStartDate() => $_has(4);
  @$pb.TagNumber(5)
  void clearStartDate() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get dueDate => $_getSZ(5);
  @$pb.TagNumber(6)
  set dueDate($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDueDate() => $_has(5);
  @$pb.TagNumber(6)
  void clearDueDate() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get totalPrincipalCents => $_getI64(6);
  @$pb.TagNumber(7)
  set totalPrincipalCents($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTotalPrincipalCents() => $_has(6);
  @$pb.TagNumber(7)
  void clearTotalPrincipalCents() => $_clearField(7);
}

class UpdateDebtRequest extends $pb.GeneratedMessage {
  factory UpdateDebtRequest({
    $core.String? id,
    $core.String? counterparty,
    $core.double? interestRate,
    $fixnum.Int64? version,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (counterparty != null) result.counterparty = counterparty;
    if (interestRate != null) result.interestRate = interestRate;
    if (version != null) result.version = version;
    return result;
  }

  UpdateDebtRequest._();

  factory UpdateDebtRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateDebtRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateDebtRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'counterparty')
    ..aD(3, _omitFieldNames ? '' : 'interestRate')
    ..aInt64(4, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateDebtRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateDebtRequest copyWith(void Function(UpdateDebtRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateDebtRequest))
          as UpdateDebtRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateDebtRequest create() => UpdateDebtRequest._();
  @$core.override
  UpdateDebtRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateDebtRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateDebtRequest>(create);
  static UpdateDebtRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get counterparty => $_getSZ(1);
  @$pb.TagNumber(2)
  set counterparty($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCounterparty() => $_has(1);
  @$pb.TagNumber(2)
  void clearCounterparty() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get interestRate => $_getN(2);
  @$pb.TagNumber(3)
  set interestRate($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasInterestRate() => $_has(2);
  @$pb.TagNumber(3)
  void clearInterestRate() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get version => $_getI64(3);
  @$pb.TagNumber(4)
  set version($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearVersion() => $_clearField(4);
}

class DeleteDebtRequest extends $pb.GeneratedMessage {
  factory DeleteDebtRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteDebtRequest._();

  factory DeleteDebtRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteDebtRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteDebtRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteDebtRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteDebtRequest copyWith(void Function(DeleteDebtRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteDebtRequest))
          as DeleteDebtRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteDebtRequest create() => DeleteDebtRequest._();
  @$core.override
  DeleteDebtRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteDebtRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteDebtRequest>(create);
  static DeleteDebtRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class RecordPaymentRequest extends $pb.GeneratedMessage {
  factory RecordPaymentRequest({
    $core.String? debtId,
    $core.String? scheduleEntryId,
    $core.String? fromAccountId,
  }) {
    final result = create();
    if (debtId != null) result.debtId = debtId;
    if (scheduleEntryId != null) result.scheduleEntryId = scheduleEntryId;
    if (fromAccountId != null) result.fromAccountId = fromAccountId;
    return result;
  }

  RecordPaymentRequest._();

  factory RecordPaymentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecordPaymentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecordPaymentRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'debtId')
    ..aOS(2, _omitFieldNames ? '' : 'scheduleEntryId')
    ..aOS(3, _omitFieldNames ? '' : 'fromAccountId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordPaymentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordPaymentRequest copyWith(void Function(RecordPaymentRequest) updates) =>
      super.copyWith((message) => updates(message as RecordPaymentRequest))
          as RecordPaymentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecordPaymentRequest create() => RecordPaymentRequest._();
  @$core.override
  RecordPaymentRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecordPaymentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecordPaymentRequest>(create);
  static RecordPaymentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get debtId => $_getSZ(0);
  @$pb.TagNumber(1)
  set debtId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDebtId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDebtId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get scheduleEntryId => $_getSZ(1);
  @$pb.TagNumber(2)
  set scheduleEntryId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasScheduleEntryId() => $_has(1);
  @$pb.TagNumber(2)
  void clearScheduleEntryId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get fromAccountId => $_getSZ(2);
  @$pb.TagNumber(3)
  set fromAccountId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFromAccountId() => $_has(2);
  @$pb.TagNumber(3)
  void clearFromAccountId() => $_clearField(3);
}

class RecordPaymentResponse extends $pb.GeneratedMessage {
  factory RecordPaymentResponse({
    $core.String? transactionId,
    PaymentEntryDTO? entry,
  }) {
    final result = create();
    if (transactionId != null) result.transactionId = transactionId;
    if (entry != null) result.entry = entry;
    return result;
  }

  RecordPaymentResponse._();

  factory RecordPaymentResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecordPaymentResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecordPaymentResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'transactionId')
    ..aOM<PaymentEntryDTO>(2, _omitFieldNames ? '' : 'entry',
        subBuilder: PaymentEntryDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordPaymentResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordPaymentResponse copyWith(
          void Function(RecordPaymentResponse) updates) =>
      super.copyWith((message) => updates(message as RecordPaymentResponse))
          as RecordPaymentResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecordPaymentResponse create() => RecordPaymentResponse._();
  @$core.override
  RecordPaymentResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecordPaymentResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecordPaymentResponse>(create);
  static RecordPaymentResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transactionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transactionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransactionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransactionId() => $_clearField(1);

  @$pb.TagNumber(2)
  PaymentEntryDTO get entry => $_getN(1);
  @$pb.TagNumber(2)
  set entry(PaymentEntryDTO value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasEntry() => $_has(1);
  @$pb.TagNumber(2)
  void clearEntry() => $_clearField(2);
  @$pb.TagNumber(2)
  PaymentEntryDTO ensureEntry() => $_ensure(1);
}

class GetDebtRequest extends $pb.GeneratedMessage {
  factory GetDebtRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  GetDebtRequest._();

  factory GetDebtRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetDebtRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetDebtRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetDebtRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetDebtRequest copyWith(void Function(GetDebtRequest) updates) =>
      super.copyWith((message) => updates(message as GetDebtRequest))
          as GetDebtRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetDebtRequest create() => GetDebtRequest._();
  @$core.override
  GetDebtRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetDebtRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetDebtRequest>(create);
  static GetDebtRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class ListDebtsRequest extends $pb.GeneratedMessage {
  factory ListDebtsRequest({
    $3.PageRequest? page,
  }) {
    final result = create();
    if (page != null) result.page = page;
    return result;
  }

  ListDebtsRequest._();

  factory ListDebtsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListDebtsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListDebtsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..aOM<$3.PageRequest>(1, _omitFieldNames ? '' : 'page',
        subBuilder: $3.PageRequest.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDebtsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDebtsRequest copyWith(void Function(ListDebtsRequest) updates) =>
      super.copyWith((message) => updates(message as ListDebtsRequest))
          as ListDebtsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListDebtsRequest create() => ListDebtsRequest._();
  @$core.override
  ListDebtsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListDebtsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListDebtsRequest>(create);
  static ListDebtsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $3.PageRequest get page => $_getN(0);
  @$pb.TagNumber(1)
  set page($3.PageRequest value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPage() => $_has(0);
  @$pb.TagNumber(1)
  void clearPage() => $_clearField(1);
  @$pb.TagNumber(1)
  $3.PageRequest ensurePage() => $_ensure(0);
}

class ListDebtsResponse extends $pb.GeneratedMessage {
  factory ListDebtsResponse({
    $core.Iterable<DebtDTO>? debts,
    $3.PageResponse? page,
  }) {
    final result = create();
    if (debts != null) result.debts.addAll(debts);
    if (page != null) result.page = page;
    return result;
  }

  ListDebtsResponse._();

  factory ListDebtsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListDebtsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListDebtsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..pPM<DebtDTO>(1, _omitFieldNames ? '' : 'debts',
        subBuilder: DebtDTO.create)
    ..aOM<$3.PageResponse>(2, _omitFieldNames ? '' : 'page',
        subBuilder: $3.PageResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDebtsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDebtsResponse copyWith(void Function(ListDebtsResponse) updates) =>
      super.copyWith((message) => updates(message as ListDebtsResponse))
          as ListDebtsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListDebtsResponse create() => ListDebtsResponse._();
  @$core.override
  ListDebtsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListDebtsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListDebtsResponse>(create);
  static ListDebtsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<DebtDTO> get debts => $_getList(0);

  @$pb.TagNumber(2)
  $3.PageResponse get page => $_getN(1);
  @$pb.TagNumber(2)
  set page($3.PageResponse value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPage() => $_has(1);
  @$pb.TagNumber(2)
  void clearPage() => $_clearField(2);
  @$pb.TagNumber(2)
  $3.PageResponse ensurePage() => $_ensure(1);
}

class GetUpcomingPaymentsRequest extends $pb.GeneratedMessage {
  factory GetUpcomingPaymentsRequest({
    $core.int? daysAhead,
  }) {
    final result = create();
    if (daysAhead != null) result.daysAhead = daysAhead;
    return result;
  }

  GetUpcomingPaymentsRequest._();

  factory GetUpcomingPaymentsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetUpcomingPaymentsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetUpcomingPaymentsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'daysAhead')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetUpcomingPaymentsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetUpcomingPaymentsRequest copyWith(
          void Function(GetUpcomingPaymentsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetUpcomingPaymentsRequest))
          as GetUpcomingPaymentsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetUpcomingPaymentsRequest create() => GetUpcomingPaymentsRequest._();
  @$core.override
  GetUpcomingPaymentsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetUpcomingPaymentsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetUpcomingPaymentsRequest>(create);
  static GetUpcomingPaymentsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get daysAhead => $_getIZ(0);
  @$pb.TagNumber(1)
  set daysAhead($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDaysAhead() => $_has(0);
  @$pb.TagNumber(1)
  void clearDaysAhead() => $_clearField(1);
}

class DebtResponse extends $pb.GeneratedMessage {
  factory DebtResponse({
    DebtDTO? debt,
  }) {
    final result = create();
    if (debt != null) result.debt = debt;
    return result;
  }

  DebtResponse._();

  factory DebtResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DebtResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DebtResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..aOM<DebtDTO>(1, _omitFieldNames ? '' : 'debt', subBuilder: DebtDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DebtResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DebtResponse copyWith(void Function(DebtResponse) updates) =>
      super.copyWith((message) => updates(message as DebtResponse))
          as DebtResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DebtResponse create() => DebtResponse._();
  @$core.override
  DebtResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DebtResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DebtResponse>(create);
  static DebtResponse? _defaultInstance;

  @$pb.TagNumber(1)
  DebtDTO get debt => $_getN(0);
  @$pb.TagNumber(1)
  set debt(DebtDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasDebt() => $_has(0);
  @$pb.TagNumber(1)
  void clearDebt() => $_clearField(1);
  @$pb.TagNumber(1)
  DebtDTO ensureDebt() => $_ensure(0);
}

class DebtDetailResponse extends $pb.GeneratedMessage {
  factory DebtDetailResponse({
    DebtDetailDTO? debt,
  }) {
    final result = create();
    if (debt != null) result.debt = debt;
    return result;
  }

  DebtDetailResponse._();

  factory DebtDetailResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DebtDetailResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DebtDetailResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..aOM<DebtDetailDTO>(1, _omitFieldNames ? '' : 'debt',
        subBuilder: DebtDetailDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DebtDetailResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DebtDetailResponse copyWith(void Function(DebtDetailResponse) updates) =>
      super.copyWith((message) => updates(message as DebtDetailResponse))
          as DebtDetailResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DebtDetailResponse create() => DebtDetailResponse._();
  @$core.override
  DebtDetailResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DebtDetailResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DebtDetailResponse>(create);
  static DebtDetailResponse? _defaultInstance;

  @$pb.TagNumber(1)
  DebtDetailDTO get debt => $_getN(0);
  @$pb.TagNumber(1)
  set debt(DebtDetailDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasDebt() => $_has(0);
  @$pb.TagNumber(1)
  void clearDebt() => $_clearField(1);
  @$pb.TagNumber(1)
  DebtDetailDTO ensureDebt() => $_ensure(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
