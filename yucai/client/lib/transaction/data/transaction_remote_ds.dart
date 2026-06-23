import 'dart:developer' as developer;

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/proto/common/v1/pagination.pb.dart' as common;
import 'package:yucai_client/proto/transaction/v1/transaction.pb.dart' as pb;
import 'package:yucai_client/proto/transaction/v1/transaction.pbgrpc.dart' as grpc;
import 'package:yucai_client/transaction/data/mappers/transaction_mapper.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// Diagnostic tag for transaction-layer logs. Every [debugPrint] in this file
/// is prefixed with `[TXN]` so a runtime crash (which the static config can't
/// surface) shows the exact exception in the console. The repository's `_guard`
/// maps thrown errors to [Failure] for the UI, but during the post-4643811
/// investigation users still reported crashes — these logs let us see whether
/// it's a gRPC error, a proto-decode error, or a null-deref in the mapper.
void _txnLog(String op, Object? e, [StackTrace? st]) {
  final msg = '[TXN] $op failed: $e';
  debugPrint(msg);
  developer.log(msg, name: 'txn.ds', error: e, stackTrace: st);
}

/// Wraps the generated `TransactionServiceClient`. Throws `GrpcError` on
/// failure (caught and mapped to [Failure] by [TransactionRepositoryImpl]).
///
/// Every call is wrapped in [AuthRetryCaller]: a 401 (expired access token)
/// triggers a transparent refresh + single retry, mirroring the account
/// datasource.
@LazySingleton()
class TransactionRemoteDataSource {
  TransactionRemoteDataSource(
    this._grpcClient,
    this._retry,
    TransactionMapper mapper,
  ) : _mapper = mapper {
    _client = grpc.TransactionServiceClient(
      _grpcClient.channel,
      interceptors: [_grpcClient.authInterceptor],
    );
  }

  final GrpcClient _grpcClient;
  final AuthRetryCaller _retry;
  final TransactionMapper _mapper;
  late final grpc.TransactionServiceClient _client;

  Future<Transaction> recordExpense(RecordExpenseParams p) {
    return _retry.call(() async {
      final req = pb.SimpleExpenseRequest(
        transactionDate: formatTxnDate(p.transactionDate),
        description: p.description,
        expenseAccountId: p.expenseAccountId,
        assetAccountId: p.assetAccountId,
        amountCents: Int64(p.amountCents),
        note: p.note,
      );
      if (p.transactionTime.isNotEmpty) req.transactionTime = p.transactionTime;
      final res = await _client.simpleExpense(req);
      return _mapper.toDomain(res.transaction);
    });
  }

  Future<Transaction> recordIncome(RecordIncomeParams p) {
    return _retry.call(() async {
      final req = pb.SimpleIncomeRequest(
        transactionDate: formatTxnDate(p.transactionDate),
        description: p.description,
        assetAccountId: p.assetAccountId,
        incomeAccountId: p.incomeAccountId,
        amountCents: Int64(p.amountCents),
        note: p.note,
      );
      if (p.transactionTime.isNotEmpty) req.transactionTime = p.transactionTime;
      final res = await _client.simpleIncome(req);
      return _mapper.toDomain(res.transaction);
    });
  }

  Future<Transaction> recordTransfer(RecordTransferParams p) {
    return _retry.call(() async {
      final req = pb.SimpleTransferRequest(
        transactionDate: formatTxnDate(p.transactionDate),
        description: p.description,
        fromAccountId: p.fromAccountId,
        toAccountId: p.toAccountId,
        amountCents: Int64(p.amountCents),
        note: p.note,
      );
      if (p.transactionTime.isNotEmpty) req.transactionTime = p.transactionTime;
      final res = await _client.simpleTransfer(req);
      return _mapper.toDomain(res.transaction);
    });
  }

  Future<Transaction> recordTransaction(RecordTransactionParams p) {
    return _retry.call(() async {
      final res = await _client.recordTransaction(pb.RecordTransactionRequest(
        transactionDate: formatTxnDate(p.transactionDate),
        description: p.description,
        entries: p.entries.map(_mapper.entryToProto),
      ));
      return _mapper.toDomain(res.transaction);
    });
  }

