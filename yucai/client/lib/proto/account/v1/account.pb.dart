// This is a generated file - do not edit.
//
// Generated from account/v1/account.proto.

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
import 'account.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'account.pbenum.dart';

class AccountDTO extends $pb.GeneratedMessage {
  factory AccountDTO({
    $core.String? id,
    $core.String? name,
    AccountType? accountType,
    $core.String? currencyCode,
    $fixnum.Int64? initialBalanceCents,
    $fixnum.Int64? currentBalanceCents,
    Ownership? ownership,
    $core.String? icon,
    $core.String? color,
    $core.String? chartCode,
    $core.String? parentId,
    $core.String? institution,
    $fixnum.Int64? creditLimitCents,
    AccountStatus? status,
    $fixnum.Int64? version,
    $2.Timestamp? createdAt,
    $2.Timestamp? updatedAt,
    AccountCategory? category,
    $core.String? cardNumberTail,
    $core.String? notes,
    $2.Timestamp? openingDate,
    $core.double? interestRate,
    $core.int? creditBillingDay,
    $core.int? creditRepaymentDay,
    $fixnum.Int64? creditAnnualFeeCents,
    $fixnum.Int64? investCostCents,
    $fixnum.Int64? investMarketValueCents,
    $core.double? investReturnYtd,
    $fixnum.Int64? fixedPrincipalCents,
    $2.Timestamp? fixedStartDate,
    $2.Timestamp? fixedMaturityDate,
    $core.int? fixedTermMonths,
    $core.String? goldProductType,
    $core.double? goldQuantity,
    $fixnum.Int64? goldBuyPriceCents,
    $fixnum.Int64? goldCurrentPriceCents,
    $fixnum.Int64? estatePurchasePriceCents,
    $fixnum.Int64? estateCurrentValueCents,
    $2.Timestamp? estatePurchaseDate,
    $core.double? estateDepreciationRate,
    $fixnum.Int64? loanOriginalCents,
    $fixnum.Int64? loanRemainingCents,
    $fixnum.Int64? loanMonthlyCents,
    $2.Timestamp? loanNextPaymentDate,
    $core.bool? isSystem,
    $core.int? sortOrder,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (accountType != null) result.accountType = accountType;
    if (currencyCode != null) result.currencyCode = currencyCode;
    if (initialBalanceCents != null)
      result.initialBalanceCents = initialBalanceCents;
    if (currentBalanceCents != null)
      result.currentBalanceCents = currentBalanceCents;
    if (ownership != null) result.ownership = ownership;
    if (icon != null) result.icon = icon;
    if (color != null) result.color = color;
    if (chartCode != null) result.chartCode = chartCode;
    if (parentId != null) result.parentId = parentId;
    if (institution != null) result.institution = institution;
    if (creditLimitCents != null) result.creditLimitCents = creditLimitCents;
    if (status != null) result.status = status;
    if (version != null) result.version = version;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    if (category != null) result.category = category;
    if (cardNumberTail != null) result.cardNumberTail = cardNumberTail;
    if (notes != null) result.notes = notes;
    if (openingDate != null) result.openingDate = openingDate;
    if (interestRate != null) result.interestRate = interestRate;
    if (creditBillingDay != null) result.creditBillingDay = creditBillingDay;
    if (creditRepaymentDay != null)
      result.creditRepaymentDay = creditRepaymentDay;
    if (creditAnnualFeeCents != null)
      result.creditAnnualFeeCents = creditAnnualFeeCents;
    if (investCostCents != null) result.investCostCents = investCostCents;
    if (investMarketValueCents != null)
      result.investMarketValueCents = investMarketValueCents;
    if (investReturnYtd != null) result.investReturnYtd = investReturnYtd;
    if (fixedPrincipalCents != null)
      result.fixedPrincipalCents = fixedPrincipalCents;
    if (fixedStartDate != null) result.fixedStartDate = fixedStartDate;
    if (fixedMaturityDate != null) result.fixedMaturityDate = fixedMaturityDate;
    if (fixedTermMonths != null) result.fixedTermMonths = fixedTermMonths;
    if (goldProductType != null) result.goldProductType = goldProductType;
    if (goldQuantity != null) result.goldQuantity = goldQuantity;
    if (goldBuyPriceCents != null) result.goldBuyPriceCents = goldBuyPriceCents;
    if (goldCurrentPriceCents != null)
      result.goldCurrentPriceCents = goldCurrentPriceCents;
    if (estatePurchasePriceCents != null)
      result.estatePurchasePriceCents = estatePurchasePriceCents;
    if (estateCurrentValueCents != null)
      result.estateCurrentValueCents = estateCurrentValueCents;
    if (estatePurchaseDate != null)
      result.estatePurchaseDate = estatePurchaseDate;
    if (estateDepreciationRate != null)
      result.estateDepreciationRate = estateDepreciationRate;
    if (loanOriginalCents != null) result.loanOriginalCents = loanOriginalCents;
    if (loanRemainingCents != null)
      result.loanRemainingCents = loanRemainingCents;
    if (loanMonthlyCents != null) result.loanMonthlyCents = loanMonthlyCents;
    if (loanNextPaymentDate != null)
      result.loanNextPaymentDate = loanNextPaymentDate;
    if (isSystem != null) result.isSystem = isSystem;
    if (sortOrder != null) result.sortOrder = sortOrder;
    return result;
  }

  AccountDTO._();

  factory AccountDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AccountDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AccountDTO',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aE<AccountType>(3, _omitFieldNames ? '' : 'accountType',
        enumValues: AccountType.values)
    ..aOS(4, _omitFieldNames ? '' : 'currencyCode')
    ..aInt64(5, _omitFieldNames ? '' : 'initialBalanceCents')
    ..aInt64(6, _omitFieldNames ? '' : 'currentBalanceCents')
    ..aE<Ownership>(7, _omitFieldNames ? '' : 'ownership',
        enumValues: Ownership.values)
    ..aOS(8, _omitFieldNames ? '' : 'icon')
    ..aOS(9, _omitFieldNames ? '' : 'color')
    ..aOS(10, _omitFieldNames ? '' : 'chartCode')
    ..aOS(11, _omitFieldNames ? '' : 'parentId')
    ..aOS(12, _omitFieldNames ? '' : 'institution')
    ..aInt64(13, _omitFieldNames ? '' : 'creditLimitCents')
    ..aE<AccountStatus>(14, _omitFieldNames ? '' : 'status',
        enumValues: AccountStatus.values)
    ..aInt64(15, _omitFieldNames ? '' : 'version')
    ..aOM<$2.Timestamp>(16, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(17, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $2.Timestamp.create)
    ..aE<AccountCategory>(18, _omitFieldNames ? '' : 'category',
        enumValues: AccountCategory.values)
    ..aOS(19, _omitFieldNames ? '' : 'cardNumberTail')
    ..aOS(20, _omitFieldNames ? '' : 'notes')
    ..aOM<$2.Timestamp>(21, _omitFieldNames ? '' : 'openingDate',
        subBuilder: $2.Timestamp.create)
    ..aD(22, _omitFieldNames ? '' : 'interestRate')
    ..aI(23, _omitFieldNames ? '' : 'creditBillingDay')
    ..aI(24, _omitFieldNames ? '' : 'creditRepaymentDay')
    ..aInt64(25, _omitFieldNames ? '' : 'creditAnnualFeeCents')
    ..aInt64(26, _omitFieldNames ? '' : 'investCostCents')
    ..aInt64(27, _omitFieldNames ? '' : 'investMarketValueCents')
    ..aD(28, _omitFieldNames ? '' : 'investReturnYtd')
    ..aInt64(29, _omitFieldNames ? '' : 'fixedPrincipalCents')
    ..aOM<$2.Timestamp>(30, _omitFieldNames ? '' : 'fixedStartDate',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(31, _omitFieldNames ? '' : 'fixedMaturityDate',
        subBuilder: $2.Timestamp.create)
    ..aI(32, _omitFieldNames ? '' : 'fixedTermMonths')
    ..aOS(33, _omitFieldNames ? '' : 'goldProductType')
    ..aD(34, _omitFieldNames ? '' : 'goldQuantity')
    ..aInt64(35, _omitFieldNames ? '' : 'goldBuyPriceCents')
    ..aInt64(36, _omitFieldNames ? '' : 'goldCurrentPriceCents')
    ..aInt64(37, _omitFieldNames ? '' : 'estatePurchasePriceCents')
    ..aInt64(38, _omitFieldNames ? '' : 'estateCurrentValueCents')
    ..aOM<$2.Timestamp>(39, _omitFieldNames ? '' : 'estatePurchaseDate',
        subBuilder: $2.Timestamp.create)
    ..aD(40, _omitFieldNames ? '' : 'estateDepreciationRate')
    ..aInt64(41, _omitFieldNames ? '' : 'loanOriginalCents')
    ..aInt64(42, _omitFieldNames ? '' : 'loanRemainingCents')
    ..aInt64(43, _omitFieldNames ? '' : 'loanMonthlyCents')
    ..aOM<$2.Timestamp>(44, _omitFieldNames ? '' : 'loanNextPaymentDate',
        subBuilder: $2.Timestamp.create)
    ..aOB(45, _omitFieldNames ? '' : 'isSystem')
    ..aI(46, _omitFieldNames ? '' : 'sortOrder')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccountDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccountDTO copyWith(void Function(AccountDTO) updates) =>
      super.copyWith((message) => updates(message as AccountDTO)) as AccountDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AccountDTO create() => AccountDTO._();
  @$core.override
  AccountDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AccountDTO getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AccountDTO>(create);
  static AccountDTO? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  AccountType get accountType => $_getN(2);
  @$pb.TagNumber(3)
  set accountType(AccountType value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAccountType() => $_has(2);
  @$pb.TagNumber(3)
  void clearAccountType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get currencyCode => $_getSZ(3);
  @$pb.TagNumber(4)
  set currencyCode($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCurrencyCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearCurrencyCode() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get initialBalanceCents => $_getI64(4);
  @$pb.TagNumber(5)
  set initialBalanceCents($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasInitialBalanceCents() => $_has(4);
  @$pb.TagNumber(5)
  void clearInitialBalanceCents() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get currentBalanceCents => $_getI64(5);
  @$pb.TagNumber(6)
  set currentBalanceCents($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCurrentBalanceCents() => $_has(5);
  @$pb.TagNumber(6)
  void clearCurrentBalanceCents() => $_clearField(6);

  @$pb.TagNumber(7)
  Ownership get ownership => $_getN(6);
  @$pb.TagNumber(7)
  set ownership(Ownership value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasOwnership() => $_has(6);
  @$pb.TagNumber(7)
  void clearOwnership() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get icon => $_getSZ(7);
  @$pb.TagNumber(8)
  set icon($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasIcon() => $_has(7);
  @$pb.TagNumber(8)
  void clearIcon() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get color => $_getSZ(8);
  @$pb.TagNumber(9)
  set color($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasColor() => $_has(8);
  @$pb.TagNumber(9)
  void clearColor() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get chartCode => $_getSZ(9);
  @$pb.TagNumber(10)
  set chartCode($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasChartCode() => $_has(9);
  @$pb.TagNumber(10)
  void clearChartCode() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get parentId => $_getSZ(10);
  @$pb.TagNumber(11)
  set parentId($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasParentId() => $_has(10);
  @$pb.TagNumber(11)
  void clearParentId() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get institution => $_getSZ(11);
  @$pb.TagNumber(12)
  set institution($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasInstitution() => $_has(11);
  @$pb.TagNumber(12)
  void clearInstitution() => $_clearField(12);

  @$pb.TagNumber(13)
  $fixnum.Int64 get creditLimitCents => $_getI64(12);
  @$pb.TagNumber(13)
  set creditLimitCents($fixnum.Int64 value) => $_setInt64(12, value);
  @$pb.TagNumber(13)
  $core.bool hasCreditLimitCents() => $_has(12);
  @$pb.TagNumber(13)
  void clearCreditLimitCents() => $_clearField(13);

  @$pb.TagNumber(14)
  AccountStatus get status => $_getN(13);
  @$pb.TagNumber(14)
  set status(AccountStatus value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasStatus() => $_has(13);
  @$pb.TagNumber(14)
  void clearStatus() => $_clearField(14);

  @$pb.TagNumber(15)
  $fixnum.Int64 get version => $_getI64(14);
  @$pb.TagNumber(15)
  set version($fixnum.Int64 value) => $_setInt64(14, value);
  @$pb.TagNumber(15)
  $core.bool hasVersion() => $_has(14);
  @$pb.TagNumber(15)
  void clearVersion() => $_clearField(15);

  @$pb.TagNumber(16)
  $2.Timestamp get createdAt => $_getN(15);
  @$pb.TagNumber(16)
  set createdAt($2.Timestamp value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasCreatedAt() => $_has(15);
  @$pb.TagNumber(16)
  void clearCreatedAt() => $_clearField(16);
  @$pb.TagNumber(16)
  $2.Timestamp ensureCreatedAt() => $_ensure(15);

  @$pb.TagNumber(17)
  $2.Timestamp get updatedAt => $_getN(16);
  @$pb.TagNumber(17)
  set updatedAt($2.Timestamp value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasUpdatedAt() => $_has(16);
  @$pb.TagNumber(17)
  void clearUpdatedAt() => $_clearField(17);
  @$pb.TagNumber(17)
  $2.Timestamp ensureUpdatedAt() => $_ensure(16);

  @$pb.TagNumber(18)
  AccountCategory get category => $_getN(17);
  @$pb.TagNumber(18)
  set category(AccountCategory value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasCategory() => $_has(17);
  @$pb.TagNumber(18)
  void clearCategory() => $_clearField(18);

  @$pb.TagNumber(19)
  $core.String get cardNumberTail => $_getSZ(18);
  @$pb.TagNumber(19)
  set cardNumberTail($core.String value) => $_setString(18, value);
  @$pb.TagNumber(19)
  $core.bool hasCardNumberTail() => $_has(18);
  @$pb.TagNumber(19)
  void clearCardNumberTail() => $_clearField(19);

  @$pb.TagNumber(20)
  $core.String get notes => $_getSZ(19);
  @$pb.TagNumber(20)
  set notes($core.String value) => $_setString(19, value);
  @$pb.TagNumber(20)
  $core.bool hasNotes() => $_has(19);
  @$pb.TagNumber(20)
  void clearNotes() => $_clearField(20);

  @$pb.TagNumber(21)
  $2.Timestamp get openingDate => $_getN(20);
  @$pb.TagNumber(21)
  set openingDate($2.Timestamp value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasOpeningDate() => $_has(20);
  @$pb.TagNumber(21)
  void clearOpeningDate() => $_clearField(21);
  @$pb.TagNumber(21)
  $2.Timestamp ensureOpeningDate() => $_ensure(20);

  @$pb.TagNumber(22)
  $core.double get interestRate => $_getN(21);
  @$pb.TagNumber(22)
  set interestRate($core.double value) => $_setDouble(21, value);
  @$pb.TagNumber(22)
  $core.bool hasInterestRate() => $_has(21);
  @$pb.TagNumber(22)
  void clearInterestRate() => $_clearField(22);

  @$pb.TagNumber(23)
  $core.int get creditBillingDay => $_getIZ(22);
  @$pb.TagNumber(23)
  set creditBillingDay($core.int value) => $_setSignedInt32(22, value);
  @$pb.TagNumber(23)
  $core.bool hasCreditBillingDay() => $_has(22);
  @$pb.TagNumber(23)
  void clearCreditBillingDay() => $_clearField(23);

  @$pb.TagNumber(24)
  $core.int get creditRepaymentDay => $_getIZ(23);
  @$pb.TagNumber(24)
  set creditRepaymentDay($core.int value) => $_setSignedInt32(23, value);
  @$pb.TagNumber(24)
  $core.bool hasCreditRepaymentDay() => $_has(23);
  @$pb.TagNumber(24)
  void clearCreditRepaymentDay() => $_clearField(24);

  @$pb.TagNumber(25)
  $fixnum.Int64 get creditAnnualFeeCents => $_getI64(24);
  @$pb.TagNumber(25)
  set creditAnnualFeeCents($fixnum.Int64 value) => $_setInt64(24, value);
  @$pb.TagNumber(25)
  $core.bool hasCreditAnnualFeeCents() => $_has(24);
  @$pb.TagNumber(25)
  void clearCreditAnnualFeeCents() => $_clearField(25);

  @$pb.TagNumber(26)
  $fixnum.Int64 get investCostCents => $_getI64(25);
  @$pb.TagNumber(26)
  set investCostCents($fixnum.Int64 value) => $_setInt64(25, value);
  @$pb.TagNumber(26)
  $core.bool hasInvestCostCents() => $_has(25);
  @$pb.TagNumber(26)
  void clearInvestCostCents() => $_clearField(26);

  @$pb.TagNumber(27)
  $fixnum.Int64 get investMarketValueCents => $_getI64(26);
  @$pb.TagNumber(27)
  set investMarketValueCents($fixnum.Int64 value) => $_setInt64(26, value);
  @$pb.TagNumber(27)
  $core.bool hasInvestMarketValueCents() => $_has(26);
  @$pb.TagNumber(27)
  void clearInvestMarketValueCents() => $_clearField(27);

  @$pb.TagNumber(28)
  $core.double get investReturnYtd => $_getN(27);
  @$pb.TagNumber(28)
  set investReturnYtd($core.double value) => $_setDouble(27, value);
  @$pb.TagNumber(28)
  $core.bool hasInvestReturnYtd() => $_has(27);
  @$pb.TagNumber(28)
  void clearInvestReturnYtd() => $_clearField(28);

  @$pb.TagNumber(29)
  $fixnum.Int64 get fixedPrincipalCents => $_getI64(28);
  @$pb.TagNumber(29)
  set fixedPrincipalCents($fixnum.Int64 value) => $_setInt64(28, value);
  @$pb.TagNumber(29)
  $core.bool hasFixedPrincipalCents() => $_has(28);
  @$pb.TagNumber(29)
  void clearFixedPrincipalCents() => $_clearField(29);

  @$pb.TagNumber(30)
  $2.Timestamp get fixedStartDate => $_getN(29);
  @$pb.TagNumber(30)
  set fixedStartDate($2.Timestamp value) => $_setField(30, value);
  @$pb.TagNumber(30)
  $core.bool hasFixedStartDate() => $_has(29);
  @$pb.TagNumber(30)
  void clearFixedStartDate() => $_clearField(30);
  @$pb.TagNumber(30)
  $2.Timestamp ensureFixedStartDate() => $_ensure(29);

  @$pb.TagNumber(31)
  $2.Timestamp get fixedMaturityDate => $_getN(30);
  @$pb.TagNumber(31)
  set fixedMaturityDate($2.Timestamp value) => $_setField(31, value);
  @$pb.TagNumber(31)
  $core.bool hasFixedMaturityDate() => $_has(30);
  @$pb.TagNumber(31)
  void clearFixedMaturityDate() => $_clearField(31);
  @$pb.TagNumber(31)
  $2.Timestamp ensureFixedMaturityDate() => $_ensure(30);

  @$pb.TagNumber(32)
  $core.int get fixedTermMonths => $_getIZ(31);
  @$pb.TagNumber(32)
  set fixedTermMonths($core.int value) => $_setSignedInt32(31, value);
  @$pb.TagNumber(32)
  $core.bool hasFixedTermMonths() => $_has(31);
  @$pb.TagNumber(32)
  void clearFixedTermMonths() => $_clearField(32);

  @$pb.TagNumber(33)
  $core.String get goldProductType => $_getSZ(32);
  @$pb.TagNumber(33)
  set goldProductType($core.String value) => $_setString(32, value);
  @$pb.TagNumber(33)
  $core.bool hasGoldProductType() => $_has(32);
  @$pb.TagNumber(33)
  void clearGoldProductType() => $_clearField(33);

  @$pb.TagNumber(34)
  $core.double get goldQuantity => $_getN(33);
  @$pb.TagNumber(34)
  set goldQuantity($core.double value) => $_setDouble(33, value);
  @$pb.TagNumber(34)
  $core.bool hasGoldQuantity() => $_has(33);
  @$pb.TagNumber(34)
  void clearGoldQuantity() => $_clearField(34);

  @$pb.TagNumber(35)
  $fixnum.Int64 get goldBuyPriceCents => $_getI64(34);
  @$pb.TagNumber(35)
  set goldBuyPriceCents($fixnum.Int64 value) => $_setInt64(34, value);
  @$pb.TagNumber(35)
  $core.bool hasGoldBuyPriceCents() => $_has(34);
  @$pb.TagNumber(35)
  void clearGoldBuyPriceCents() => $_clearField(35);

  @$pb.TagNumber(36)
  $fixnum.Int64 get goldCurrentPriceCents => $_getI64(35);
  @$pb.TagNumber(36)
  set goldCurrentPriceCents($fixnum.Int64 value) => $_setInt64(35, value);
  @$pb.TagNumber(36)
  $core.bool hasGoldCurrentPriceCents() => $_has(35);
  @$pb.TagNumber(36)
  void clearGoldCurrentPriceCents() => $_clearField(36);

  @$pb.TagNumber(37)
  $fixnum.Int64 get estatePurchasePriceCents => $_getI64(36);
  @$pb.TagNumber(37)
  set estatePurchasePriceCents($fixnum.Int64 value) => $_setInt64(36, value);
  @$pb.TagNumber(37)
  $core.bool hasEstatePurchasePriceCents() => $_has(36);
  @$pb.TagNumber(37)
  void clearEstatePurchasePriceCents() => $_clearField(37);

  @$pb.TagNumber(38)
  $fixnum.Int64 get estateCurrentValueCents => $_getI64(37);
  @$pb.TagNumber(38)
  set estateCurrentValueCents($fixnum.Int64 value) => $_setInt64(37, value);
  @$pb.TagNumber(38)
  $core.bool hasEstateCurrentValueCents() => $_has(37);
  @$pb.TagNumber(38)
  void clearEstateCurrentValueCents() => $_clearField(38);

  @$pb.TagNumber(39)
  $2.Timestamp get estatePurchaseDate => $_getN(38);
  @$pb.TagNumber(39)
  set estatePurchaseDate($2.Timestamp value) => $_setField(39, value);
  @$pb.TagNumber(39)
  $core.bool hasEstatePurchaseDate() => $_has(38);
  @$pb.TagNumber(39)
  void clearEstatePurchaseDate() => $_clearField(39);
  @$pb.TagNumber(39)
  $2.Timestamp ensureEstatePurchaseDate() => $_ensure(38);

  @$pb.TagNumber(40)
  $core.double get estateDepreciationRate => $_getN(39);
  @$pb.TagNumber(40)
  set estateDepreciationRate($core.double value) => $_setDouble(39, value);
  @$pb.TagNumber(40)
  $core.bool hasEstateDepreciationRate() => $_has(39);
  @$pb.TagNumber(40)
  void clearEstateDepreciationRate() => $_clearField(40);

  @$pb.TagNumber(41)
  $fixnum.Int64 get loanOriginalCents => $_getI64(40);
  @$pb.TagNumber(41)
  set loanOriginalCents($fixnum.Int64 value) => $_setInt64(40, value);
  @$pb.TagNumber(41)
  $core.bool hasLoanOriginalCents() => $_has(40);
  @$pb.TagNumber(41)
  void clearLoanOriginalCents() => $_clearField(41);

  @$pb.TagNumber(42)
  $fixnum.Int64 get loanRemainingCents => $_getI64(41);
  @$pb.TagNumber(42)
  set loanRemainingCents($fixnum.Int64 value) => $_setInt64(41, value);
  @$pb.TagNumber(42)
  $core.bool hasLoanRemainingCents() => $_has(41);
  @$pb.TagNumber(42)
  void clearLoanRemainingCents() => $_clearField(42);

  @$pb.TagNumber(43)
  $fixnum.Int64 get loanMonthlyCents => $_getI64(42);
  @$pb.TagNumber(43)
  set loanMonthlyCents($fixnum.Int64 value) => $_setInt64(42, value);
  @$pb.TagNumber(43)
  $core.bool hasLoanMonthlyCents() => $_has(42);
  @$pb.TagNumber(43)
  void clearLoanMonthlyCents() => $_clearField(43);

  @$pb.TagNumber(44)
  $2.Timestamp get loanNextPaymentDate => $_getN(43);
  @$pb.TagNumber(44)
  set loanNextPaymentDate($2.Timestamp value) => $_setField(44, value);
  @$pb.TagNumber(44)
  $core.bool hasLoanNextPaymentDate() => $_has(43);
  @$pb.TagNumber(44)
  void clearLoanNextPaymentDate() => $_clearField(44);
  @$pb.TagNumber(44)
  $2.Timestamp ensureLoanNextPaymentDate() => $_ensure(43);

  @$pb.TagNumber(45)
  $core.bool get isSystem => $_getBF(44);
  @$pb.TagNumber(45)
  set isSystem($core.bool value) => $_setBool(44, value);
  @$pb.TagNumber(45)
  $core.bool hasIsSystem() => $_has(44);
  @$pb.TagNumber(45)
  void clearIsSystem() => $_clearField(45);

  @$pb.TagNumber(46)
  $core.int get sortOrder => $_getIZ(45);
  @$pb.TagNumber(46)
  set sortOrder($core.int value) => $_setSignedInt32(45, value);
  @$pb.TagNumber(46)
  $core.bool hasSortOrder() => $_has(45);
  @$pb.TagNumber(46)
  void clearSortOrder() => $_clearField(46);
}

class CreateAccountRequest extends $pb.GeneratedMessage {
  factory CreateAccountRequest({
    $core.String? name,
    AccountType? accountType,
    $core.String? currencyCode,
    $fixnum.Int64? initialBalanceCents,
    Ownership? ownership,
    $core.String? icon,
    $core.String? color,
    $core.String? chartCode,
    $core.String? parentId,
    $core.String? institution,
    $fixnum.Int64? creditLimitCents,
    AccountCategory? category,
    $core.String? cardNumberTail,
    $core.String? notes,
    $2.Timestamp? openingDate,
    $core.double? interestRate,
    $core.int? creditBillingDay,
    $core.int? creditRepaymentDay,
    $fixnum.Int64? creditAnnualFeeCents,
    $fixnum.Int64? investCostCents,
    $fixnum.Int64? investMarketValueCents,
    $core.double? investReturnYtd,
    $fixnum.Int64? fixedPrincipalCents,
    $2.Timestamp? fixedStartDate,
    $2.Timestamp? fixedMaturityDate,
    $core.int? fixedTermMonths,
    $core.String? goldProductType,
    $core.double? goldQuantity,
    $fixnum.Int64? goldBuyPriceCents,
    $fixnum.Int64? goldCurrentPriceCents,
    $fixnum.Int64? estatePurchasePriceCents,
    $fixnum.Int64? estateCurrentValueCents,
    $2.Timestamp? estatePurchaseDate,
    $core.double? estateDepreciationRate,
    $fixnum.Int64? loanOriginalCents,
    $fixnum.Int64? loanRemainingCents,
    $fixnum.Int64? loanMonthlyCents,
    $2.Timestamp? loanNextPaymentDate,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (accountType != null) result.accountType = accountType;
    if (currencyCode != null) result.currencyCode = currencyCode;
    if (initialBalanceCents != null)
      result.initialBalanceCents = initialBalanceCents;
    if (ownership != null) result.ownership = ownership;
    if (icon != null) result.icon = icon;
    if (color != null) result.color = color;
    if (chartCode != null) result.chartCode = chartCode;
    if (parentId != null) result.parentId = parentId;
    if (institution != null) result.institution = institution;
    if (creditLimitCents != null) result.creditLimitCents = creditLimitCents;
    if (category != null) result.category = category;
    if (cardNumberTail != null) result.cardNumberTail = cardNumberTail;
    if (notes != null) result.notes = notes;
    if (openingDate != null) result.openingDate = openingDate;
    if (interestRate != null) result.interestRate = interestRate;
    if (creditBillingDay != null) result.creditBillingDay = creditBillingDay;
    if (creditRepaymentDay != null)
      result.creditRepaymentDay = creditRepaymentDay;
    if (creditAnnualFeeCents != null)
      result.creditAnnualFeeCents = creditAnnualFeeCents;
    if (investCostCents != null) result.investCostCents = investCostCents;
    if (investMarketValueCents != null)
      result.investMarketValueCents = investMarketValueCents;
    if (investReturnYtd != null) result.investReturnYtd = investReturnYtd;
    if (fixedPrincipalCents != null)
      result.fixedPrincipalCents = fixedPrincipalCents;
    if (fixedStartDate != null) result.fixedStartDate = fixedStartDate;
    if (fixedMaturityDate != null) result.fixedMaturityDate = fixedMaturityDate;
    if (fixedTermMonths != null) result.fixedTermMonths = fixedTermMonths;
    if (goldProductType != null) result.goldProductType = goldProductType;
    if (goldQuantity != null) result.goldQuantity = goldQuantity;
    if (goldBuyPriceCents != null) result.goldBuyPriceCents = goldBuyPriceCents;
    if (goldCurrentPriceCents != null)
      result.goldCurrentPriceCents = goldCurrentPriceCents;
    if (estatePurchasePriceCents != null)
      result.estatePurchasePriceCents = estatePurchasePriceCents;
    if (estateCurrentValueCents != null)
      result.estateCurrentValueCents = estateCurrentValueCents;
    if (estatePurchaseDate != null)
      result.estatePurchaseDate = estatePurchaseDate;
    if (estateDepreciationRate != null)
      result.estateDepreciationRate = estateDepreciationRate;
    if (loanOriginalCents != null) result.loanOriginalCents = loanOriginalCents;
    if (loanRemainingCents != null)
      result.loanRemainingCents = loanRemainingCents;
    if (loanMonthlyCents != null) result.loanMonthlyCents = loanMonthlyCents;
    if (loanNextPaymentDate != null)
      result.loanNextPaymentDate = loanNextPaymentDate;
    return result;
  }

  CreateAccountRequest._();

  factory CreateAccountRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateAccountRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateAccountRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aE<AccountType>(2, _omitFieldNames ? '' : 'accountType',
        enumValues: AccountType.values)
    ..aOS(3, _omitFieldNames ? '' : 'currencyCode')
    ..aInt64(4, _omitFieldNames ? '' : 'initialBalanceCents')
    ..aE<Ownership>(5, _omitFieldNames ? '' : 'ownership',
        enumValues: Ownership.values)
    ..aOS(6, _omitFieldNames ? '' : 'icon')
    ..aOS(7, _omitFieldNames ? '' : 'color')
    ..aOS(8, _omitFieldNames ? '' : 'chartCode')
    ..aOS(9, _omitFieldNames ? '' : 'parentId')
    ..aOS(10, _omitFieldNames ? '' : 'institution')
    ..aInt64(11, _omitFieldNames ? '' : 'creditLimitCents')
    ..aE<AccountCategory>(12, _omitFieldNames ? '' : 'category',
        enumValues: AccountCategory.values)
    ..aOS(13, _omitFieldNames ? '' : 'cardNumberTail')
    ..aOS(14, _omitFieldNames ? '' : 'notes')
    ..aOM<$2.Timestamp>(15, _omitFieldNames ? '' : 'openingDate',
        subBuilder: $2.Timestamp.create)
    ..aD(16, _omitFieldNames ? '' : 'interestRate')
    ..aI(17, _omitFieldNames ? '' : 'creditBillingDay')
    ..aI(18, _omitFieldNames ? '' : 'creditRepaymentDay')
    ..aInt64(19, _omitFieldNames ? '' : 'creditAnnualFeeCents')
    ..aInt64(20, _omitFieldNames ? '' : 'investCostCents')
    ..aInt64(21, _omitFieldNames ? '' : 'investMarketValueCents')
    ..aD(22, _omitFieldNames ? '' : 'investReturnYtd')
    ..aInt64(23, _omitFieldNames ? '' : 'fixedPrincipalCents')
    ..aOM<$2.Timestamp>(24, _omitFieldNames ? '' : 'fixedStartDate',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(25, _omitFieldNames ? '' : 'fixedMaturityDate',
        subBuilder: $2.Timestamp.create)
    ..aI(26, _omitFieldNames ? '' : 'fixedTermMonths')
    ..aOS(27, _omitFieldNames ? '' : 'goldProductType')
    ..aD(28, _omitFieldNames ? '' : 'goldQuantity')
    ..aInt64(29, _omitFieldNames ? '' : 'goldBuyPriceCents')
    ..aInt64(30, _omitFieldNames ? '' : 'goldCurrentPriceCents')
    ..aInt64(31, _omitFieldNames ? '' : 'estatePurchasePriceCents')
    ..aInt64(32, _omitFieldNames ? '' : 'estateCurrentValueCents')
    ..aOM<$2.Timestamp>(33, _omitFieldNames ? '' : 'estatePurchaseDate',
        subBuilder: $2.Timestamp.create)
    ..aD(34, _omitFieldNames ? '' : 'estateDepreciationRate')
    ..aInt64(35, _omitFieldNames ? '' : 'loanOriginalCents')
    ..aInt64(36, _omitFieldNames ? '' : 'loanRemainingCents')
    ..aInt64(37, _omitFieldNames ? '' : 'loanMonthlyCents')
    ..aOM<$2.Timestamp>(38, _omitFieldNames ? '' : 'loanNextPaymentDate',
        subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateAccountRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateAccountRequest copyWith(void Function(CreateAccountRequest) updates) =>
      super.copyWith((message) => updates(message as CreateAccountRequest))
          as CreateAccountRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateAccountRequest create() => CreateAccountRequest._();
  @$core.override
  CreateAccountRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateAccountRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateAccountRequest>(create);
  static CreateAccountRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  AccountType get accountType => $_getN(1);
  @$pb.TagNumber(2)
  set accountType(AccountType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAccountType() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccountType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get currencyCode => $_getSZ(2);
  @$pb.TagNumber(3)
  set currencyCode($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCurrencyCode() => $_has(2);
  @$pb.TagNumber(3)
  void clearCurrencyCode() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get initialBalanceCents => $_getI64(3);
  @$pb.TagNumber(4)
  set initialBalanceCents($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasInitialBalanceCents() => $_has(3);
  @$pb.TagNumber(4)
  void clearInitialBalanceCents() => $_clearField(4);

  @$pb.TagNumber(5)
  Ownership get ownership => $_getN(4);
  @$pb.TagNumber(5)
  set ownership(Ownership value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasOwnership() => $_has(4);
  @$pb.TagNumber(5)
  void clearOwnership() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get icon => $_getSZ(5);
  @$pb.TagNumber(6)
  set icon($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIcon() => $_has(5);
  @$pb.TagNumber(6)
  void clearIcon() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get color => $_getSZ(6);
  @$pb.TagNumber(7)
  set color($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasColor() => $_has(6);
  @$pb.TagNumber(7)
  void clearColor() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get chartCode => $_getSZ(7);
  @$pb.TagNumber(8)
  set chartCode($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasChartCode() => $_has(7);
  @$pb.TagNumber(8)
  void clearChartCode() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get parentId => $_getSZ(8);
  @$pb.TagNumber(9)
  set parentId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasParentId() => $_has(8);
  @$pb.TagNumber(9)
  void clearParentId() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get institution => $_getSZ(9);
  @$pb.TagNumber(10)
  set institution($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasInstitution() => $_has(9);
  @$pb.TagNumber(10)
  void clearInstitution() => $_clearField(10);

  @$pb.TagNumber(11)
  $fixnum.Int64 get creditLimitCents => $_getI64(10);
  @$pb.TagNumber(11)
  set creditLimitCents($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasCreditLimitCents() => $_has(10);
  @$pb.TagNumber(11)
  void clearCreditLimitCents() => $_clearField(11);

  @$pb.TagNumber(12)
  AccountCategory get category => $_getN(11);
  @$pb.TagNumber(12)
  set category(AccountCategory value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasCategory() => $_has(11);
  @$pb.TagNumber(12)
  void clearCategory() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get cardNumberTail => $_getSZ(12);
  @$pb.TagNumber(13)
  set cardNumberTail($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasCardNumberTail() => $_has(12);
  @$pb.TagNumber(13)
  void clearCardNumberTail() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get notes => $_getSZ(13);
  @$pb.TagNumber(14)
  set notes($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasNotes() => $_has(13);
  @$pb.TagNumber(14)
  void clearNotes() => $_clearField(14);

  @$pb.TagNumber(15)
  $2.Timestamp get openingDate => $_getN(14);
  @$pb.TagNumber(15)
  set openingDate($2.Timestamp value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasOpeningDate() => $_has(14);
  @$pb.TagNumber(15)
  void clearOpeningDate() => $_clearField(15);
  @$pb.TagNumber(15)
  $2.Timestamp ensureOpeningDate() => $_ensure(14);

  @$pb.TagNumber(16)
  $core.double get interestRate => $_getN(15);
  @$pb.TagNumber(16)
  set interestRate($core.double value) => $_setDouble(15, value);
  @$pb.TagNumber(16)
  $core.bool hasInterestRate() => $_has(15);
  @$pb.TagNumber(16)
  void clearInterestRate() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.int get creditBillingDay => $_getIZ(16);
  @$pb.TagNumber(17)
  set creditBillingDay($core.int value) => $_setSignedInt32(16, value);
  @$pb.TagNumber(17)
  $core.bool hasCreditBillingDay() => $_has(16);
  @$pb.TagNumber(17)
  void clearCreditBillingDay() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.int get creditRepaymentDay => $_getIZ(17);
  @$pb.TagNumber(18)
  set creditRepaymentDay($core.int value) => $_setSignedInt32(17, value);
  @$pb.TagNumber(18)
  $core.bool hasCreditRepaymentDay() => $_has(17);
  @$pb.TagNumber(18)
  void clearCreditRepaymentDay() => $_clearField(18);

  @$pb.TagNumber(19)
  $fixnum.Int64 get creditAnnualFeeCents => $_getI64(18);
  @$pb.TagNumber(19)
  set creditAnnualFeeCents($fixnum.Int64 value) => $_setInt64(18, value);
  @$pb.TagNumber(19)
  $core.bool hasCreditAnnualFeeCents() => $_has(18);
  @$pb.TagNumber(19)
  void clearCreditAnnualFeeCents() => $_clearField(19);

  @$pb.TagNumber(20)
  $fixnum.Int64 get investCostCents => $_getI64(19);
  @$pb.TagNumber(20)
  set investCostCents($fixnum.Int64 value) => $_setInt64(19, value);
  @$pb.TagNumber(20)
  $core.bool hasInvestCostCents() => $_has(19);
  @$pb.TagNumber(20)
  void clearInvestCostCents() => $_clearField(20);

  @$pb.TagNumber(21)
  $fixnum.Int64 get investMarketValueCents => $_getI64(20);
  @$pb.TagNumber(21)
  set investMarketValueCents($fixnum.Int64 value) => $_setInt64(20, value);
  @$pb.TagNumber(21)
  $core.bool hasInvestMarketValueCents() => $_has(20);
  @$pb.TagNumber(21)
  void clearInvestMarketValueCents() => $_clearField(21);

  @$pb.TagNumber(22)
  $core.double get investReturnYtd => $_getN(21);
  @$pb.TagNumber(22)
  set investReturnYtd($core.double value) => $_setDouble(21, value);
  @$pb.TagNumber(22)
  $core.bool hasInvestReturnYtd() => $_has(21);
  @$pb.TagNumber(22)
  void clearInvestReturnYtd() => $_clearField(22);

  @$pb.TagNumber(23)
  $fixnum.Int64 get fixedPrincipalCents => $_getI64(22);
  @$pb.TagNumber(23)
  set fixedPrincipalCents($fixnum.Int64 value) => $_setInt64(22, value);
  @$pb.TagNumber(23)
  $core.bool hasFixedPrincipalCents() => $_has(22);
  @$pb.TagNumber(23)
  void clearFixedPrincipalCents() => $_clearField(23);

  @$pb.TagNumber(24)
  $2.Timestamp get fixedStartDate => $_getN(23);
  @$pb.TagNumber(24)
  set fixedStartDate($2.Timestamp value) => $_setField(24, value);
  @$pb.TagNumber(24)
  $core.bool hasFixedStartDate() => $_has(23);
  @$pb.TagNumber(24)
  void clearFixedStartDate() => $_clearField(24);
  @$pb.TagNumber(24)
  $2.Timestamp ensureFixedStartDate() => $_ensure(23);

  @$pb.TagNumber(25)
  $2.Timestamp get fixedMaturityDate => $_getN(24);
  @$pb.TagNumber(25)
  set fixedMaturityDate($2.Timestamp value) => $_setField(25, value);
  @$pb.TagNumber(25)
  $core.bool hasFixedMaturityDate() => $_has(24);
  @$pb.TagNumber(25)
  void clearFixedMaturityDate() => $_clearField(25);
  @$pb.TagNumber(25)
  $2.Timestamp ensureFixedMaturityDate() => $_ensure(24);

  @$pb.TagNumber(26)
  $core.int get fixedTermMonths => $_getIZ(25);
  @$pb.TagNumber(26)
  set fixedTermMonths($core.int value) => $_setSignedInt32(25, value);
  @$pb.TagNumber(26)
  $core.bool hasFixedTermMonths() => $_has(25);
  @$pb.TagNumber(26)
  void clearFixedTermMonths() => $_clearField(26);

  @$pb.TagNumber(27)
  $core.String get goldProductType => $_getSZ(26);
  @$pb.TagNumber(27)
  set goldProductType($core.String value) => $_setString(26, value);
  @$pb.TagNumber(27)
  $core.bool hasGoldProductType() => $_has(26);
  @$pb.TagNumber(27)
  void clearGoldProductType() => $_clearField(27);

  @$pb.TagNumber(28)
  $core.double get goldQuantity => $_getN(27);
  @$pb.TagNumber(28)
  set goldQuantity($core.double value) => $_setDouble(27, value);
  @$pb.TagNumber(28)
  $core.bool hasGoldQuantity() => $_has(27);
  @$pb.TagNumber(28)
  void clearGoldQuantity() => $_clearField(28);

  @$pb.TagNumber(29)
  $fixnum.Int64 get goldBuyPriceCents => $_getI64(28);
  @$pb.TagNumber(29)
  set goldBuyPriceCents($fixnum.Int64 value) => $_setInt64(28, value);
  @$pb.TagNumber(29)
  $core.bool hasGoldBuyPriceCents() => $_has(28);
  @$pb.TagNumber(29)
  void clearGoldBuyPriceCents() => $_clearField(29);

  @$pb.TagNumber(30)
  $fixnum.Int64 get goldCurrentPriceCents => $_getI64(29);
  @$pb.TagNumber(30)
  set goldCurrentPriceCents($fixnum.Int64 value) => $_setInt64(29, value);
  @$pb.TagNumber(30)
  $core.bool hasGoldCurrentPriceCents() => $_has(29);
  @$pb.TagNumber(30)
  void clearGoldCurrentPriceCents() => $_clearField(30);

  @$pb.TagNumber(31)
  $fixnum.Int64 get estatePurchasePriceCents => $_getI64(30);
  @$pb.TagNumber(31)
  set estatePurchasePriceCents($fixnum.Int64 value) => $_setInt64(30, value);
  @$pb.TagNumber(31)
  $core.bool hasEstatePurchasePriceCents() => $_has(30);
  @$pb.TagNumber(31)
  void clearEstatePurchasePriceCents() => $_clearField(31);

  @$pb.TagNumber(32)
  $fixnum.Int64 get estateCurrentValueCents => $_getI64(31);
  @$pb.TagNumber(32)
  set estateCurrentValueCents($fixnum.Int64 value) => $_setInt64(31, value);
  @$pb.TagNumber(32)
  $core.bool hasEstateCurrentValueCents() => $_has(31);
  @$pb.TagNumber(32)
  void clearEstateCurrentValueCents() => $_clearField(32);

  @$pb.TagNumber(33)
  $2.Timestamp get estatePurchaseDate => $_getN(32);
  @$pb.TagNumber(33)
  set estatePurchaseDate($2.Timestamp value) => $_setField(33, value);
  @$pb.TagNumber(33)
  $core.bool hasEstatePurchaseDate() => $_has(32);
  @$pb.TagNumber(33)
  void clearEstatePurchaseDate() => $_clearField(33);
  @$pb.TagNumber(33)
  $2.Timestamp ensureEstatePurchaseDate() => $_ensure(32);

  @$pb.TagNumber(34)
  $core.double get estateDepreciationRate => $_getN(33);
  @$pb.TagNumber(34)
  set estateDepreciationRate($core.double value) => $_setDouble(33, value);
  @$pb.TagNumber(34)
  $core.bool hasEstateDepreciationRate() => $_has(33);
  @$pb.TagNumber(34)
  void clearEstateDepreciationRate() => $_clearField(34);

  @$pb.TagNumber(35)
  $fixnum.Int64 get loanOriginalCents => $_getI64(34);
  @$pb.TagNumber(35)
  set loanOriginalCents($fixnum.Int64 value) => $_setInt64(34, value);
  @$pb.TagNumber(35)
  $core.bool hasLoanOriginalCents() => $_has(34);
  @$pb.TagNumber(35)
  void clearLoanOriginalCents() => $_clearField(35);

  @$pb.TagNumber(36)
  $fixnum.Int64 get loanRemainingCents => $_getI64(35);
  @$pb.TagNumber(36)
  set loanRemainingCents($fixnum.Int64 value) => $_setInt64(35, value);
  @$pb.TagNumber(36)
  $core.bool hasLoanRemainingCents() => $_has(35);
  @$pb.TagNumber(36)
  void clearLoanRemainingCents() => $_clearField(36);

  @$pb.TagNumber(37)
  $fixnum.Int64 get loanMonthlyCents => $_getI64(36);
  @$pb.TagNumber(37)
  set loanMonthlyCents($fixnum.Int64 value) => $_setInt64(36, value);
  @$pb.TagNumber(37)
  $core.bool hasLoanMonthlyCents() => $_has(36);
  @$pb.TagNumber(37)
  void clearLoanMonthlyCents() => $_clearField(37);

  @$pb.TagNumber(38)
  $2.Timestamp get loanNextPaymentDate => $_getN(37);
  @$pb.TagNumber(38)
  set loanNextPaymentDate($2.Timestamp value) => $_setField(38, value);
  @$pb.TagNumber(38)
  $core.bool hasLoanNextPaymentDate() => $_has(37);
  @$pb.TagNumber(38)
  void clearLoanNextPaymentDate() => $_clearField(38);
  @$pb.TagNumber(38)
  $2.Timestamp ensureLoanNextPaymentDate() => $_ensure(37);
}

class GetAccountRequest extends $pb.GeneratedMessage {
  factory GetAccountRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  GetAccountRequest._();

  factory GetAccountRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetAccountRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetAccountRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAccountRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAccountRequest copyWith(void Function(GetAccountRequest) updates) =>
      super.copyWith((message) => updates(message as GetAccountRequest))
          as GetAccountRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetAccountRequest create() => GetAccountRequest._();
  @$core.override
  GetAccountRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetAccountRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetAccountRequest>(create);
  static GetAccountRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class ListAccountsRequest extends $pb.GeneratedMessage {
  factory ListAccountsRequest({
    $3.PageRequest? page,
    AccountType? accountType,
    AccountStatus? status,
  }) {
    final result = create();
    if (page != null) result.page = page;
    if (accountType != null) result.accountType = accountType;
    if (status != null) result.status = status;
    return result;
  }

  ListAccountsRequest._();

  factory ListAccountsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListAccountsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListAccountsRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aOM<$3.PageRequest>(1, _omitFieldNames ? '' : 'page',
        subBuilder: $3.PageRequest.create)
    ..aE<AccountType>(2, _omitFieldNames ? '' : 'accountType',
        enumValues: AccountType.values)
    ..aE<AccountStatus>(3, _omitFieldNames ? '' : 'status',
        enumValues: AccountStatus.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAccountsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAccountsRequest copyWith(void Function(ListAccountsRequest) updates) =>
      super.copyWith((message) => updates(message as ListAccountsRequest))
          as ListAccountsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListAccountsRequest create() => ListAccountsRequest._();
  @$core.override
  ListAccountsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListAccountsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListAccountsRequest>(create);
  static ListAccountsRequest? _defaultInstance;

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
  AccountType get accountType => $_getN(1);
  @$pb.TagNumber(2)
  set accountType(AccountType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAccountType() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccountType() => $_clearField(2);

  @$pb.TagNumber(3)
  AccountStatus get status => $_getN(2);
  @$pb.TagNumber(3)
  set status(AccountStatus value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasStatus() => $_has(2);
  @$pb.TagNumber(3)
  void clearStatus() => $_clearField(3);
}

class ListAccountsResponse extends $pb.GeneratedMessage {
  factory ListAccountsResponse({
    $core.Iterable<AccountDTO>? accounts,
    $3.PageResponse? page,
  }) {
    final result = create();
    if (accounts != null) result.accounts.addAll(accounts);
    if (page != null) result.page = page;
    return result;
  }

  ListAccountsResponse._();

  factory ListAccountsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListAccountsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListAccountsResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..pPM<AccountDTO>(1, _omitFieldNames ? '' : 'accounts',
        subBuilder: AccountDTO.create)
    ..aOM<$3.PageResponse>(2, _omitFieldNames ? '' : 'page',
        subBuilder: $3.PageResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAccountsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAccountsResponse copyWith(void Function(ListAccountsResponse) updates) =>
      super.copyWith((message) => updates(message as ListAccountsResponse))
          as ListAccountsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListAccountsResponse create() => ListAccountsResponse._();
  @$core.override
  ListAccountsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListAccountsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListAccountsResponse>(create);
  static ListAccountsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<AccountDTO> get accounts => $_getList(0);

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

class UpdateAccountRequest extends $pb.GeneratedMessage {
  factory UpdateAccountRequest({
    $core.String? id,
    $core.String? name,
    $core.String? icon,
    $core.String? color,
    $core.String? chartCode,
    $core.String? institution,
    $fixnum.Int64? creditLimitCents,
    $fixnum.Int64? version,
    AccountStatus? status,
    $core.String? cardNumberTail,
    $core.String? notes,
    $2.Timestamp? openingDate,
    $core.double? interestRate,
    $core.int? creditBillingDay,
    $core.int? creditRepaymentDay,
    $fixnum.Int64? creditAnnualFeeCents,
    $fixnum.Int64? investCostCents,
    $fixnum.Int64? investMarketValueCents,
    $core.double? investReturnYtd,
    $fixnum.Int64? fixedPrincipalCents,
    $2.Timestamp? fixedStartDate,
    $2.Timestamp? fixedMaturityDate,
    $core.int? fixedTermMonths,
    $core.String? goldProductType,
    $core.double? goldQuantity,
    $fixnum.Int64? goldBuyPriceCents,
    $fixnum.Int64? goldCurrentPriceCents,
    $fixnum.Int64? estatePurchasePriceCents,
    $fixnum.Int64? estateCurrentValueCents,
    $2.Timestamp? estatePurchaseDate,
    $core.double? estateDepreciationRate,
    $fixnum.Int64? loanOriginalCents,
    $fixnum.Int64? loanRemainingCents,
    $fixnum.Int64? loanMonthlyCents,
    $2.Timestamp? loanNextPaymentDate,
    $core.String? parentId,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (icon != null) result.icon = icon;
    if (color != null) result.color = color;
    if (chartCode != null) result.chartCode = chartCode;
    if (institution != null) result.institution = institution;
    if (creditLimitCents != null) result.creditLimitCents = creditLimitCents;
    if (version != null) result.version = version;
    if (status != null) result.status = status;
    if (cardNumberTail != null) result.cardNumberTail = cardNumberTail;
    if (notes != null) result.notes = notes;
    if (openingDate != null) result.openingDate = openingDate;
    if (interestRate != null) result.interestRate = interestRate;
    if (creditBillingDay != null) result.creditBillingDay = creditBillingDay;
    if (creditRepaymentDay != null)
      result.creditRepaymentDay = creditRepaymentDay;
    if (creditAnnualFeeCents != null)
      result.creditAnnualFeeCents = creditAnnualFeeCents;
    if (investCostCents != null) result.investCostCents = investCostCents;
    if (investMarketValueCents != null)
      result.investMarketValueCents = investMarketValueCents;
    if (investReturnYtd != null) result.investReturnYtd = investReturnYtd;
    if (fixedPrincipalCents != null)
      result.fixedPrincipalCents = fixedPrincipalCents;
    if (fixedStartDate != null) result.fixedStartDate = fixedStartDate;
    if (fixedMaturityDate != null) result.fixedMaturityDate = fixedMaturityDate;
    if (fixedTermMonths != null) result.fixedTermMonths = fixedTermMonths;
    if (goldProductType != null) result.goldProductType = goldProductType;
    if (goldQuantity != null) result.goldQuantity = goldQuantity;
    if (goldBuyPriceCents != null) result.goldBuyPriceCents = goldBuyPriceCents;
    if (goldCurrentPriceCents != null)
      result.goldCurrentPriceCents = goldCurrentPriceCents;
    if (estatePurchasePriceCents != null)
      result.estatePurchasePriceCents = estatePurchasePriceCents;
    if (estateCurrentValueCents != null)
      result.estateCurrentValueCents = estateCurrentValueCents;
    if (estatePurchaseDate != null)
      result.estatePurchaseDate = estatePurchaseDate;
    if (estateDepreciationRate != null)
      result.estateDepreciationRate = estateDepreciationRate;
    if (loanOriginalCents != null) result.loanOriginalCents = loanOriginalCents;
    if (loanRemainingCents != null)
      result.loanRemainingCents = loanRemainingCents;
    if (loanMonthlyCents != null) result.loanMonthlyCents = loanMonthlyCents;
    if (loanNextPaymentDate != null)
      result.loanNextPaymentDate = loanNextPaymentDate;
    if (parentId != null) result.parentId = parentId;
    return result;
  }

  UpdateAccountRequest._();

  factory UpdateAccountRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateAccountRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateAccountRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'icon')
    ..aOS(4, _omitFieldNames ? '' : 'color')
    ..aOS(5, _omitFieldNames ? '' : 'chartCode')
    ..aOS(6, _omitFieldNames ? '' : 'institution')
    ..aInt64(7, _omitFieldNames ? '' : 'creditLimitCents')
    ..aInt64(8, _omitFieldNames ? '' : 'version')
    ..aE<AccountStatus>(9, _omitFieldNames ? '' : 'status',
        enumValues: AccountStatus.values)
    ..aOS(10, _omitFieldNames ? '' : 'cardNumberTail')
    ..aOS(11, _omitFieldNames ? '' : 'notes')
    ..aOM<$2.Timestamp>(12, _omitFieldNames ? '' : 'openingDate',
        subBuilder: $2.Timestamp.create)
    ..aD(13, _omitFieldNames ? '' : 'interestRate')
    ..aI(14, _omitFieldNames ? '' : 'creditBillingDay')
    ..aI(15, _omitFieldNames ? '' : 'creditRepaymentDay')
    ..aInt64(16, _omitFieldNames ? '' : 'creditAnnualFeeCents')
    ..aInt64(17, _omitFieldNames ? '' : 'investCostCents')
    ..aInt64(18, _omitFieldNames ? '' : 'investMarketValueCents')
    ..aD(19, _omitFieldNames ? '' : 'investReturnYtd')
    ..aInt64(20, _omitFieldNames ? '' : 'fixedPrincipalCents')
    ..aOM<$2.Timestamp>(21, _omitFieldNames ? '' : 'fixedStartDate',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(22, _omitFieldNames ? '' : 'fixedMaturityDate',
        subBuilder: $2.Timestamp.create)
    ..aI(23, _omitFieldNames ? '' : 'fixedTermMonths')
    ..aOS(24, _omitFieldNames ? '' : 'goldProductType')
    ..aD(25, _omitFieldNames ? '' : 'goldQuantity')
    ..aInt64(26, _omitFieldNames ? '' : 'goldBuyPriceCents')
    ..aInt64(27, _omitFieldNames ? '' : 'goldCurrentPriceCents')
    ..aInt64(28, _omitFieldNames ? '' : 'estatePurchasePriceCents')
    ..aInt64(29, _omitFieldNames ? '' : 'estateCurrentValueCents')
    ..aOM<$2.Timestamp>(30, _omitFieldNames ? '' : 'estatePurchaseDate',
        subBuilder: $2.Timestamp.create)
    ..aD(31, _omitFieldNames ? '' : 'estateDepreciationRate')
    ..aInt64(32, _omitFieldNames ? '' : 'loanOriginalCents')
    ..aInt64(33, _omitFieldNames ? '' : 'loanRemainingCents')
    ..aInt64(34, _omitFieldNames ? '' : 'loanMonthlyCents')
    ..aOM<$2.Timestamp>(35, _omitFieldNames ? '' : 'loanNextPaymentDate',
        subBuilder: $2.Timestamp.create)
    ..aOS(36, _omitFieldNames ? '' : 'parentId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateAccountRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateAccountRequest copyWith(void Function(UpdateAccountRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateAccountRequest))
          as UpdateAccountRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateAccountRequest create() => UpdateAccountRequest._();
  @$core.override
  UpdateAccountRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateAccountRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateAccountRequest>(create);
  static UpdateAccountRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get icon => $_getSZ(2);
  @$pb.TagNumber(3)
  set icon($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIcon() => $_has(2);
  @$pb.TagNumber(3)
  void clearIcon() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get color => $_getSZ(3);
  @$pb.TagNumber(4)
  set color($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasColor() => $_has(3);
  @$pb.TagNumber(4)
  void clearColor() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get chartCode => $_getSZ(4);
  @$pb.TagNumber(5)
  set chartCode($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasChartCode() => $_has(4);
  @$pb.TagNumber(5)
  void clearChartCode() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get institution => $_getSZ(5);
  @$pb.TagNumber(6)
  set institution($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasInstitution() => $_has(5);
  @$pb.TagNumber(6)
  void clearInstitution() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get creditLimitCents => $_getI64(6);
  @$pb.TagNumber(7)
  set creditLimitCents($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCreditLimitCents() => $_has(6);
  @$pb.TagNumber(7)
  void clearCreditLimitCents() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get version => $_getI64(7);
  @$pb.TagNumber(8)
  set version($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasVersion() => $_has(7);
  @$pb.TagNumber(8)
  void clearVersion() => $_clearField(8);

  @$pb.TagNumber(9)
  AccountStatus get status => $_getN(8);
  @$pb.TagNumber(9)
  set status(AccountStatus value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasStatus() => $_has(8);
  @$pb.TagNumber(9)
  void clearStatus() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get cardNumberTail => $_getSZ(9);
  @$pb.TagNumber(10)
  set cardNumberTail($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasCardNumberTail() => $_has(9);
  @$pb.TagNumber(10)
  void clearCardNumberTail() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get notes => $_getSZ(10);
  @$pb.TagNumber(11)
  set notes($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasNotes() => $_has(10);
  @$pb.TagNumber(11)
  void clearNotes() => $_clearField(11);

  @$pb.TagNumber(12)
  $2.Timestamp get openingDate => $_getN(11);
  @$pb.TagNumber(12)
  set openingDate($2.Timestamp value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasOpeningDate() => $_has(11);
  @$pb.TagNumber(12)
  void clearOpeningDate() => $_clearField(12);
  @$pb.TagNumber(12)
  $2.Timestamp ensureOpeningDate() => $_ensure(11);

  @$pb.TagNumber(13)
  $core.double get interestRate => $_getN(12);
  @$pb.TagNumber(13)
  set interestRate($core.double value) => $_setDouble(12, value);
  @$pb.TagNumber(13)
  $core.bool hasInterestRate() => $_has(12);
  @$pb.TagNumber(13)
  void clearInterestRate() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.int get creditBillingDay => $_getIZ(13);
  @$pb.TagNumber(14)
  set creditBillingDay($core.int value) => $_setSignedInt32(13, value);
  @$pb.TagNumber(14)
  $core.bool hasCreditBillingDay() => $_has(13);
  @$pb.TagNumber(14)
  void clearCreditBillingDay() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.int get creditRepaymentDay => $_getIZ(14);
  @$pb.TagNumber(15)
  set creditRepaymentDay($core.int value) => $_setSignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasCreditRepaymentDay() => $_has(14);
  @$pb.TagNumber(15)
  void clearCreditRepaymentDay() => $_clearField(15);

  @$pb.TagNumber(16)
  $fixnum.Int64 get creditAnnualFeeCents => $_getI64(15);
  @$pb.TagNumber(16)
  set creditAnnualFeeCents($fixnum.Int64 value) => $_setInt64(15, value);
  @$pb.TagNumber(16)
  $core.bool hasCreditAnnualFeeCents() => $_has(15);
  @$pb.TagNumber(16)
  void clearCreditAnnualFeeCents() => $_clearField(16);

  @$pb.TagNumber(17)
  $fixnum.Int64 get investCostCents => $_getI64(16);
  @$pb.TagNumber(17)
  set investCostCents($fixnum.Int64 value) => $_setInt64(16, value);
  @$pb.TagNumber(17)
  $core.bool hasInvestCostCents() => $_has(16);
  @$pb.TagNumber(17)
  void clearInvestCostCents() => $_clearField(17);

  @$pb.TagNumber(18)
  $fixnum.Int64 get investMarketValueCents => $_getI64(17);
  @$pb.TagNumber(18)
  set investMarketValueCents($fixnum.Int64 value) => $_setInt64(17, value);
  @$pb.TagNumber(18)
  $core.bool hasInvestMarketValueCents() => $_has(17);
  @$pb.TagNumber(18)
  void clearInvestMarketValueCents() => $_clearField(18);

  @$pb.TagNumber(19)
  $core.double get investReturnYtd => $_getN(18);
  @$pb.TagNumber(19)
  set investReturnYtd($core.double value) => $_setDouble(18, value);
  @$pb.TagNumber(19)
  $core.bool hasInvestReturnYtd() => $_has(18);
  @$pb.TagNumber(19)
  void clearInvestReturnYtd() => $_clearField(19);

  @$pb.TagNumber(20)
  $fixnum.Int64 get fixedPrincipalCents => $_getI64(19);
  @$pb.TagNumber(20)
  set fixedPrincipalCents($fixnum.Int64 value) => $_setInt64(19, value);
  @$pb.TagNumber(20)
  $core.bool hasFixedPrincipalCents() => $_has(19);
  @$pb.TagNumber(20)
  void clearFixedPrincipalCents() => $_clearField(20);

  @$pb.TagNumber(21)
  $2.Timestamp get fixedStartDate => $_getN(20);
  @$pb.TagNumber(21)
  set fixedStartDate($2.Timestamp value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasFixedStartDate() => $_has(20);
  @$pb.TagNumber(21)
  void clearFixedStartDate() => $_clearField(21);
  @$pb.TagNumber(21)
  $2.Timestamp ensureFixedStartDate() => $_ensure(20);

  @$pb.TagNumber(22)
  $2.Timestamp get fixedMaturityDate => $_getN(21);
  @$pb.TagNumber(22)
  set fixedMaturityDate($2.Timestamp value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasFixedMaturityDate() => $_has(21);
  @$pb.TagNumber(22)
  void clearFixedMaturityDate() => $_clearField(22);
  @$pb.TagNumber(22)
  $2.Timestamp ensureFixedMaturityDate() => $_ensure(21);

  @$pb.TagNumber(23)
  $core.int get fixedTermMonths => $_getIZ(22);
  @$pb.TagNumber(23)
  set fixedTermMonths($core.int value) => $_setSignedInt32(22, value);
  @$pb.TagNumber(23)
  $core.bool hasFixedTermMonths() => $_has(22);
  @$pb.TagNumber(23)
  void clearFixedTermMonths() => $_clearField(23);

  @$pb.TagNumber(24)
  $core.String get goldProductType => $_getSZ(23);
  @$pb.TagNumber(24)
  set goldProductType($core.String value) => $_setString(23, value);
  @$pb.TagNumber(24)
  $core.bool hasGoldProductType() => $_has(23);
  @$pb.TagNumber(24)
  void clearGoldProductType() => $_clearField(24);

  @$pb.TagNumber(25)
  $core.double get goldQuantity => $_getN(24);
  @$pb.TagNumber(25)
  set goldQuantity($core.double value) => $_setDouble(24, value);
  @$pb.TagNumber(25)
  $core.bool hasGoldQuantity() => $_has(24);
  @$pb.TagNumber(25)
  void clearGoldQuantity() => $_clearField(25);

  @$pb.TagNumber(26)
  $fixnum.Int64 get goldBuyPriceCents => $_getI64(25);
  @$pb.TagNumber(26)
  set goldBuyPriceCents($fixnum.Int64 value) => $_setInt64(25, value);
  @$pb.TagNumber(26)
  $core.bool hasGoldBuyPriceCents() => $_has(25);
  @$pb.TagNumber(26)
  void clearGoldBuyPriceCents() => $_clearField(26);

  @$pb.TagNumber(27)
  $fixnum.Int64 get goldCurrentPriceCents => $_getI64(26);
  @$pb.TagNumber(27)
  set goldCurrentPriceCents($fixnum.Int64 value) => $_setInt64(26, value);
  @$pb.TagNumber(27)
  $core.bool hasGoldCurrentPriceCents() => $_has(26);
  @$pb.TagNumber(27)
  void clearGoldCurrentPriceCents() => $_clearField(27);

  @$pb.TagNumber(28)
  $fixnum.Int64 get estatePurchasePriceCents => $_getI64(27);
  @$pb.TagNumber(28)
  set estatePurchasePriceCents($fixnum.Int64 value) => $_setInt64(27, value);
  @$pb.TagNumber(28)
  $core.bool hasEstatePurchasePriceCents() => $_has(27);
  @$pb.TagNumber(28)
  void clearEstatePurchasePriceCents() => $_clearField(28);

  @$pb.TagNumber(29)
  $fixnum.Int64 get estateCurrentValueCents => $_getI64(28);
  @$pb.TagNumber(29)
  set estateCurrentValueCents($fixnum.Int64 value) => $_setInt64(28, value);
  @$pb.TagNumber(29)
  $core.bool hasEstateCurrentValueCents() => $_has(28);
  @$pb.TagNumber(29)
  void clearEstateCurrentValueCents() => $_clearField(29);

  @$pb.TagNumber(30)
  $2.Timestamp get estatePurchaseDate => $_getN(29);
  @$pb.TagNumber(30)
  set estatePurchaseDate($2.Timestamp value) => $_setField(30, value);
  @$pb.TagNumber(30)
  $core.bool hasEstatePurchaseDate() => $_has(29);
  @$pb.TagNumber(30)
  void clearEstatePurchaseDate() => $_clearField(30);
  @$pb.TagNumber(30)
  $2.Timestamp ensureEstatePurchaseDate() => $_ensure(29);

  @$pb.TagNumber(31)
  $core.double get estateDepreciationRate => $_getN(30);
  @$pb.TagNumber(31)
  set estateDepreciationRate($core.double value) => $_setDouble(30, value);
  @$pb.TagNumber(31)
  $core.bool hasEstateDepreciationRate() => $_has(30);
  @$pb.TagNumber(31)
  void clearEstateDepreciationRate() => $_clearField(31);

  @$pb.TagNumber(32)
  $fixnum.Int64 get loanOriginalCents => $_getI64(31);
  @$pb.TagNumber(32)
  set loanOriginalCents($fixnum.Int64 value) => $_setInt64(31, value);
  @$pb.TagNumber(32)
  $core.bool hasLoanOriginalCents() => $_has(31);
  @$pb.TagNumber(32)
  void clearLoanOriginalCents() => $_clearField(32);

  @$pb.TagNumber(33)
  $fixnum.Int64 get loanRemainingCents => $_getI64(32);
  @$pb.TagNumber(33)
  set loanRemainingCents($fixnum.Int64 value) => $_setInt64(32, value);
  @$pb.TagNumber(33)
  $core.bool hasLoanRemainingCents() => $_has(32);
  @$pb.TagNumber(33)
  void clearLoanRemainingCents() => $_clearField(33);

  @$pb.TagNumber(34)
  $fixnum.Int64 get loanMonthlyCents => $_getI64(33);
  @$pb.TagNumber(34)
  set loanMonthlyCents($fixnum.Int64 value) => $_setInt64(33, value);
  @$pb.TagNumber(34)
  $core.bool hasLoanMonthlyCents() => $_has(33);
  @$pb.TagNumber(34)
  void clearLoanMonthlyCents() => $_clearField(34);

  @$pb.TagNumber(35)
  $2.Timestamp get loanNextPaymentDate => $_getN(34);
  @$pb.TagNumber(35)
  set loanNextPaymentDate($2.Timestamp value) => $_setField(35, value);
  @$pb.TagNumber(35)
  $core.bool hasLoanNextPaymentDate() => $_has(34);
  @$pb.TagNumber(35)
  void clearLoanNextPaymentDate() => $_clearField(35);
  @$pb.TagNumber(35)
  $2.Timestamp ensureLoanNextPaymentDate() => $_ensure(34);

  /// Optional sub-category parent. nil/empty = unchanged (top-level if setting
  /// for the first time). Mirrors CreateAccountRequest.parent_id so the category
  /// edit path (which rides on UpdateAccount) can persist parent changes.
  @$pb.TagNumber(36)
  $core.String get parentId => $_getSZ(35);
  @$pb.TagNumber(36)
  set parentId($core.String value) => $_setString(35, value);
  @$pb.TagNumber(36)
  $core.bool hasParentId() => $_has(35);
  @$pb.TagNumber(36)
  void clearParentId() => $_clearField(36);
}

class DeleteAccountRequest extends $pb.GeneratedMessage {
  factory DeleteAccountRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteAccountRequest._();

  factory DeleteAccountRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteAccountRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteAccountRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteAccountRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteAccountRequest copyWith(void Function(DeleteAccountRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteAccountRequest))
          as DeleteAccountRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteAccountRequest create() => DeleteAccountRequest._();
  @$core.override
  DeleteAccountRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteAccountRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteAccountRequest>(create);
  static DeleteAccountRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class AccountResponse extends $pb.GeneratedMessage {
  factory AccountResponse({
    AccountDTO? account,
  }) {
    final result = create();
    if (account != null) result.account = account;
    return result;
  }

  AccountResponse._();

  factory AccountResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AccountResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AccountResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aOM<AccountDTO>(1, _omitFieldNames ? '' : 'account',
        subBuilder: AccountDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccountResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccountResponse copyWith(void Function(AccountResponse) updates) =>
      super.copyWith((message) => updates(message as AccountResponse))
          as AccountResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AccountResponse create() => AccountResponse._();
  @$core.override
  AccountResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AccountResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AccountResponse>(create);
  static AccountResponse? _defaultInstance;

  @$pb.TagNumber(1)
  AccountDTO get account => $_getN(0);
  @$pb.TagNumber(1)
  set account(AccountDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAccount() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccount() => $_clearField(1);
  @$pb.TagNumber(1)
  AccountDTO ensureAccount() => $_ensure(0);
}

class FindByAccountTypeRequest extends $pb.GeneratedMessage {
  factory FindByAccountTypeRequest({
    AccountType? accountType,
  }) {
    final result = create();
    if (accountType != null) result.accountType = accountType;
    return result;
  }

  FindByAccountTypeRequest._();

  factory FindByAccountTypeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FindByAccountTypeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FindByAccountTypeRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aE<AccountType>(1, _omitFieldNames ? '' : 'accountType',
        enumValues: AccountType.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FindByAccountTypeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FindByAccountTypeRequest copyWith(
          void Function(FindByAccountTypeRequest) updates) =>
      super.copyWith((message) => updates(message as FindByAccountTypeRequest))
          as FindByAccountTypeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FindByAccountTypeRequest create() => FindByAccountTypeRequest._();
  @$core.override
  FindByAccountTypeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FindByAccountTypeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FindByAccountTypeRequest>(create);
  static FindByAccountTypeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  AccountType get accountType => $_getN(0);
  @$pb.TagNumber(1)
  set accountType(AccountType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAccountType() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccountType() => $_clearField(1);
}

class FindByAccountTypeResponse extends $pb.GeneratedMessage {
  factory FindByAccountTypeResponse({
    $core.Iterable<AccountDTO>? accounts,
  }) {
    final result = create();
    if (accounts != null) result.accounts.addAll(accounts);
    return result;
  }

  FindByAccountTypeResponse._();

  factory FindByAccountTypeResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FindByAccountTypeResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FindByAccountTypeResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..pPM<AccountDTO>(1, _omitFieldNames ? '' : 'accounts',
        subBuilder: AccountDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FindByAccountTypeResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FindByAccountTypeResponse copyWith(
          void Function(FindByAccountTypeResponse) updates) =>
      super.copyWith((message) => updates(message as FindByAccountTypeResponse))
          as FindByAccountTypeResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FindByAccountTypeResponse create() => FindByAccountTypeResponse._();
  @$core.override
  FindByAccountTypeResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FindByAccountTypeResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FindByAccountTypeResponse>(create);
  static FindByAccountTypeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<AccountDTO> get accounts => $_getList(0);
}

class CreateCategoryRequest extends $pb.GeneratedMessage {
  factory CreateCategoryRequest({
    $core.String? name,
    AccountType? accountType,
    $core.String? icon,
    $core.String? color,
    $core.String? parentId,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (accountType != null) result.accountType = accountType;
    if (icon != null) result.icon = icon;
    if (color != null) result.color = color;
    if (parentId != null) result.parentId = parentId;
    return result;
  }

  CreateCategoryRequest._();

  factory CreateCategoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateCategoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateCategoryRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aE<AccountType>(2, _omitFieldNames ? '' : 'accountType',
        enumValues: AccountType.values)
    ..aOS(3, _omitFieldNames ? '' : 'icon')
    ..aOS(4, _omitFieldNames ? '' : 'color')
    ..aOS(5, _omitFieldNames ? '' : 'parentId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateCategoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateCategoryRequest copyWith(
          void Function(CreateCategoryRequest) updates) =>
      super.copyWith((message) => updates(message as CreateCategoryRequest))
          as CreateCategoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateCategoryRequest create() => CreateCategoryRequest._();
  @$core.override
  CreateCategoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateCategoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateCategoryRequest>(create);
  static CreateCategoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  AccountType get accountType => $_getN(1);
  @$pb.TagNumber(2)
  set accountType(AccountType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAccountType() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccountType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get icon => $_getSZ(2);
  @$pb.TagNumber(3)
  set icon($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIcon() => $_has(2);
  @$pb.TagNumber(3)
  void clearIcon() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get color => $_getSZ(3);
  @$pb.TagNumber(4)
  set color($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasColor() => $_has(3);
  @$pb.TagNumber(4)
  void clearColor() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get parentId => $_getSZ(4);
  @$pb.TagNumber(5)
  set parentId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasParentId() => $_has(4);
  @$pb.TagNumber(5)
  void clearParentId() => $_clearField(5);
}

class UpdateCategoryRequest extends $pb.GeneratedMessage {
  factory UpdateCategoryRequest({
    $core.String? id,
    $core.String? name,
    $core.String? icon,
    $core.String? color,
    $core.String? parentId,
    $fixnum.Int64? version,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (icon != null) result.icon = icon;
    if (color != null) result.color = color;
    if (parentId != null) result.parentId = parentId;
    if (version != null) result.version = version;
    return result;
  }

  UpdateCategoryRequest._();

  factory UpdateCategoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateCategoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateCategoryRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'icon')
    ..aOS(4, _omitFieldNames ? '' : 'color')
    ..aOS(5, _omitFieldNames ? '' : 'parentId')
    ..aInt64(6, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateCategoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateCategoryRequest copyWith(
          void Function(UpdateCategoryRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateCategoryRequest))
          as UpdateCategoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateCategoryRequest create() => UpdateCategoryRequest._();
  @$core.override
  UpdateCategoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateCategoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateCategoryRequest>(create);
  static UpdateCategoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get icon => $_getSZ(2);
  @$pb.TagNumber(3)
  set icon($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIcon() => $_has(2);
  @$pb.TagNumber(3)
  void clearIcon() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get color => $_getSZ(3);
  @$pb.TagNumber(4)
  set color($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasColor() => $_has(3);
  @$pb.TagNumber(4)
  void clearColor() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get parentId => $_getSZ(4);
  @$pb.TagNumber(5)
  set parentId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasParentId() => $_has(4);
  @$pb.TagNumber(5)
  void clearParentId() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get version => $_getI64(5);
  @$pb.TagNumber(6)
  set version($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasVersion() => $_has(5);
  @$pb.TagNumber(6)
  void clearVersion() => $_clearField(6);
}

class ReorderCategoriesRequest extends $pb.GeneratedMessage {
  factory ReorderCategoriesRequest({
    AccountType? accountType,
    $core.Iterable<$core.String>? orderedIds,
  }) {
    final result = create();
    if (accountType != null) result.accountType = accountType;
    if (orderedIds != null) result.orderedIds.addAll(orderedIds);
    return result;
  }

  ReorderCategoriesRequest._();

  factory ReorderCategoriesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReorderCategoriesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReorderCategoriesRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aE<AccountType>(1, _omitFieldNames ? '' : 'accountType',
        enumValues: AccountType.values)
    ..pPS(2, _omitFieldNames ? '' : 'orderedIds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReorderCategoriesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReorderCategoriesRequest copyWith(
          void Function(ReorderCategoriesRequest) updates) =>
      super.copyWith((message) => updates(message as ReorderCategoriesRequest))
          as ReorderCategoriesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReorderCategoriesRequest create() => ReorderCategoriesRequest._();
  @$core.override
  ReorderCategoriesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReorderCategoriesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReorderCategoriesRequest>(create);
  static ReorderCategoriesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  AccountType get accountType => $_getN(0);
  @$pb.TagNumber(1)
  set accountType(AccountType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAccountType() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccountType() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get orderedIds => $_getList(1);
}

class DeleteCategoryRequest extends $pb.GeneratedMessage {
  factory DeleteCategoryRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteCategoryRequest._();

  factory DeleteCategoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteCategoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteCategoryRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteCategoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteCategoryRequest copyWith(
          void Function(DeleteCategoryRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteCategoryRequest))
          as DeleteCategoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteCategoryRequest create() => DeleteCategoryRequest._();
  @$core.override
  DeleteCategoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteCategoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteCategoryRequest>(create);
  static DeleteCategoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
