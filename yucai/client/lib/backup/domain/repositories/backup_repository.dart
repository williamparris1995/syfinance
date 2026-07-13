import 'package:dartz/dartz.dart';

import 'package:yucai_client/backup/domain/entities/backup_entity.dart';
import 'package:yucai_client/core/error/failures.dart';

/// 备份仓库接口（domain 层，不 import proto）。
abstract class BackupRepository {
  Future<Either<Failure, List<Backup>>> list();
  Future<Either<Failure, Backup>> create({required bool encrypted});
  Future<Either<Failure, void>> restore({
    required String id,
    required String password,
  });
  Future<Either<Failure, void>> delete(String id);
}