  Future<ListTransactionsResult> list(ListTransactionsParams p) {
    return _retry.call(() async {
      final req = pb.ListTransactionsRequest(
        page: common.PageRequest(
          pageSize: p.pageSize,
          pageToken: p.pageToken ?? '',
        ),
      );
      if (p.accountId != null && p.accountId!.isNotEmpty) {
        req.accountId = p.accountId!;
      }
      if (p.dateFrom != null) req.dateFrom = formatTxnDate(p.dateFrom!);
      if (p.dateTo != null) req.dateTo = formatTxnDate(p.dateTo!);
      final res = await _client.listTransactions(req);
      // Defensive mapping: a single malformed row (bad date / decode error)
      // must not poison the whole list — log it and skip. The page otherwise
      // blanks to an error and the user can't see *any* transactions.
      final txns = <Transaction>[];
      for (var i = 0; i < res.transactions.length; i++) {
        try {
          txns.add(_mapper.toDomain(res.transactions[i]));
        } catch (e, st) {
          _txnLog('list.toDomain[$i]', e, st);
        }
      }
      // Server-side type filter not yet in proto (Task 2.1 not landed in
      // client stub); apply client-side so the UI contract is stable.
      final f = p.typeFilter;
      final filtered =
          f != null ? txns.where((t) => inferFlavour(t) == f).toList() : txns;
      return ListTransactionsResult(
        transactions: filtered,
        nextPageToken: res.hasPage() ? res.page.nextPageToken : '',
        totalCount: res.hasPage() ? res.page.totalCount : 0,
      );
    });
  }

  Future<Transaction> getById(String id) {
    return _retry.call(() async {
      final res = await _client.getTransaction(pb.GetTransactionRequest(id: id));
      return _mapper.toDomain(res.transaction);
    });
  }

  Future<Transaction> update(UpdateTransactionParams p) {
    return _retry.call(() async {
      final req = pb.UpdateTransactionRequest(
        id: p.id,
        transactionDate: p.transactionDate != null
            ? formatTxnDate(p.transactionDate!)
            : '',
        description: p.description,
        entries: p.entries.map(_mapper.entryToProto),
        version: Int64(p.version),
      );
      final res = await _client.updateTransaction(req);
      return _mapper.toDomain(res.transaction);
    });
  }

  Future<void> delete(String id) {
    return _retry.call(() async {
      await _client.deleteTransaction(pb.DeleteTransactionRequest(id: id));
    });
  }

  /// Calls the `TransactionSummary` RPC (Task 5.1 + Task 9 scope). Returns
  /// the domain [MonthlySummary]; `year`/`month`/`accountId`/`scope` are
  /// stamped onto the domain object by the mapper since the proto DTO only
  /// carries the totals + per-day breakdown, not the scope.
  ///
  /// **Scope mapping** (client [SummaryScope] → proto `Scope`):
  ///   - [SummaryScope.day]   → `Scope.SCOPE_DAY`
  ///   - [SummaryScope.month] → `Scope.SCOPE_MONTH` (the default)
  ///   - [SummaryScope.year]  → `Scope.SCOPE_YEAR`
  ///
  /// `day` is forwarded only when non-null (meaningful for day scope).
  Future<MonthlySummary> summary(
    int year,
    int month, {
    String? accountId,
    SummaryScope scope = SummaryScope.month,
    int? day,
  }) {
    return _retry.call(() async {
      final req = pb.TransactionSummaryRequest(
        year: year,
        month: month,
        accountId: accountId ?? '',
        scope: _scopeToProto(scope),
      );
      if (day != null) req.day = day;
      final res = await _client.transactionSummary(req);
      final dto = res.hasSummary() ? res.summary : pb.MonthlySummary();
      try {
        return _mapper.summaryToDomain(dto,
            year: year, month: month, scope: scope);
      } catch (e, st) {
        // Mapper crash (e.g. unexpected enum / null field) must not blank the
        // card — fall back to a zeroed summary so the list still renders.
        _txnLog('summary.summaryToDomain', e, st);
        return MonthlySummary(year: year, month: month, scope: scope);
      }
    });
  }
}

/// Maps a client [SummaryScope] to the proto `Scope` enum. Kept as a
/// top-level helper so a future read path (e.g. decoding a stored summary)
/// can re-use it. The proto's `SCOPE_UNSPECIFIED` is never produced here —
/// callers always carry a concrete granularity (defaulting to month).
pb.Scope _scopeToProto(SummaryScope scope) {
  switch (scope) {
    case SummaryScope.day:
      return pb.Scope.SCOPE_DAY;
    case SummaryScope.month:
      return pb.Scope.SCOPE_MONTH;
    case SummaryScope.year:
      return pb.Scope.SCOPE_YEAR;
  }
}
