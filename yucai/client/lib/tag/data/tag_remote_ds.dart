import 'package:fixnum/fixnum.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/proto/common/v1/pagination.pb.dart' as common;
import 'package:yucai_client/proto/tag/v1/tag.pb.dart' as pb;
import 'package:yucai_client/proto/tag/v1/tag.pbgrpc.dart' as grpc;
import 'package:yucai_client/tag/data/mappers/tag_mapper.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';

/// 封装生成的 TagServiceClient。抛 GrpcError(repo 层 catch 映射)。
/// 对齐 DebtRemoteDataSource/BackupRemoteDataSource:每 RPC AuthRetryCaller wrap。
@LazySingleton()
class TagRemoteDataSource {
  TagRemoteDataSource(this._grpcClient, this._retry) {
    _client = grpc.TagServiceClient(
      _grpcClient.channel,
      interceptors: [_grpcClient.authInterceptor],
    );
  }

  final GrpcClient _grpcClient;
  final AuthRetryCaller _retry;
  late final grpc.TagServiceClient _client;

  Future<List<Tag>> list() async {
    return _retry.call(() async {
      final res = await _client.listTags(pb.ListTagsRequest(
        page: common.PageRequest(pageSize: 100),
      ));
      return res.tags.map(TagMapper.toDomain).toList();
    });
  }

  Future<Tag> create({required String name, required String color}) async {
    return _retry.call(() async {
      final res = await _client.createTag(pb.CreateTagRequest(name: name, color: color));
      return TagMapper.toDomain(res.tag);
    });
  }

  Future<Tag> update({
    required String id,
    required String name,
    required String color,
    required int version,
  }) async {
    return _retry.call(() async {
      final res = await _client.updateTag(pb.UpdateTagRequest(
        id: id,
        name: name,
        color: color,
        version: Int64(version),
      ));
      return TagMapper.toDomain(res.tag);
    });
  }

  Future<void> delete(String id) async {
    return _retry.call(() async {
      await _client.deleteTag(pb.DeleteTagRequest(id: id));
    });
  }

  Future<void> addTagToTransaction({required String tagId, required String transactionId}) async {
    return _retry.call(() async {
      await _client.addTagToTransaction(
          pb.TagTransactionRequest(tagId: tagId, transactionId: transactionId));
    });
  }

  Future<void> removeTagFromTransaction({required String tagId, required String transactionId}) async {
    return _retry.call(() async {
      await _client.removeTagFromTransaction(
          pb.TagTransactionRequest(tagId: tagId, transactionId: transactionId));
    });
  }

  Future<List<Tag>> getTransactionTags(String transactionId) async {
    return _retry.call(() async {
      final res = await _client.getTransactionTags(
          pb.GetTransactionTagsRequest(transactionId: transactionId));
      return res.tags.map(TagMapper.toDomain).toList();
    });
  }
}
