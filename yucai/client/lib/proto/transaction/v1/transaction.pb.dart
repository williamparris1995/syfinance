// This is a generated file - do not edit.
//
// Generated from transaction/v1/transaction.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $2;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $0;

import '../../common/v1/pagination.pb.dart' as $1;
import 'transaction.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'transaction.pbenum.dart';

class TransactionDTO extends $pb.GeneratedMessage {
  factory TransactionDTO({
    $core.String? id,
    $core.String? transactionDate,
    $core.String? description,
    $core.Iterable<EntryDTO>? entries,
    $fixnum.Int64? version,
    $0.Timestamp? createdAt,
    $0.Timestamp? updatedAt,
    $core.String? transactionTime,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (transactionDate != null) result.transactionDate = transactionDate;
    if (description != null) result.description = description;
    if (entries != null) result.entries.addAll(entries);
    if (version != null) result.version = version;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    if (transactionTime != null) result.transactionTime = transactionTime;
    return result;
  }

  TransactionDTO._();

  factory TransactionDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TransactionDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransactionDTO',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'yucai.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'transactionDate')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..pPM<EntryDTO>(4, _omitFieldNames ? '' : 'entries',
        subBuilder: EntryDTO.create)
    ..aInt64(5, _omitFieldNames ? '' : 'version')
    ..aOM<$0.Timestamp>(6, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $0.Timestamp.create)
    ..aOM<$0.Timestamp>(7, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $0.Timestamp.create)
    ..aOS(8, _omitFieldNames ? '' : 'transactionTime')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransactionDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransactionDTO copyWith(void Function(TransactionDTO) updates) =>
      super.copyWith((message) => updates(message as TransactionDTO))
          as TransactionDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TransactionDTO create() => TransactionDTO._();
  @$core.override
  TransactionDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TransactionDTO getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransactionDTO>(create);
  static TransactionDTO? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get transactionDate => $_getSZ(1);
  @$pb.TagNumber(2)
  set transactionDate($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTransactionDate() => $_has(1);
  @$pb.TagNumber(2)
  void clearTransactionDate() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<EntryDTO> get entries => $_getList(3);

  @$pb.TagNumber(5)
  $fixnum.Int64 get version => $_getI64(4);
  @$pb.TagNumber(5)
  set version($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasVersion() => $_has(4);
  @$pb.TagNumber(5)
  void clearVersion() => $_clearField(5);

  @$pb.TagNumber(6)
  $0.Timestamp get createdAt => $_getN(5);
  @$pb.TagNumber(6)
  set createdAt($0.Timestamp value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasCreatedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedAt() => $_clearField(6);
  @$pb.TagNumber(6)
  $0.Timestamp ensureCreatedAt() => $_ensure(5);

  @$pb.TagNumber(7)
  $0.Timestamp get updatedAt => $_getN(6);
  @$pb.TagNumber(7)
  set updatedAt($0.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasUpdatedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearUpdatedAt() => $_clearField(7);
  @$pb.TagNumber(7)
  $0.Timestamp ensureUpdatedAt() => $_ensure(6);

  /// Optional wall-clock time the transaction occurred (RFC3339, e.g.
  /// "2026-06-05T19:20:00Z"). Empty when unset (proto3 default).
  @$pb.TagNumber(8)
  $core.String get transactionTime => $_getSZ(7);
  @$pb.TagNumber(8)
  set transactionTime($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTransactionTime() => $_has(7);
  @$pb.TagNumber(8)
  void clearTransactionTime() => $_clearField(8);
}

class EntryDTO extends $pb.GeneratedMessage {
  factory EntryDTO({
    $core.String? id,
    $core.String? accountId,
    $core.String? chartOfAccountCode,
    $fixnum.Int64? debitCents,
    $fixnum.Int64? creditCents,
    $core.String? note,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (accountId != null) result.accountId = accountId;
    if (chartOfAccountCode != null)
      result.chartOfAccountCode = chartOfAccountCode;
    if (debitCents != null) result.debitCents = debitCents;
    if (creditCents != null) result.creditCents = creditCents;
    if (note != null) result.note = note;
    return result;
  }

  EntryDTO._();

  factory EntryDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EntryDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EntryDTO',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'yucai.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'accountId')
    ..aOS(3, _omitFieldNames ? '' : 'chartOfAccountCode')
    ..aInt64(4, _omitFieldNames ? '' : 'debitCents')
    ..aInt64(5, _omitFieldNames ? '' : 'creditCents')
    ..aOS(6, _omitFieldNames ? '' : 'note')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EntryDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EntryDTO copyWith(void Function(EntryDTO) updates) =>
      super.copyWith((message) => updates(message as EntryDTO)) as EntryDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EntryDTO create() => EntryDTO._();
  @$core.override
  EntryDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EntryDTO getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EntryDTO>(create);
  static EntryDTO? _defaultInstance;

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
  $core.String get chartOfAccountCode => $_getSZ(2);
  @$pb.TagNumber(3)
  set chartOfAccountCode($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasChartOfAccountCode() => $_has(2);
  @$pb.TagNumber(3)
  void clearChartOfAccountCode() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get debitCents => $_getI64(3);
  @$pb.TagNumber(4)
  set debitCents($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDebitCents() => $_has(3);
  @$pb.TagNumber(4)
  void clearDebitCents() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get creditCents => $_getI64(4);
  @$pb.TagNumber(5)
  set creditCents($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCreditCents() => $_has(4);
  @$pb.TagNumber(5)
  void clearCreditCents() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get note => $_getSZ(5);
  @$pb.TagNumber(6)
  set note($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNote() => $_has(5);
  @$pb.TagNumber(6)
  void clearNote() => $_clearField(6);
}

class RecordTransactionRequest extends $pb.GeneratedMessage {
  factory RecordTransactionRequest({
    $core.String? transactionDate,
    $core.String? description,
    $core.Iterable<EntryDTO>? entries,
    $core.String? transactionTime,
  }) {
    final result = create();
    if (transactionDate != null) result.transactionDate = transactionDate;
    if (description != null) result.description = description;
    if (entries != null) result.entries.addAll(entries);
    if (transactionTime != null) result.transactionTime = transactionTime;
    return result;
  }

  RecordTransactionRequest._();

  factory RecordTransactionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecordTransactionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecordTransactionRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'yucai.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'transactionDate')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..pPM<EntryDTO>(3, _omitFieldNames ? '' : 'entries',
        subBuilder: EntryDTO.create)
    ..aOS(4, _omitFieldNames ? '' : 'transactionTime')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordTransactionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordTransactionRequest copyWith(
          void Function(RecordTransactionRequest) updates) =>
      super.copyWith((message) => updates(message as RecordTransactionRequest))
          as RecordTransactionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecordTransactionRequest create() => RecordTransactionRequest._();
  @$core.override
  RecordTransactionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecordTransactionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecordTransactionRequest>(create);
  static RecordTransactionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transactionDate => $_getSZ(0);
  @$pb.TagNumber(1)
  set transactionDate($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransactionDate() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransactionDate() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<EntryDTO> get entries => $_getList(2);

  /// Optional wall-clock time the transaction occurred (RFC3339). Empty = unset.
  @$pb.TagNumber(4)
  $core.String get transactionTime => $_getSZ(3);
  @$pb.TagNumber(4)
  set transactionTime($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTransactionTime() => $_has(3);
  @$pb.TagNumber(4)
  void clearTransactionTime() => $_clearField(4);
}

class GetTransactionRequest extends $pb.GeneratedMessage {
  factory GetTransactionRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  GetTransactionRequest._();

  factory GetTransactionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetTransactionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTransactionRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'yucai.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTransactionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTransactionRequest copyWith(
          void Function(GetTransactionRequest) updates) =>
      super.copyWith((message) => updates(message as GetTransactionRequest))
          as GetTransactionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetTransactionRequest create() => GetTransactionRequest._();
  @$core.override
  GetTransactionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetTransactionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetTransactionRequest>(create);
  static GetTransactionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class ListTransactionsRequest extends $pb.GeneratedMessage {
  factory ListTransactionsRequest({
    $1.PageRequest? page,
    $core.String? accountId,
    $core.String? dateFrom,
    $core.String? dateTo,
  }) {
    final result = create();
    if (page != null) result.page = page;
    if (accountId != null) result.accountId = accountId;
    if (dateFrom != null) result.dateFrom = dateFrom;
    if (dateTo != null) result.dateTo = dateTo;
    return result;
  }

  ListTransactionsRequest._();

  factory ListTransactionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListTransactionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListTransactionsRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'yucai.transaction.v1'),
      createEmptyInstance: create)
    ..aOM<$1.PageRequest>(1, _omitFieldNames ? '' : 'page',
        subBuilder: $1.PageRequest.create)
    ..aOS(2, _omitFieldNames ? '' : 'accountId')
    ..aOS(3, _omitFieldNames ? '' : 'dateFrom')
    ..aOS(4, _omitFieldNames ? '' : 'dateTo')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTransactionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTransactionsRequest copyWith(
          void Function(ListTransactionsRequest) updates) =>
      super.copyWith((message) => updates(message as ListTransactionsRequest))
          as ListTransactionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListTransactionsRequest create() => ListTransactionsRequest._();
  @$core.override
  ListTransactionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListTransactionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListTransactionsRequest>(create);
  static ListTransactionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $1.PageRequest get page => $_getN(0);
  @$pb.TagNumber(1)
  set page($1.PageRequest value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPage() => $_has(0);
  @$pb.TagNumber(1)
  void clearPage() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.PageRequest ensurePage() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get accountId => $_getSZ(1);
  @$pb.TagNumber(2)
  set accountId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAccountId() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccountId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get dateFrom => $_getSZ(2);
  @$pb.TagNumber(3)
  set dateFrom($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDateFrom() => $_has(2);
  @$pb.TagNumber(3)
  void clearDateFrom() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get dateTo => $_getSZ(3);
  @$pb.TagNumber(4)
  set dateTo($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDateTo() => $_has(3);
  @$pb.TagNumber(4)
  void clearDateTo() => $_clearField(4);
}

class ListTransactionsResponse extends $pb.GeneratedMessage {
  factory ListTransactionsResponse({
    $core.Iterable<TransactionDTO>? transactions,
    $1.PageResponse? page,
  }) {
    final result = create();
    if (transactions != null) result.transactions.addAll(transactions);
    if (page != null) result.page = page;
    return result;
  }

  ListTransactionsResponse._();

  factory ListTransactionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListTransactionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListTransactionsResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'yucai.transaction.v1'),
      createEmptyInstance: create)
    ..pPM<TransactionDTO>(1, _omitFieldNames ? '' : 'transactions',
        subBuilder: TransactionDTO.create)
    ..aOM<$1.PageResponse>(2, _omitFieldNames ? '' : 'page',
        subBuilder: $1.PageResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTransactionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTransactionsResponse copyWith(
          void Function(ListTransactionsResponse) updates) =>
      super.copyWith((message) => updates(message as ListTransactionsResponse))
          as ListTransactionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListTransactionsResponse create() => ListTransactionsResponse._();
  @$core.override
  ListTransactionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListTransactionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListTransactionsResponse>(create);
  static ListTransactionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<TransactionDTO> get transactions => $_getList(0);

  @$pb.TagNumber(2)
  $1.PageResponse get page => $_getN(1);
  @$pb.TagNumber(2)
  set page($1.PageResponse value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPage() => $_has(1);
  @$pb.TagNumber(2)
  void clearPage() => $_clearField(2);
  @$pb.TagNumber(2)
  $1.PageResponse ensurePage() => $_ensure(1);
}

class UpdateTransactionRequest extends $pb.GeneratedMessage {
  factory UpdateTransactionRequest({
    $core.String? id,
    $core.String? transactionDate,
    $core.String? description,
    $core.Iterable<EntryDTO>? entries,
    $fixnum.Int64? version,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (transactionDate != null) result.transactionDate = transactionDate;
    if (description != null) result.description = description;
    if (entries != null) result.entries.addAll(entries);
    if (version != null) result.version = version;
    return result;
  }

  UpdateTransactionRequest._();

  factory UpdateTransactionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateTransactionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateTransactionRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'yucai.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'transactionDate')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..pPM<EntryDTO>(4, _omitFieldNames ? '' : 'entries',
        subBuilder: EntryDTO.create)
    ..aInt64(5, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTransactionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTransactionRequest copyWith(
          void Function(UpdateTransactionRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateTransactionRequest))
          as UpdateTransactionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateTransactionRequest create() => UpdateTransactionRequest._();
  @$core.override
  UpdateTransactionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateTransactionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateTransactionRequest>(create);
  static UpdateTransactionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get transactionDate => $_getSZ(1);
  @$pb.TagNumber(2)
  set transactionDate($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTransactionDate() => $_has(1);
  @$pb.TagNumber(2)
  void clearTransactionDate() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<EntryDTO> get entries => $_getList(3);

  @$pb.TagNumber(5)
  $fixnum.Int64 get version => $_getI64(4);
  @$pb.TagNumber(5)
  set version($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasVersion() => $_has(4);
  @$pb.TagNumber(5)
  void clearVersion() => $_clearField(5);
}

class DeleteTransactionRequest extends $pb.GeneratedMessage {
  factory DeleteTransactionRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteTransactionRequest._();

  factory DeleteTransactionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteTransactionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteTransactionRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'yucai.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTransactionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTransactionRequest copyWith(
          void Function(DeleteTransactionRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteTransactionRequest))
          as DeleteTransactionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteTransactionRequest create() => DeleteTransactionRequest._();
  @$core.override
  DeleteTransactionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteTransactionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteTransactionRequest>(create);
  static DeleteTransactionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

/// Convenience RPCs — server creates the correct entries
class SimpleIncomeRequest extends $pb.GeneratedMessage {
  factory SimpleIncomeRequest({
    $core.String? transactionDate,
    $core.String? description,
    $core.String? assetAccountId,
    $core.String? incomeAccountId,
    $fixnum.Int64? amountCents,
    $core.String? note,
    $core.String? transactionTime,
  }) {
    final result = create();
    if (transactionDate != null) result.transactionDate = transactionDate;
    if (description != null) result.description = description;
    if (assetAccountId != null) result.assetAccountId = assetAccountId;
    if (incomeAccountId != null) result.incomeAccountId = incomeAccountId;
    if (amountCents != null) result.amountCents = amountCents;
    if (note != null) result.note = note;
    if (transactionTime != null) result.transactionTime = transactionTime;
    return result;
  }

  SimpleIncomeRequest._();

  factory SimpleIncomeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SimpleIncomeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SimpleIncomeRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'yucai.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'transactionDate')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..aOS(3, _omitFieldNames ? '' : 'assetAccountId')
    ..aOS(4, _omitFieldNames ? '' : 'incomeAccountId')
    ..aInt64(5, _omitFieldNames ? '' : 'amountCents')
    ..aOS(6, _omitFieldNames ? '' : 'note')
    ..aOS(7, _omitFieldNames ? '' : 'transactionTime')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SimpleIncomeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SimpleIncomeRequest copyWith(void Function(SimpleIncomeRequest) updates) =>
      super.copyWith((message) => updates(message as SimpleIncomeRequest))
          as SimpleIncomeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SimpleIncomeRequest create() => SimpleIncomeRequest._();
  @$core.override
  SimpleIncomeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SimpleIncomeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SimpleIncomeRequest>(create);
  static SimpleIncomeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transactionDate => $_getSZ(0);
  @$pb.TagNumber(1)
  set transactionDate($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransactionDate() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransactionDate() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get assetAccountId => $_getSZ(2);
  @$pb.TagNumber(3)
  set assetAccountId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAssetAccountId() => $_has(2);
  @$pb.TagNumber(3)
  void clearAssetAccountId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get incomeAccountId => $_getSZ(3);
  @$pb.TagNumber(4)
  set incomeAccountId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIncomeAccountId() => $_has(3);
  @$pb.TagNumber(4)
  void clearIncomeAccountId() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get amountCents => $_getI64(4);
  @$pb.TagNumber(5)
  set amountCents($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAmountCents() => $_has(4);
  @$pb.TagNumber(5)
  void clearAmountCents() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get note => $_getSZ(5);
  @$pb.TagNumber(6)
  set note($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNote() => $_has(5);
  @$pb.TagNumber(6)
  void clearNote() => $_clearField(6);

  /// Optional wall-clock time the transaction occurred (RFC3339). Empty = unset.
  @$pb.TagNumber(7)
  $core.String get transactionTime => $_getSZ(6);
  @$pb.TagNumber(7)
  set transactionTime($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTransactionTime() => $_has(6);
  @$pb.TagNumber(7)
  void clearTransactionTime() => $_clearField(7);
}

class SimpleExpenseRequest extends $pb.GeneratedMessage {
  factory SimpleExpenseRequest({
    $core.String? transactionDate,
    $core.String? description,
    $core.String? expenseAccountId,
    $core.String? assetAccountId,
    $fixnum.Int64? amountCents,
    $core.String? note,
    $core.String? transactionTime,
  }) {
    final result = create();
    if (transactionDate != null) result.transactionDate = transactionDate;
    if (description != null) result.description = description;
    if (expenseAccountId != null) result.expenseAccountId = expenseAccountId;
    if (assetAccountId != null) result.assetAccountId = assetAccountId;
    if (amountCents != null) result.amountCents = amountCents;
    if (note != null) result.note = note;
    if (transactionTime != null) result.transactionTime = transactionTime;
    return result;
  }

  SimpleExpenseRequest._();

  factory SimpleExpenseRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SimpleExpenseRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SimpleExpenseRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'yucai.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'transactionDate')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..aOS(3, _omitFieldNames ? '' : 'expenseAccountId')
    ..aOS(4, _omitFieldNames ? '' : 'assetAccountId')
    ..aInt64(5, _omitFieldNames ? '' : 'amountCents')
    ..aOS(6, _omitFieldNames ? '' : 'note')
    ..aOS(7, _omitFieldNames ? '' : 'transactionTime')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SimpleExpenseRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SimpleExpenseRequest copyWith(void Function(SimpleExpenseRequest) updates) =>
      super.copyWith((message) => updates(message as SimpleExpenseRequest))
          as SimpleExpenseRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SimpleExpenseRequest create() => SimpleExpenseRequest._();
  @$core.override
  SimpleExpenseRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SimpleExpenseRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SimpleExpenseRequest>(create);
  static SimpleExpenseRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transactionDate => $_getSZ(0);
  @$pb.TagNumber(1)
  set transactionDate($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransactionDate() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransactionDate() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get expenseAccountId => $_getSZ(2);
  @$pb.TagNumber(3)
  set expenseAccountId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExpenseAccountId() => $_has(2);
  @$pb.TagNumber(3)
  void clearExpenseAccountId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get assetAccountId => $_getSZ(3);
  @$pb.TagNumber(4)
  set assetAccountId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAssetAccountId() => $_has(3);
  @$pb.TagNumber(4)
  void clearAssetAccountId() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get amountCents => $_getI64(4);
  @$pb.TagNumber(5)
  set amountCents($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAmountCents() => $_has(4);
  @$pb.TagNumber(5)
  void clearAmountCents() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get note => $_getSZ(5);
  @$pb.TagNumber(6)
  set note($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNote() => $_has(5);
  @$pb.TagNumber(6)
  void clearNote() => $_clearField(6);

  /// Optional wall-clock time the transaction occurred (RFC3339). Empty = unset.
  @$pb.TagNumber(7)
  $core.String get transactionTime => $_getSZ(6);
  @$pb.TagNumber(7)
  set transactionTime($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTransactionTime() => $_has(6);
  @$pb.TagNumber(7)
  void clearTransactionTime() => $_clearField(7);
}

class SimpleTransferRequest extends $pb.GeneratedMessage {
  factory SimpleTransferRequest({
    $core.String? transactionDate,
    $core.String? description,
    $core.String? fromAccountId,
    $core.String? toAccountId,
    $fixnum.Int64? amountCents,
    $core.String? note,
    $core.String? transactionTime,
  }) {
    final result = create();
    if (transactionDate != null) result.transactionDate = transactionDate;
    if (description != null) result.description = description;
    if (fromAccountId != null) result.fromAccountId = fromAccountId;
    if (toAccountId != null) result.toAccountId = toAccountId;
    if (amountCents != null) result.amountCents = amountCents;
    if (note != null) result.note = note;
    if (transactionTime != null) result.transactionTime = transactionTime;
    return result;
  }

  SimpleTransferRequest._();

  factory SimpleTransferRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SimpleTransferRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SimpleTransferRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'yucai.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'transactionDate')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..aOS(3, _omitFieldNames ? '' : 'fromAccountId')
    ..aOS(4, _omitFieldNames ? '' : 'toAccountId')
    ..aInt64(5, _omitFieldNames ? '' : 'amountCents')
    ..aOS(6, _omitFieldNames ? '' : 'note')
    ..aOS(7, _omitFieldNames ? '' : 'transactionTime')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SimpleTransferRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SimpleTransferRequest copyWith(
          void Function(SimpleTransferRequest) updates) =>
      super.copyWith((message) => updates(message as SimpleTransferRequest))
          as SimpleTransferRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SimpleTransferRequest create() => SimpleTransferRequest._();
  @$core.override
  SimpleTransferRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SimpleTransferRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SimpleTransferRequest>(create);
  static SimpleTransferRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transactionDate => $_getSZ(0);
  @$pb.TagNumber(1)
  set transactionDate($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransactionDate() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransactionDate() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get fromAccountId => $_getSZ(2);
  @$pb.TagNumber(3)
  set fromAccountId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFromAccountId() => $_has(2);
  @$pb.TagNumber(3)
  void clearFromAccountId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get toAccountId => $_getSZ(3);
  @$pb.TagNumber(4)
  set toAccountId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasToAccountId() => $_has(3);
  @$pb.TagNumber(4)
  void clearToAccountId() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get amountCents => $_getI64(4);
  @$pb.TagNumber(5)
  set amountCents($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAmountCents() => $_has(4);
  @$pb.TagNumber(5)
  void clearAmountCents() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get note => $_getSZ(5);
  @$pb.TagNumber(6)
  set note($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNote() => $_has(5);
  @$pb.TagNumber(6)
  void clearNote() => $_clearField(6);

  /// Optional wall-clock time the transaction occurred (RFC3339). Empty = unset.
  @$pb.TagNumber(7)
  $core.String get transactionTime => $_getSZ(6);
  @$pb.TagNumber(7)
  set transactionTime($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTransactionTime() => $_has(6);
  @$pb.TagNumber(7)
  void clearTransactionTime() => $_clearField(7);
}

class TransactionResponse extends $pb.GeneratedMessage {
  factory TransactionResponse({
    TransactionDTO? transaction,
  }) {
    final result = create();
    if (transaction != null) result.transaction = transaction;
    return result;
  }

  TransactionResponse._();

  factory TransactionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TransactionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransactionResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'yucai.transaction.v1'),
      createEmptyInstance: create)
    ..aOM<TransactionDTO>(1, _omitFieldNames ? '' : 'transaction',
        subBuilder: TransactionDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransactionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransactionResponse copyWith(void Function(TransactionResponse) updates) =>
      super.copyWith((message) => updates(message as TransactionResponse))
          as TransactionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TransactionResponse create() => TransactionResponse._();
  @$core.override
  TransactionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TransactionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransactionResponse>(create);
  static TransactionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  TransactionDTO get transaction => $_getN(0);
  @$pb.TagNumber(1)
  set transaction(TransactionDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTransaction() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransaction() => $_clearField(1);
  @$pb.TagNumber(1)
  TransactionDTO ensureTransaction() => $_ensure(0);
}

class TransactionSummaryRequest extends $pb.GeneratedMessage {
  factory TransactionSummaryRequest({
    $core.int? year,
    $core.int? month,
    $core.String? accountId,
    Scope? scope,
    $core.int? day,
  }) {
    final result = create();
    if (year != null) result.year = year;
    if (month != null) result.month = month;
    if (accountId != null) result.accountId = accountId;
    if (scope != null) result.scope = scope;
    if (day != null) result.day = day;
    return result;
  }

  TransactionSummaryRequest._();

  factory TransactionSummaryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TransactionSummaryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransactionSummaryRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'yucai.transaction.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'year')
    ..aI(2, _omitFieldNames ? '' : 'month')
    ..aOS(3, _omitFieldNames ? '' : 'accountId')
    ..aE<Scope>(4, _omitFieldNames ? '' : 'scope', enumValues: Scope.values)
    ..aI(5, _omitFieldNames ? '' : 'day')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransactionSummaryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransactionSummaryRequest copyWith(
          void Function(TransactionSummaryRequest) updates) =>
      super.copyWith((message) => updates(message as TransactionSummaryRequest))
          as TransactionSummaryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TransactionSummaryRequest create() => TransactionSummaryRequest._();
  @$core.override
  TransactionSummaryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TransactionSummaryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransactionSummaryRequest>(create);
  static TransactionSummaryRequest? _defaultInstance;

  /// Calendar year, e.g. 2026.
  @$pb.TagNumber(1)
  $core.int get year => $_getIZ(0);
  @$pb.TagNumber(1)
  set year($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasYear() => $_has(0);
  @$pb.TagNumber(1)
  void clearYear() => $_clearField(1);

  /// Calendar month, 1-12. Ignored when scope = YEAR.
  @$pb.TagNumber(2)
  $core.int get month => $_getIZ(1);
  @$pb.TagNumber(2)
  set month($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMonth() => $_has(1);
  @$pb.TagNumber(2)
  void clearMonth() => $_clearField(2);

  /// Optional: scope the summary to a single account (account_detail view).
  /// Empty = all accounts.
  @$pb.TagNumber(3)
  $core.String get accountId => $_getSZ(2);
  @$pb.TagNumber(3)
  set accountId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAccountId() => $_has(2);
  @$pb.TagNumber(3)
  void clearAccountId() => $_clearField(3);

  /// Aggregation period. UNSPECIFIED defaults to MONTH for backward compat.
  @$pb.TagNumber(4)
  Scope get scope => $_getN(3);
  @$pb.TagNumber(4)
  set scope(Scope value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasScope() => $_has(3);
  @$pb.TagNumber(4)
  void clearScope() => $_clearField(4);

  /// Calendar day, 1-31. Required when scope = DAY; ignored otherwise.
  @$pb.TagNumber(5)
  $core.int get day => $_getIZ(4);
  @$pb.TagNumber(5)
  set day($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDay() => $_has(4);
  @$pb.TagNumber(5)
  void clearDay() => $_clearField(5);
}

class TransactionSummaryResponse extends $pb.GeneratedMessage {
  factory TransactionSummaryResponse({
    MonthlySummary? summary,
  }) {
    final result = create();
    if (summary != null) result.summary = summary;
    return result;
  }

  TransactionSummaryResponse._();

  factory TransactionSummaryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TransactionSummaryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransactionSummaryResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'yucai.transaction.v1'),
      createEmptyInstance: create)
    ..aOM<MonthlySummary>(1, _omitFieldNames ? '' : 'summary',
        subBuilder: MonthlySummary.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransactionSummaryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransactionSummaryResponse copyWith(
          void Function(TransactionSummaryResponse) updates) =>
      super.copyWith(
              (message) => updates(message as TransactionSummaryResponse))
          as TransactionSummaryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TransactionSummaryResponse create() => TransactionSummaryResponse._();
  @$core.override
  TransactionSummaryResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TransactionSummaryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransactionSummaryResponse>(create);
  static TransactionSummaryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  MonthlySummary get summary => $_getN(0);
  @$pb.TagNumber(1)
  set summary(MonthlySummary value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSummary() => $_has(0);
  @$pb.TagNumber(1)
  void clearSummary() => $_clearField(1);
  @$pb.TagNumber(1)
  MonthlySummary ensureSummary() => $_ensure(0);
}

class MonthlySummary extends $pb.GeneratedMessage {
  factory MonthlySummary({
    $fixnum.Int64? incomeCents,
    $fixnum.Int64? expenseCents,
    $fixnum.Int64? netCents,
    $fixnum.Int64? dailyAvgCents,
    $core.Iterable<DailyItem>? byDay,
  }) {
    final result = create();
    if (incomeCents != null) result.incomeCents = incomeCents;
    if (expenseCents != null) result.expenseCents = expenseCents;
    if (netCents != null) result.netCents = netCents;
    if (dailyAvgCents != null) result.dailyAvgCents = dailyAvgCents;
    if (byDay != null) result.byDay.addAll(byDay);
    return result;
  }

  MonthlySummary._();

  factory MonthlySummary.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MonthlySummary.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MonthlySummary',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'yucai.transaction.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'incomeCents')
    ..aInt64(2, _omitFieldNames ? '' : 'expenseCents')
    ..aInt64(3, _omitFieldNames ? '' : 'netCents')
    ..aInt64(4, _omitFieldNames ? '' : 'dailyAvgCents')
    ..pPM<DailyItem>(5, _omitFieldNames ? '' : 'byDay',
        subBuilder: DailyItem.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MonthlySummary clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MonthlySummary copyWith(void Function(MonthlySummary) updates) =>
      super.copyWith((message) => updates(message as MonthlySummary))
          as MonthlySummary;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MonthlySummary create() => MonthlySummary._();
  @$core.override
  MonthlySummary createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MonthlySummary getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MonthlySummary>(create);
  static MonthlySummary? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get incomeCents => $_getI64(0);
  @$pb.TagNumber(1)
  set incomeCents($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIncomeCents() => $_has(0);
  @$pb.TagNumber(1)
  void clearIncomeCents() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get expenseCents => $_getI64(1);
  @$pb.TagNumber(2)
  set expenseCents($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExpenseCents() => $_has(1);
  @$pb.TagNumber(2)
  void clearExpenseCents() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get netCents => $_getI64(2);
  @$pb.TagNumber(3)
  set netCents($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNetCents() => $_has(2);
  @$pb.TagNumber(3)
  void clearNetCents() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get dailyAvgCents => $_getI64(3);
  @$pb.TagNumber(4)
  set dailyAvgCents($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDailyAvgCents() => $_has(3);
  @$pb.TagNumber(4)
  void clearDailyAvgCents() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<DailyItem> get byDay => $_getList(4);
}

class DailyItem extends $pb.GeneratedMessage {
  factory DailyItem({
    $core.String? date,
    $fixnum.Int64? totalIncome,
    $core.Iterable<CategoryItem>? byCategory,
  }) {
    final result = create();
    if (date != null) result.date = date;
    if (totalIncome != null) result.totalIncome = totalIncome;
    if (byCategory != null) result.byCategory.addAll(byCategory);
    return result;
  }

  DailyItem._();

  factory DailyItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DailyItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DailyItem',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'yucai.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'date')
    ..aInt64(2, _omitFieldNames ? '' : 'totalIncome')
    ..pPM<CategoryItem>(3, _omitFieldNames ? '' : 'byCategory',
        subBuilder: CategoryItem.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DailyItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DailyItem copyWith(void Function(DailyItem) updates) =>
      super.copyWith((message) => updates(message as DailyItem)) as DailyItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DailyItem create() => DailyItem._();
  @$core.override
  DailyItem createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DailyItem getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DailyItem>(create);
  static DailyItem? _defaultInstance;

  /// Calendar day in YYYY-MM-DD form (UTC midnight of the transaction's date).
  @$pb.TagNumber(1)
  $core.String get date => $_getSZ(0);
  @$pb.TagNumber(1)
  set date($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDate() => $_has(0);
  @$pb.TagNumber(1)
  void clearDate() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get totalIncome => $_getI64(1);
  @$pb.TagNumber(2)
  set totalIncome($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalIncome() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalIncome() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<CategoryItem> get byCategory => $_getList(2);
}

class CategoryItem extends $pb.GeneratedMessage {
  factory CategoryItem({
    $core.String? accountId,
    $core.String? name,
    $core.String? accountType,
    $fixnum.Int64? amount,
  }) {
    final result = create();
    if (accountId != null) result.accountId = accountId;
    if (name != null) result.name = name;
    if (accountType != null) result.accountType = accountType;
    if (amount != null) result.amount = amount;
    return result;
  }

  CategoryItem._();

  factory CategoryItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CategoryItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CategoryItem',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'yucai.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'accountId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'accountType')
    ..aInt64(4, _omitFieldNames ? '' : 'amount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CategoryItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CategoryItem copyWith(void Function(CategoryItem) updates) =>
      super.copyWith((message) => updates(message as CategoryItem))
          as CategoryItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CategoryItem create() => CategoryItem._();
  @$core.override
  CategoryItem createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CategoryItem getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CategoryItem>(create);
  static CategoryItem? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get accountId => $_getSZ(0);
  @$pb.TagNumber(1)
  set accountId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccountId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccountId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  /// "income" or "expense".
  @$pb.TagNumber(3)
  $core.String get accountType => $_getSZ(2);
  @$pb.TagNumber(3)
  set accountType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAccountType() => $_has(2);
  @$pb.TagNumber(3)
  void clearAccountType() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get amount => $_getI64(3);
  @$pb.TagNumber(4)
  set amount($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAmount() => $_has(3);
  @$pb.TagNumber(4)
  void clearAmount() => $_clearField(4);
}

/// TransactionService manages double-entry bookkeeping transactions.
class TransactionServiceApi {
  final $pb.RpcClient _client;

  TransactionServiceApi(this._client);

  $async.Future<TransactionResponse> recordTransaction(
          $pb.ClientContext? ctx, RecordTransactionRequest request) =>
      _client.invoke<TransactionResponse>(ctx, 'TransactionService',
          'RecordTransaction', request, TransactionResponse());
  $async.Future<TransactionResponse> getTransaction(
          $pb.ClientContext? ctx, GetTransactionRequest request) =>
      _client.invoke<TransactionResponse>(ctx, 'TransactionService',
          'GetTransaction', request, TransactionResponse());
  $async.Future<ListTransactionsResponse> listTransactions(
          $pb.ClientContext? ctx, ListTransactionsRequest request) =>
      _client.invoke<ListTransactionsResponse>(ctx, 'TransactionService',
          'ListTransactions', request, ListTransactionsResponse());
  $async.Future<TransactionResponse> updateTransaction(
          $pb.ClientContext? ctx, UpdateTransactionRequest request) =>
      _client.invoke<TransactionResponse>(ctx, 'TransactionService',
          'UpdateTransaction', request, TransactionResponse());
  $async.Future<$2.Empty> deleteTransaction(
          $pb.ClientContext? ctx, DeleteTransactionRequest request) =>
      _client.invoke<$2.Empty>(
          ctx, 'TransactionService', 'DeleteTransaction', request, $2.Empty());
  $async.Future<TransactionResponse> simpleIncome(
          $pb.ClientContext? ctx, SimpleIncomeRequest request) =>
      _client.invoke<TransactionResponse>(ctx, 'TransactionService',
          'SimpleIncome', request, TransactionResponse());
  $async.Future<TransactionResponse> simpleExpense(
          $pb.ClientContext? ctx, SimpleExpenseRequest request) =>
      _client.invoke<TransactionResponse>(ctx, 'TransactionService',
          'SimpleExpense', request, TransactionResponse());
  $async.Future<TransactionResponse> simpleTransfer(
          $pb.ClientContext? ctx, SimpleTransferRequest request) =>
      _client.invoke<TransactionResponse>(ctx, 'TransactionService',
          'SimpleTransfer', request, TransactionResponse());

  /// TransactionSummary returns a tenant's monthly income/expense summary,
  /// optionally scoped to one account (account_detail view), broken down by
  /// day and by Income/Expense account (category).
  $async.Future<TransactionSummaryResponse> transactionSummary(
          $pb.ClientContext? ctx, TransactionSummaryRequest request) =>
      _client.invoke<TransactionSummaryResponse>(ctx, 'TransactionService',
          'TransactionSummary', request, TransactionSummaryResponse());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
