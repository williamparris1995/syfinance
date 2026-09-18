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
import '../../common/v1/recurrence.pbenum.dart' as $4;
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
    DebtType? debtType,
    $core.String? subtype,
    $core.String? contact,
    $core.String? contractRef,
    $core.String? collectionAccountId,
    $core.String? nextPaymentDate,
    $fixnum.Int64? nextPaymentAmountCents,
    $core.int? nextPaymentPeriodNo,
    $fixnum.Int64? remainingTrendCents,
    $4.RecurrenceCycle? cycle,
    $core.int? interval,
    $core.int? weekdayMask,
    $4.RecurrenceMonthlyMode? monthlyMode,
    $core.int? nth,
    $core.String? guarantorName,
    $core.String? guarantorContact,
    $fixnum.Int64? interestWaivedCents,
    $fixnum.Int64? remainingInterestCents,
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
    if (debtType != null) result.debtType = debtType;
    if (subtype != null) result.subtype = subtype;
    if (contact != null) result.contact = contact;
    if (contractRef != null) result.contractRef = contractRef;
    if (collectionAccountId != null)
      result.collectionAccountId = collectionAccountId;
    if (nextPaymentDate != null) result.nextPaymentDate = nextPaymentDate;
    if (nextPaymentAmountCents != null)
      result.nextPaymentAmountCents = nextPaymentAmountCents;
    if (nextPaymentPeriodNo != null)
      result.nextPaymentPeriodNo = nextPaymentPeriodNo;
    if (remainingTrendCents != null)
      result.remainingTrendCents = remainingTrendCents;
    if (cycle != null) result.cycle = cycle;
    if (interval != null) result.interval = interval;
    if (weekdayMask != null) result.weekdayMask = weekdayMask;
    if (monthlyMode != null) result.monthlyMode = monthlyMode;
    if (nth != null) result.nth = nth;
    if (guarantorName != null) result.guarantorName = guarantorName;
    if (guarantorContact != null) result.guarantorContact = guarantorContact;
    if (interestWaivedCents != null)
      result.interestWaivedCents = interestWaivedCents;
    if (remainingInterestCents != null)
      result.remainingInterestCents = remainingInterestCents;
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
    ..aE<DebtType>(13, _omitFieldNames ? '' : 'debtType',
        enumValues: DebtType.values)
    ..aOS(14, _omitFieldNames ? '' : 'subtype')
    ..aOS(15, _omitFieldNames ? '' : 'contact')
    ..aOS(16, _omitFieldNames ? '' : 'contractRef')
    ..aOS(17, _omitFieldNames ? '' : 'collectionAccountId')
    ..aOS(18, _omitFieldNames ? '' : 'nextPaymentDate')
    ..aInt64(19, _omitFieldNames ? '' : 'nextPaymentAmountCents')
    ..aI(20, _omitFieldNames ? '' : 'nextPaymentPeriodNo')
    ..aInt64(21, _omitFieldNames ? '' : 'remainingTrendCents')
    ..aE<$4.RecurrenceCycle>(22, _omitFieldNames ? '' : 'cycle',
        enumValues: $4.RecurrenceCycle.values)
    ..aI(23, _omitFieldNames ? '' : 'interval')
    ..aI(24, _omitFieldNames ? '' : 'weekdayMask')
    ..aE<$4.RecurrenceMonthlyMode>(25, _omitFieldNames ? '' : 'monthlyMode',
        enumValues: $4.RecurrenceMonthlyMode.values)
    ..aI(26, _omitFieldNames ? '' : 'nth')
    ..aOS(27, _omitFieldNames ? '' : 'guarantorName')
    ..aOS(28, _omitFieldNames ? '' : 'guarantorContact')
    ..aInt64(29, _omitFieldNames ? '' : 'interestWaivedCents')
    ..aInt64(30, _omitFieldNames ? '' : 'remainingInterestCents')
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

  @$pb.TagNumber(13)
  DebtType get debtType => $_getN(12);
  @$pb.TagNumber(13)
  set debtType(DebtType value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasDebtType() => $_has(12);
  @$pb.TagNumber(13)
  void clearDebtType() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get subtype => $_getSZ(13);
  @$pb.TagNumber(14)
  set subtype($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasSubtype() => $_has(13);
  @$pb.TagNumber(14)
  void clearSubtype() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get contact => $_getSZ(14);
  @$pb.TagNumber(15)
  set contact($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasContact() => $_has(14);
  @$pb.TagNumber(15)
  void clearContact() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.String get contractRef => $_getSZ(15);
  @$pb.TagNumber(16)
  set contractRef($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasContractRef() => $_has(15);
  @$pb.TagNumber(16)
  void clearContractRef() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.String get collectionAccountId => $_getSZ(16);
  @$pb.TagNumber(17)
  set collectionAccountId($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasCollectionAccountId() => $_has(16);
  @$pb.TagNumber(17)
  void clearCollectionAccountId() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.String get nextPaymentDate => $_getSZ(17);
  @$pb.TagNumber(18)
  set nextPaymentDate($core.String value) => $_setString(17, value);
  @$pb.TagNumber(18)
  $core.bool hasNextPaymentDate() => $_has(17);
  @$pb.TagNumber(18)
  void clearNextPaymentDate() => $_clearField(18);

  @$pb.TagNumber(19)
  $fixnum.Int64 get nextPaymentAmountCents => $_getI64(18);
  @$pb.TagNumber(19)
  set nextPaymentAmountCents($fixnum.Int64 value) => $_setInt64(18, value);
  @$pb.TagNumber(19)
  $core.bool hasNextPaymentAmountCents() => $_has(18);
  @$pb.TagNumber(19)
  void clearNextPaymentAmountCents() => $_clearField(19);

  @$pb.TagNumber(20)
  $core.int get nextPaymentPeriodNo => $_getIZ(19);
  @$pb.TagNumber(20)
  set nextPaymentPeriodNo($core.int value) => $_setSignedInt32(19, value);
  @$pb.TagNumber(20)
  $core.bool hasNextPaymentPeriodNo() => $_has(19);
  @$pb.TagNumber(20)
  void clearNextPaymentPeriodNo() => $_clearField(20);

  @$pb.TagNumber(21)
  $fixnum.Int64 get remainingTrendCents => $_getI64(20);
  @$pb.TagNumber(21)
  set remainingTrendCents($fixnum.Int64 value) => $_setInt64(20, value);
  @$pb.TagNumber(21)
  $core.bool hasRemainingTrendCents() => $_has(20);
  @$pb.TagNumber(21)
  void clearRemainingTrendCents() => $_clearField(21);

  /// Recurrence rule (zero values = legacy monthly). billing_day is not
  /// used by debt: by-date months anchor the start date.
  @$pb.TagNumber(22)
  $4.RecurrenceCycle get cycle => $_getN(21);
  @$pb.TagNumber(22)
  set cycle($4.RecurrenceCycle value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasCycle() => $_has(21);
  @$pb.TagNumber(22)
  void clearCycle() => $_clearField(22);

  @$pb.TagNumber(23)
  $core.int get interval => $_getIZ(22);
  @$pb.TagNumber(23)
  set interval($core.int value) => $_setSignedInt32(22, value);
  @$pb.TagNumber(23)
  $core.bool hasInterval() => $_has(22);
  @$pb.TagNumber(23)
  void clearInterval() => $_clearField(23);

  @$pb.TagNumber(24)
  $core.int get weekdayMask => $_getIZ(23);
  @$pb.TagNumber(24)
  set weekdayMask($core.int value) => $_setSignedInt32(23, value);
  @$pb.TagNumber(24)
  $core.bool hasWeekdayMask() => $_has(23);
  @$pb.TagNumber(24)
  void clearWeekdayMask() => $_clearField(24);

  @$pb.TagNumber(25)
  $4.RecurrenceMonthlyMode get monthlyMode => $_getN(24);
  @$pb.TagNumber(25)
  set monthlyMode($4.RecurrenceMonthlyMode value) => $_setField(25, value);
  @$pb.TagNumber(25)
  $core.bool hasMonthlyMode() => $_has(24);
  @$pb.TagNumber(25)
  void clearMonthlyMode() => $_clearField(25);

  @$pb.TagNumber(26)
  $core.int get nth => $_getIZ(25);
  @$pb.TagNumber(26)
  set nth($core.int value) => $_setSignedInt32(25, value);
  @$pb.TagNumber(26)
  $core.bool hasNth() => $_has(25);
  @$pb.TagNumber(26)
  void clearNth() => $_clearField(26);

  /// Guarantor (2026-09 user request; both directions, optional free text).
  /// Field numbers 27/28 allocated after the recurrence block (22-26).
  @$pb.TagNumber(27)
  $core.String get guarantorName => $_getSZ(26);
  @$pb.TagNumber(27)
  set guarantorName($core.String value) => $_setString(26, value);
  @$pb.TagNumber(27)
  $core.bool hasGuarantorName() => $_has(26);
  @$pb.TagNumber(27)
  void clearGuarantorName() => $_clearField(27);

  @$pb.TagNumber(28)
  $core.String get guarantorContact => $_getSZ(27);
  @$pb.TagNumber(28)
  set guarantorContact($core.String value) => $_setString(27, value);
  @$pb.TagNumber(28)
  $core.bool hasGuarantorContact() => $_has(27);
  @$pb.TagNumber(28)
  void clearGuarantorContact() => $_clearField(28);

  /// One-off interest waiver (cents), deducted from the earliest installments'
  /// interest at schedule generation; 0 = none.
  @$pb.TagNumber(29)
  $fixnum.Int64 get interestWaivedCents => $_getI64(28);
  @$pb.TagNumber(29)
  set interestWaivedCents($fixnum.Int64 value) => $_setInt64(28, value);
  @$pb.TagNumber(29)
  $core.bool hasInterestWaivedCents() => $_has(28);
  @$pb.TagNumber(29)
  void clearInterestWaivedCents() => $_clearField(29);

  /// Σ unpaid schedule interest (本息口径统计用).
  @$pb.TagNumber(30)
  $fixnum.Int64 get remainingInterestCents => $_getI64(29);
  @$pb.TagNumber(30)
  set remainingInterestCents($fixnum.Int64 value) => $_setInt64(29, value);
  @$pb.TagNumber(30)
  $core.bool hasRemainingInterestCents() => $_has(29);
  @$pb.TagNumber(30)
  void clearRemainingInterestCents() => $_clearField(30);
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
    DebtType? debtType,
    $core.String? subtype,
    $core.String? sourceAccountId,
    $core.String? contact,
    $core.String? contractRef,
    $core.String? collectionAccountId,
    $4.RecurrenceCycle? cycle,
    $core.int? interval,
    $core.int? weekdayMask,
    $4.RecurrenceMonthlyMode? monthlyMode,
    $core.int? nth,
    $core.int? termPeriods,
    $core.String? guarantorName,
    $core.String? guarantorContact,
    $fixnum.Int64? interestWaivedCents,
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
    if (debtType != null) result.debtType = debtType;
    if (subtype != null) result.subtype = subtype;
    if (sourceAccountId != null) result.sourceAccountId = sourceAccountId;
    if (contact != null) result.contact = contact;
    if (contractRef != null) result.contractRef = contractRef;
    if (collectionAccountId != null)
      result.collectionAccountId = collectionAccountId;
    if (cycle != null) result.cycle = cycle;
    if (interval != null) result.interval = interval;
    if (weekdayMask != null) result.weekdayMask = weekdayMask;
    if (monthlyMode != null) result.monthlyMode = monthlyMode;
    if (nth != null) result.nth = nth;
    if (termPeriods != null) result.termPeriods = termPeriods;
    if (guarantorName != null) result.guarantorName = guarantorName;
    if (guarantorContact != null) result.guarantorContact = guarantorContact;
    if (interestWaivedCents != null)
      result.interestWaivedCents = interestWaivedCents;
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
    ..aE<DebtType>(8, _omitFieldNames ? '' : 'debtType',
        enumValues: DebtType.values)
    ..aOS(9, _omitFieldNames ? '' : 'subtype')
    ..aOS(10, _omitFieldNames ? '' : 'sourceAccountId')
    ..aOS(11, _omitFieldNames ? '' : 'contact')
    ..aOS(12, _omitFieldNames ? '' : 'contractRef')
    ..aOS(13, _omitFieldNames ? '' : 'collectionAccountId')
    ..aE<$4.RecurrenceCycle>(14, _omitFieldNames ? '' : 'cycle',
        enumValues: $4.RecurrenceCycle.values)
    ..aI(15, _omitFieldNames ? '' : 'interval')
    ..aI(16, _omitFieldNames ? '' : 'weekdayMask')
    ..aE<$4.RecurrenceMonthlyMode>(17, _omitFieldNames ? '' : 'monthlyMode',
        enumValues: $4.RecurrenceMonthlyMode.values)
    ..aI(18, _omitFieldNames ? '' : 'nth')
    ..aI(19, _omitFieldNames ? '' : 'termPeriods')
    ..aOS(20, _omitFieldNames ? '' : 'guarantorName')
    ..aOS(21, _omitFieldNames ? '' : 'guarantorContact')
    ..aInt64(22, _omitFieldNames ? '' : 'interestWaivedCents')
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

  @$pb.TagNumber(8)
  DebtType get debtType => $_getN(7);
  @$pb.TagNumber(8)
  set debtType(DebtType value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasDebtType() => $_has(7);
  @$pb.TagNumber(8)
  void clearDebtType() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get subtype => $_getSZ(8);
  @$pb.TagNumber(9)
  set subtype($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSubtype() => $_has(8);
  @$pb.TagNumber(9)
  void clearSubtype() => $_clearField(9);

  /// borrowedOut 双写:借出资金的来源账户(cash asset)。borrowedOut 必填;
  /// borrowedIn 忽略(不双写)。空字符串 = 不双写。
  @$pb.TagNumber(10)
  $core.String get sourceAccountId => $_getSZ(9);
  @$pb.TagNumber(10)
  set sourceAccountId($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSourceAccountId() => $_has(9);
  @$pb.TagNumber(10)
  void clearSourceAccountId() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get contact => $_getSZ(10);
  @$pb.TagNumber(11)
  set contact($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasContact() => $_has(10);
  @$pb.TagNumber(11)
  void clearContact() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get contractRef => $_getSZ(11);
  @$pb.TagNumber(12)
  set contractRef($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasContractRef() => $_has(11);
  @$pb.TagNumber(12)
  void clearContractRef() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get collectionAccountId => $_getSZ(12);
  @$pb.TagNumber(13)
  set collectionAccountId($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasCollectionAccountId() => $_has(12);
  @$pb.TagNumber(13)
  void clearCollectionAccountId() => $_clearField(13);

  /// Recurrence rule (zero values = legacy monthly; ignored by lump_sum).
  @$pb.TagNumber(14)
  $4.RecurrenceCycle get cycle => $_getN(13);
  @$pb.TagNumber(14)
  set cycle($4.RecurrenceCycle value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasCycle() => $_has(13);
  @$pb.TagNumber(14)
  void clearCycle() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.int get interval => $_getIZ(14);
  @$pb.TagNumber(15)
  set interval($core.int value) => $_setSignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasInterval() => $_has(14);
  @$pb.TagNumber(15)
  void clearInterval() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.int get weekdayMask => $_getIZ(15);
  @$pb.TagNumber(16)
  set weekdayMask($core.int value) => $_setSignedInt32(15, value);
  @$pb.TagNumber(16)
  $core.bool hasWeekdayMask() => $_has(15);
  @$pb.TagNumber(16)
  void clearWeekdayMask() => $_clearField(16);

  @$pb.TagNumber(17)
  $4.RecurrenceMonthlyMode get monthlyMode => $_getN(16);
  @$pb.TagNumber(17)
  set monthlyMode($4.RecurrenceMonthlyMode value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasMonthlyMode() => $_has(16);
  @$pb.TagNumber(17)
  void clearMonthlyMode() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.int get nth => $_getIZ(17);
  @$pb.TagNumber(18)
  set nth($core.int value) => $_setSignedInt32(17, value);
  @$pb.TagNumber(18)
  $core.bool hasNth() => $_has(17);
  @$pb.TagNumber(18)
  void clearNth() => $_clearField(18);

  /// Term input dual mode: >0 = by periods (N periods, due_date derived);
  /// ==0 = by due date (default; period count derived from rule + dates).
  @$pb.TagNumber(19)
  $core.int get termPeriods => $_getIZ(18);
  @$pb.TagNumber(19)
  set termPeriods($core.int value) => $_setSignedInt32(18, value);
  @$pb.TagNumber(19)
  $core.bool hasTermPeriods() => $_has(18);
  @$pb.TagNumber(19)
  void clearTermPeriods() => $_clearField(19);

  /// Guarantor (optional; empty = none). Numbers after recurrence 14-19.
  @$pb.TagNumber(20)
  $core.String get guarantorName => $_getSZ(19);
  @$pb.TagNumber(20)
  set guarantorName($core.String value) => $_setString(19, value);
  @$pb.TagNumber(20)
  $core.bool hasGuarantorName() => $_has(19);
  @$pb.TagNumber(20)
  void clearGuarantorName() => $_clearField(20);

  @$pb.TagNumber(21)
  $core.String get guarantorContact => $_getSZ(20);
  @$pb.TagNumber(21)
  set guarantorContact($core.String value) => $_setString(20, value);
  @$pb.TagNumber(21)
  $core.bool hasGuarantorContact() => $_has(20);
  @$pb.TagNumber(21)
  void clearGuarantorContact() => $_clearField(21);

  /// One-off interest waiver (cents); must not exceed total interest.
  @$pb.TagNumber(22)
  $fixnum.Int64 get interestWaivedCents => $_getI64(21);
  @$pb.TagNumber(22)
  set interestWaivedCents($fixnum.Int64 value) => $_setInt64(21, value);
  @$pb.TagNumber(22)
  $core.bool hasInterestWaivedCents() => $_has(21);
  @$pb.TagNumber(22)
  void clearInterestWaivedCents() => $_clearField(22);
}

class UpdateDebtRequest extends $pb.GeneratedMessage {
  factory UpdateDebtRequest({
    $core.String? id,
    $core.String? counterparty,
    $core.double? interestRate,
    $fixnum.Int64? version,
    $core.String? contact,
    $core.String? contractRef,
    $core.String? collectionAccountId,
    AmortizationMethod? amortizationMethod,
    $core.String? dueDate,
    $core.int? termPeriods,
    $4.RecurrenceCycle? cycle,
    $core.int? interval,
    $core.int? weekdayMask,
    $4.RecurrenceMonthlyMode? monthlyMode,
    $core.int? nth,
    $core.String? guarantorName,
    $core.String? guarantorContact,
    $fixnum.Int64? interestWaivedCents,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (counterparty != null) result.counterparty = counterparty;
    if (interestRate != null) result.interestRate = interestRate;
    if (version != null) result.version = version;
    if (contact != null) result.contact = contact;
    if (contractRef != null) result.contractRef = contractRef;
    if (collectionAccountId != null)
      result.collectionAccountId = collectionAccountId;
    if (amortizationMethod != null)
      result.amortizationMethod = amortizationMethod;
    if (dueDate != null) result.dueDate = dueDate;
    if (termPeriods != null) result.termPeriods = termPeriods;
    if (cycle != null) result.cycle = cycle;
    if (interval != null) result.interval = interval;
    if (weekdayMask != null) result.weekdayMask = weekdayMask;
    if (monthlyMode != null) result.monthlyMode = monthlyMode;
    if (nth != null) result.nth = nth;
    if (guarantorName != null) result.guarantorName = guarantorName;
    if (guarantorContact != null) result.guarantorContact = guarantorContact;
    if (interestWaivedCents != null)
      result.interestWaivedCents = interestWaivedCents;
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
    ..aOS(5, _omitFieldNames ? '' : 'contact')
    ..aOS(6, _omitFieldNames ? '' : 'contractRef')
    ..aOS(7, _omitFieldNames ? '' : 'collectionAccountId')
    ..aE<AmortizationMethod>(8, _omitFieldNames ? '' : 'amortizationMethod',
        enumValues: AmortizationMethod.values)
    ..aOS(9, _omitFieldNames ? '' : 'dueDate')
    ..aI(10, _omitFieldNames ? '' : 'termPeriods')
    ..aE<$4.RecurrenceCycle>(11, _omitFieldNames ? '' : 'cycle',
        enumValues: $4.RecurrenceCycle.values)
    ..aI(12, _omitFieldNames ? '' : 'interval')
    ..aI(13, _omitFieldNames ? '' : 'weekdayMask')
    ..aE<$4.RecurrenceMonthlyMode>(14, _omitFieldNames ? '' : 'monthlyMode',
        enumValues: $4.RecurrenceMonthlyMode.values)
    ..aI(15, _omitFieldNames ? '' : 'nth')
    ..aOS(16, _omitFieldNames ? '' : 'guarantorName')
    ..aOS(17, _omitFieldNames ? '' : 'guarantorContact')
    ..aInt64(18, _omitFieldNames ? '' : 'interestWaivedCents')
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

  @$pb.TagNumber(5)
  $core.String get contact => $_getSZ(4);
  @$pb.TagNumber(5)
  set contact($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasContact() => $_has(4);
  @$pb.TagNumber(5)
  void clearContact() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get contractRef => $_getSZ(5);
  @$pb.TagNumber(6)
  set contractRef($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasContractRef() => $_has(5);
  @$pb.TagNumber(6)
  void clearContractRef() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get collectionAccountId => $_getSZ(6);
  @$pb.TagNumber(7)
  set collectionAccountId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCollectionAccountId() => $_has(6);
  @$pb.TagNumber(7)
  void clearCollectionAccountId() => $_clearField(7);

  /// Schedule-affecting edits (Google-Calendar style): already-recorded
  /// entries (paid / paid_cents>0 / transaction set) are frozen; the future
  /// schedule is regenerated from the remaining principal.
  @$pb.TagNumber(8)
  AmortizationMethod get amortizationMethod => $_getN(7);
  @$pb.TagNumber(8)
  set amortizationMethod(AmortizationMethod value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasAmortizationMethod() => $_has(7);
  @$pb.TagNumber(8)
  void clearAmortizationMethod() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get dueDate => $_getSZ(8);
  @$pb.TagNumber(9)
  set dueDate($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasDueDate() => $_has(8);
  @$pb.TagNumber(9)
  void clearDueDate() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get termPeriods => $_getIZ(9);
  @$pb.TagNumber(10)
  set termPeriods($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasTermPeriods() => $_has(9);
  @$pb.TagNumber(10)
  void clearTermPeriods() => $_clearField(10);

  @$pb.TagNumber(11)
  $4.RecurrenceCycle get cycle => $_getN(10);
  @$pb.TagNumber(11)
  set cycle($4.RecurrenceCycle value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasCycle() => $_has(10);
  @$pb.TagNumber(11)
  void clearCycle() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get interval => $_getIZ(11);
  @$pb.TagNumber(12)
  set interval($core.int value) => $_setSignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasInterval() => $_has(11);
  @$pb.TagNumber(12)
  void clearInterval() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get weekdayMask => $_getIZ(12);
  @$pb.TagNumber(13)
  set weekdayMask($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasWeekdayMask() => $_has(12);
  @$pb.TagNumber(13)
  void clearWeekdayMask() => $_clearField(13);

  @$pb.TagNumber(14)
  $4.RecurrenceMonthlyMode get monthlyMode => $_getN(13);
  @$pb.TagNumber(14)
  set monthlyMode($4.RecurrenceMonthlyMode value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasMonthlyMode() => $_has(13);
  @$pb.TagNumber(14)
  void clearMonthlyMode() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.int get nth => $_getIZ(14);
  @$pb.TagNumber(15)
  set nth($core.int value) => $_setSignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasNth() => $_has(14);
  @$pb.TagNumber(15)
  void clearNth() => $_clearField(15);

  /// Guarantor (optional; empty string clears, same semantics as contact).
  @$pb.TagNumber(16)
  $core.String get guarantorName => $_getSZ(15);
  @$pb.TagNumber(16)
  set guarantorName($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasGuarantorName() => $_has(15);
  @$pb.TagNumber(16)
  void clearGuarantorName() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.String get guarantorContact => $_getSZ(16);
  @$pb.TagNumber(17)
  set guarantorContact($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasGuarantorContact() => $_has(16);
  @$pb.TagNumber(17)
  void clearGuarantorContact() => $_clearField(17);

  /// optional = presence-aware: unset keeps the current waiver, set replaces
  /// (0 clears the waiver).
  @$pb.TagNumber(18)
  $fixnum.Int64 get interestWaivedCents => $_getI64(17);
  @$pb.TagNumber(18)
  set interestWaivedCents($fixnum.Int64 value) => $_setInt64(17, value);
  @$pb.TagNumber(18)
  $core.bool hasInterestWaivedCents() => $_has(17);
  @$pb.TagNumber(18)
  void clearInterestWaivedCents() => $_clearField(18);
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

class SetPaymentDateRequest extends $pb.GeneratedMessage {
  factory SetPaymentDateRequest({
    $core.String? debtId,
    $core.String? entryId,
    $core.String? paymentDate,
  }) {
    final result = create();
    if (debtId != null) result.debtId = debtId;
    if (entryId != null) result.entryId = entryId;
    if (paymentDate != null) result.paymentDate = paymentDate;
    return result;
  }

  SetPaymentDateRequest._();

  factory SetPaymentDateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetPaymentDateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetPaymentDateRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'debtId')
    ..aOS(2, _omitFieldNames ? '' : 'entryId')
    ..aOS(3, _omitFieldNames ? '' : 'paymentDate')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetPaymentDateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetPaymentDateRequest copyWith(
          void Function(SetPaymentDateRequest) updates) =>
      super.copyWith((message) => updates(message as SetPaymentDateRequest))
          as SetPaymentDateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetPaymentDateRequest create() => SetPaymentDateRequest._();
  @$core.override
  SetPaymentDateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetPaymentDateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetPaymentDateRequest>(create);
  static SetPaymentDateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get debtId => $_getSZ(0);
  @$pb.TagNumber(1)
  set debtId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDebtId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDebtId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get entryId => $_getSZ(1);
  @$pb.TagNumber(2)
  set entryId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEntryId() => $_has(1);
  @$pb.TagNumber(2)
  void clearEntryId() => $_clearField(2);

  /// yyyy-MM-dd; must be after the debt start date and free of collision.
  @$pb.TagNumber(3)
  $core.String get paymentDate => $_getSZ(2);
  @$pb.TagNumber(3)
  set paymentDate($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPaymentDate() => $_has(2);
  @$pb.TagNumber(3)
  void clearPaymentDate() => $_clearField(3);
}

class PaymentEntryResponse extends $pb.GeneratedMessage {
  factory PaymentEntryResponse({
    PaymentEntryDTO? entry,
  }) {
    final result = create();
    if (entry != null) result.entry = entry;
    return result;
  }

  PaymentEntryResponse._();

  factory PaymentEntryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PaymentEntryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PaymentEntryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..aOM<PaymentEntryDTO>(1, _omitFieldNames ? '' : 'entry',
        subBuilder: PaymentEntryDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaymentEntryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaymentEntryResponse copyWith(void Function(PaymentEntryResponse) updates) =>
      super.copyWith((message) => updates(message as PaymentEntryResponse))
          as PaymentEntryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaymentEntryResponse create() => PaymentEntryResponse._();
  @$core.override
  PaymentEntryResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PaymentEntryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PaymentEntryResponse>(create);
  static PaymentEntryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  PaymentEntryDTO get entry => $_getN(0);
  @$pb.TagNumber(1)
  set entry(PaymentEntryDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasEntry() => $_has(0);
  @$pb.TagNumber(1)
  void clearEntry() => $_clearField(1);
  @$pb.TagNumber(1)
  PaymentEntryDTO ensureEntry() => $_ensure(0);
}

class MarkEntryPaidRequest extends $pb.GeneratedMessage {
  factory MarkEntryPaidRequest({
    $core.String? debtId,
    $core.String? entryId,
  }) {
    final result = create();
    if (debtId != null) result.debtId = debtId;
    if (entryId != null) result.entryId = entryId;
    return result;
  }

  MarkEntryPaidRequest._();

  factory MarkEntryPaidRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MarkEntryPaidRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MarkEntryPaidRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'debtId')
    ..aOS(2, _omitFieldNames ? '' : 'entryId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarkEntryPaidRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarkEntryPaidRequest copyWith(void Function(MarkEntryPaidRequest) updates) =>
      super.copyWith((message) => updates(message as MarkEntryPaidRequest))
          as MarkEntryPaidRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MarkEntryPaidRequest create() => MarkEntryPaidRequest._();
  @$core.override
  MarkEntryPaidRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MarkEntryPaidRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MarkEntryPaidRequest>(create);
  static MarkEntryPaidRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get debtId => $_getSZ(0);
  @$pb.TagNumber(1)
  set debtId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDebtId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDebtId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get entryId => $_getSZ(1);
  @$pb.TagNumber(2)
  set entryId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEntryId() => $_has(1);
  @$pb.TagNumber(2)
  void clearEntryId() => $_clearField(2);
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
    DebtType? typeFilter,
  }) {
    final result = create();
    if (page != null) result.page = page;
    if (typeFilter != null) result.typeFilter = typeFilter;
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
    ..aE<DebtType>(2, _omitFieldNames ? '' : 'typeFilter',
        enumValues: DebtType.values)
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

  @$pb.TagNumber(2)
  DebtType get typeFilter => $_getN(1);
  @$pb.TagNumber(2)
  set typeFilter(DebtType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasTypeFilter() => $_has(1);
  @$pb.TagNumber(2)
  void clearTypeFilter() => $_clearField(2);
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

class GetReceivablesSummaryRequest extends $pb.GeneratedMessage {
  factory GetReceivablesSummaryRequest() => create();

  GetReceivablesSummaryRequest._();

  factory GetReceivablesSummaryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetReceivablesSummaryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetReceivablesSummaryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetReceivablesSummaryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetReceivablesSummaryRequest copyWith(
          void Function(GetReceivablesSummaryRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetReceivablesSummaryRequest))
          as GetReceivablesSummaryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetReceivablesSummaryRequest create() =>
      GetReceivablesSummaryRequest._();
  @$core.override
  GetReceivablesSummaryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetReceivablesSummaryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetReceivablesSummaryRequest>(create);
  static GetReceivablesSummaryRequest? _defaultInstance;
}

class ReceivablesSummaryDTO extends $pb.GeneratedMessage {
  factory ReceivablesSummaryDTO({
    $fixnum.Int64? totalPrincipalCents,
    $fixnum.Int64? totalRemainingCents,
    $fixnum.Int64? totalCollectedCents,
    $fixnum.Int64? pendingInterestCents,
    $core.int? count,
    $core.int? overdueCount,
    $fixnum.Int64? overdueAmountCents,
    $fixnum.Int64? principalTrendCents,
    $fixnum.Int64? remainingTrendCents,
    $core.String? nextPaymentDate,
    $fixnum.Int64? nextPaymentAmountCents,
    $core.String? nextPaymentCounterparty,
    $core.int? nextPaymentPeriodNo,
    $core.int? newCountThisMonth,
  }) {
    final result = create();
    if (totalPrincipalCents != null)
      result.totalPrincipalCents = totalPrincipalCents;
    if (totalRemainingCents != null)
      result.totalRemainingCents = totalRemainingCents;
    if (totalCollectedCents != null)
      result.totalCollectedCents = totalCollectedCents;
    if (pendingInterestCents != null)
      result.pendingInterestCents = pendingInterestCents;
    if (count != null) result.count = count;
    if (overdueCount != null) result.overdueCount = overdueCount;
    if (overdueAmountCents != null)
      result.overdueAmountCents = overdueAmountCents;
    if (principalTrendCents != null)
      result.principalTrendCents = principalTrendCents;
    if (remainingTrendCents != null)
      result.remainingTrendCents = remainingTrendCents;
    if (nextPaymentDate != null) result.nextPaymentDate = nextPaymentDate;
    if (nextPaymentAmountCents != null)
      result.nextPaymentAmountCents = nextPaymentAmountCents;
    if (nextPaymentCounterparty != null)
      result.nextPaymentCounterparty = nextPaymentCounterparty;
    if (nextPaymentPeriodNo != null)
      result.nextPaymentPeriodNo = nextPaymentPeriodNo;
    if (newCountThisMonth != null) result.newCountThisMonth = newCountThisMonth;
    return result;
  }

  ReceivablesSummaryDTO._();

  factory ReceivablesSummaryDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReceivablesSummaryDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReceivablesSummaryDTO',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'totalPrincipalCents')
    ..aInt64(2, _omitFieldNames ? '' : 'totalRemainingCents')
    ..aInt64(3, _omitFieldNames ? '' : 'totalCollectedCents')
    ..aInt64(4, _omitFieldNames ? '' : 'pendingInterestCents')
    ..aI(5, _omitFieldNames ? '' : 'count')
    ..aI(6, _omitFieldNames ? '' : 'overdueCount')
    ..aInt64(7, _omitFieldNames ? '' : 'overdueAmountCents')
    ..aInt64(8, _omitFieldNames ? '' : 'principalTrendCents')
    ..aInt64(9, _omitFieldNames ? '' : 'remainingTrendCents')
    ..aOS(10, _omitFieldNames ? '' : 'nextPaymentDate')
    ..aInt64(11, _omitFieldNames ? '' : 'nextPaymentAmountCents')
    ..aOS(12, _omitFieldNames ? '' : 'nextPaymentCounterparty')
    ..aI(13, _omitFieldNames ? '' : 'nextPaymentPeriodNo')
    ..aI(14, _omitFieldNames ? '' : 'newCountThisMonth')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReceivablesSummaryDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReceivablesSummaryDTO copyWith(
          void Function(ReceivablesSummaryDTO) updates) =>
      super.copyWith((message) => updates(message as ReceivablesSummaryDTO))
          as ReceivablesSummaryDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReceivablesSummaryDTO create() => ReceivablesSummaryDTO._();
  @$core.override
  ReceivablesSummaryDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReceivablesSummaryDTO getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReceivablesSummaryDTO>(create);
  static ReceivablesSummaryDTO? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get totalPrincipalCents => $_getI64(0);
  @$pb.TagNumber(1)
  set totalPrincipalCents($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTotalPrincipalCents() => $_has(0);
  @$pb.TagNumber(1)
  void clearTotalPrincipalCents() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get totalRemainingCents => $_getI64(1);
  @$pb.TagNumber(2)
  set totalRemainingCents($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalRemainingCents() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalRemainingCents() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get totalCollectedCents => $_getI64(2);
  @$pb.TagNumber(3)
  set totalCollectedCents($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotalCollectedCents() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalCollectedCents() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get pendingInterestCents => $_getI64(3);
  @$pb.TagNumber(4)
  set pendingInterestCents($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPendingInterestCents() => $_has(3);
  @$pb.TagNumber(4)
  void clearPendingInterestCents() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get count => $_getIZ(4);
  @$pb.TagNumber(5)
  set count($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCount() => $_has(4);
  @$pb.TagNumber(5)
  void clearCount() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get overdueCount => $_getIZ(5);
  @$pb.TagNumber(6)
  set overdueCount($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasOverdueCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearOverdueCount() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get overdueAmountCents => $_getI64(6);
  @$pb.TagNumber(7)
  set overdueAmountCents($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasOverdueAmountCents() => $_has(6);
  @$pb.TagNumber(7)
  void clearOverdueAmountCents() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get principalTrendCents => $_getI64(7);
  @$pb.TagNumber(8)
  set principalTrendCents($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPrincipalTrendCents() => $_has(7);
  @$pb.TagNumber(8)
  void clearPrincipalTrendCents() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get remainingTrendCents => $_getI64(8);
  @$pb.TagNumber(9)
  set remainingTrendCents($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasRemainingTrendCents() => $_has(8);
  @$pb.TagNumber(9)
  void clearRemainingTrendCents() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get nextPaymentDate => $_getSZ(9);
  @$pb.TagNumber(10)
  set nextPaymentDate($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasNextPaymentDate() => $_has(9);
  @$pb.TagNumber(10)
  void clearNextPaymentDate() => $_clearField(10);

  @$pb.TagNumber(11)
  $fixnum.Int64 get nextPaymentAmountCents => $_getI64(10);
  @$pb.TagNumber(11)
  set nextPaymentAmountCents($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasNextPaymentAmountCents() => $_has(10);
  @$pb.TagNumber(11)
  void clearNextPaymentAmountCents() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get nextPaymentCounterparty => $_getSZ(11);
  @$pb.TagNumber(12)
  set nextPaymentCounterparty($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasNextPaymentCounterparty() => $_has(11);
  @$pb.TagNumber(12)
  void clearNextPaymentCounterparty() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get nextPaymentPeriodNo => $_getIZ(12);
  @$pb.TagNumber(13)
  set nextPaymentPeriodNo($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasNextPaymentPeriodNo() => $_has(12);
  @$pb.TagNumber(13)
  void clearNextPaymentPeriodNo() => $_clearField(13);

  /// Count of receivables newly created this month (created_at in current month).
  /// Drives the "较上月 +¥X · 新增 N 笔" trend line on the list overview.
  @$pb.TagNumber(14)
  $core.int get newCountThisMonth => $_getIZ(13);
  @$pb.TagNumber(14)
  set newCountThisMonth($core.int value) => $_setSignedInt32(13, value);
  @$pb.TagNumber(14)
  $core.bool hasNewCountThisMonth() => $_has(13);
  @$pb.TagNumber(14)
  void clearNewCountThisMonth() => $_clearField(14);
}

class ReceivablesSummaryResponse extends $pb.GeneratedMessage {
  factory ReceivablesSummaryResponse({
    ReceivablesSummaryDTO? summary,
  }) {
    final result = create();
    if (summary != null) result.summary = summary;
    return result;
  }

  ReceivablesSummaryResponse._();

  factory ReceivablesSummaryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReceivablesSummaryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReceivablesSummaryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.debt.v1'),
      createEmptyInstance: create)
    ..aOM<ReceivablesSummaryDTO>(1, _omitFieldNames ? '' : 'summary',
        subBuilder: ReceivablesSummaryDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReceivablesSummaryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReceivablesSummaryResponse copyWith(
          void Function(ReceivablesSummaryResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ReceivablesSummaryResponse))
          as ReceivablesSummaryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReceivablesSummaryResponse create() => ReceivablesSummaryResponse._();
  @$core.override
  ReceivablesSummaryResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReceivablesSummaryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReceivablesSummaryResponse>(create);
  static ReceivablesSummaryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  ReceivablesSummaryDTO get summary => $_getN(0);
  @$pb.TagNumber(1)
  set summary(ReceivablesSummaryDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSummary() => $_has(0);
  @$pb.TagNumber(1)
  void clearSummary() => $_clearField(1);
  @$pb.TagNumber(1)
  ReceivablesSummaryDTO ensureSummary() => $_ensure(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
