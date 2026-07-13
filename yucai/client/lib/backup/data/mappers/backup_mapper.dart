import 'package:yucai_client/backup/domain/entities/backup_entity.dart';
import 'package:yucai_client/proto/backup/v1/backup.pb.dart' as pb;

/// proto BackupDTO → domain Backup。provider 字段丢弃（本地备份 UI 不用；
/// 见 entity 注释）。sizeBytes Int64 → int（.toInt()，与 holding_mapper 同款，
/// 避免 Int64→int 类型错位）。createdAt 缺失 → null（对齐 DebtMapper.securityToDomain
/// 的 hasCreatedAt 判空）。
class BackupMapper {
  BackupMapper._();

  static Backup toDomain(pb.BackupDTO dto) {
    return Backup(
      id: dto.id,
      filename: dto.filename,
      sizeBytes: dto.sizeBytes.toInt(),
      checksum: dto.checksum,
      encrypted: dto.encrypted,
      auto: dto.auto,
      createdAt: dto.hasCreatedAt() ? dto.createdAt.toDateTime() : null,
    );
  }
}
