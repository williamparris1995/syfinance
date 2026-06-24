import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/currency/data/mappers/currency_mapper.dart';
import 'package:yucai_client/currency/domain/entities/currency_entity.dart';
import 'package:yucai_client/proto/common/v1/pagination.pb.dart' as common;
import 'package:yucai_client/proto/currency/v1/currency.pb.dart' as pb;
import 'package:yucai_client/proto/currency/v1/currency.pbgrpc.dart' as grpc;

/// Wraps the generated CurrencyServiceClient. Throws GrpcError on failure
/// (caught and mapped by CurrencyRepositoryImpl).
///
/// `list` is wrapped in AuthRetryCaller: a 401 (expired access token)
/// triggers a transparent refresh + single retry.
@LazySingleton()
class CurrencyRemoteDataSource {
  CurrencyRemoteDataSource(
    this._grpcClient,
    this._retry,
    CurrencyMapper mapper,
  ) : _mapper = mapper {
    _client = grpc.CurrencyServiceClient(
      _grpcClient.channel,
      interceptors: [_grpcClient.authInterceptor],
    );
  }

  final GrpcClient _grpcClient;
  final AuthRetryCaller _retry;
  final CurrencyMapper _mapper;
  late final grpc.CurrencyServiceClient _client;

  Future<List<Currency>> list({bool activeOnly = true}) async {
    return _retry.call(() async {
      final res = await _client.listCurrencies(pb.ListCurrenciesRequest(
        page: common.PageRequest(pageSize: 200),
        activeOnly: activeOnly,
      ));
      return res.currencies.map(_mapper.toDomain).toList();
    });
  }
}
