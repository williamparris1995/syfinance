import 'package:fixnum/fixnum.dart';
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
      final res = await _client.simpleExpense(pb.SimpleExpenseRequest(
        transactionDate: formatTxnDate(p.transactionDate),
        description: p.description,
        expenseAccountId: p.expenseAccountId,
        assetAccountId: p.assetAccountId,
        amountCents: Int64(p.amountCents),
        note: p.note,
      ));
      return _mapper.toDomain(res.transaction);
    });
  }

  Future<Transaction> recordIncome(RecordIncomeParams p) {
    return _retry.call(() async {
      final res = await _client.simpleIncome(pb.SimpleIncomeRequest(
        transactionDate: formatTxnDate(p.transactionDate),
        description: p.description,
        assetAccountId: p.assetAccountId,
        incomeAccountId: p.incomeAccountId,
        amountCents: Int64(p.amountCents),
        note: p.note,
      ));
      return _mapper.toDomain(res.transaction);
    });
  }

  Future<Transaction> recordTransfer(RecordTransferParams p) {
    return _retry.call(() async {
      final res = await _client.simpleTransfer(pb.SimpleTransferRequest(
        transactionDate: formatTxnDate(p.transactionDate),
        description: p.description,
        fromAccountId: p.fromAccountId,
        toAccountId: p.toAccountId,
        amountCents: Int64(p.amountCents),
        note: p.note,
      ));
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

  Future<List<Transaction>> list(ListTransactionsParams p) {
    return _retry.call(() async {
      final req = pb.ListTransactionsRequest(
        page: common.PageRequest(pageSize: p.pageSize),
      );
      if (p.accountId != null && p.accountId!.isNotEmpty) {
        req.accountId = p.accountId!;
      }
      if (p.dateFrom != null) req.dateFrom = formatTxnDate(p.dateFrom!);
      if (p.dateTo != null) req.dateTo = formatTxnDate(p.dateTo!);
      final res = await _client.listTransactions(req);
      return res.transactions.map(_mapper.toDomain).toList(growable: false);
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
}
