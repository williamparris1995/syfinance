import 'package:dartz/dartz.dart';

import 'package:yucai_client/backup/domain/entities/backup_entity.dart';
import 'package:yucai_client/backup/domain/entities/backup_settings_entity.dart';
import 'package:yucai_client/core/error/failures.dart';

/// 备份仓库接口（domain 层，不 import proto）。
abstract class BackupRepository {
  Future<Either<Failure, List<Backup>>> list();
  Future<Either<Failure, Backup>> create({
    required bool encrypted,
    String password = '',
  });
  Future<Either<Failure, void>> restore({
    required String id,
    required String password,
  });
  Future<Either<Failure, void>> delete(String id);

  /// 自动备份配置（P1 Task 5）：读取 tenant 的 AutoBackup + interval。
  Future<Either<Failure, BackupSettings>> getCloudSettings();

  /// 保存自动备份配置（P1 Task 5）：服务端 SaveCloudSettings 仅持久化
  /// AutoBackup + AutoBackupIntervalHours 两个字段。
  Future<Either<Failure, void>> saveCloudSettings(BackupSettings settings);
}
