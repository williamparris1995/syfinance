import 'package:fixnum/fixnum.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/account/data/mappers/account_mapper.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/proto/account/v1/account.pb.dart' as pb;
import 'package:yucai_client/proto/account/v1/account.pbgrpc.dart' as grpc;
import 'package:yucai_client/proto/common/v1/pagination.pb.dart' as common;

/// Wraps the generated AccountServiceClient. Throws GrpcError on failure
/// (caught and mapped by AccountRepositoryImpl).
///
/// List/Create are wrapped in AuthRetryCaller: a 401 (expired access token)
/// triggers a transparent refresh + single retry.
@LazySingleton()
class AccountRemoteDataSource {
  AccountRemoteDataSource(this._grpcClient, this._retry, AccountMapper mapper)
      : _mapper = mapper {
    _client = grpc.AccountServiceClient(
      _grpcClient.channel,
      interceptors: [_grpcClient.authInterceptor],
    );
  }

  final GrpcClient _grpcClient;
  final AuthRetryCaller _retry;
  final AccountMapper _mapper;
  late final grpc.AccountServiceClient _client;

  Future<List<Account>> list() async {
    return _retry.call(() async {
      final res = await _client.listAccounts(pb.ListAccountsRequest(
        page: common.PageRequest(pageSize: 100),
      ));
      return res.accounts.map(_mapper.toDomain).toList();
    });
  }

  Future<Account> create(CreateAccountParams params) async {
    return _retry.call(() async {
      final res = await _client.createAccount(pb.CreateAccountRequest(
        name: params.name,
        accountType: params.accountType.toProto(),
        category: accountCategoryToProto(params.category),
        currencyCode: params.currencyCode,
        initialBalanceCents: Int64(params.initialBalanceCents),
        ownership: params.ownership.toProto(),
        icon: params.icon,
        color: params.color,
      ));
      return _mapper.toDomain(res.account);
    });
  }

  Future<void> delete(String id) async {
    return _retry.call(() async {
      await _client.deleteAccount(pb.DeleteAccountRequest(id: id));
    });
  }
}
