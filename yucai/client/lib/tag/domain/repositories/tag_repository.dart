import 'package:dartz/dartz.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';

/// 标签仓库接口(domain 层,不 import proto)。7 method 对齐 TagService 7 RPC。
abstract class TagRepository {
  Future<Either<Failure, List<Tag>>> list();
  Future<Either<Failure, Tag>> create({required String name, required String color});
  Future<Either<Failure, Tag>> update({
    required String id,
    required String name,
    required String color,
    required int version,
  });
  Future<Either<Failure, void>> delete(String id);
  Future<Either<Failure, void>> addTagToTransaction({
    required String tagId,
    required String transactionId,
  });
  Future<Either<Failure, void>> removeTagFromTransaction({
    required String tagId,
    required String transactionId,
  });
  Future<Either<Failure, List<Tag>>> getTransactionTags(String transactionId);
}
