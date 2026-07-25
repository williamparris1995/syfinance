import 'package:yucai_client/backup/domain/entities/backup_settings_entity.dart';
import 'package:yucai_client/proto/backup/v1/backup.pb.dart' as pb;

/// proto CloudSettingsDTO ↔ domain BackupSettings（仅 AutoBackup 子集）。
///
/// 云备份 provider/webdav/oauth 字段已于 2026-07-25 从 proto 移除；
/// CloudSettingsDTO 现仅含这两个 auto-backup 字段，entity 与之一一对应。
class BackupSettingsMapper {
  BackupSettingsMapper._();

  /// DTO → entity。interval 为 0（tenant 无配置行时 server 返回零值）
  /// 时 fallback 到 24h（与 UI picker 默认值一致，避免 dropdown 找不到
  /// value 触发断言）。
  static BackupSettings toDomain(pb.CloudSettingsDTO dto) {
    final interval = dto.autoBackupIntervalHours == 0
        ? 24
        : dto.autoBackupIntervalHours;
    return BackupSettings(
      autoBackup: dto.autoBackup,
      intervalHours: interval,
    );
  }

  /// entity → DTO。填 AutoBackup + interval；与 server 持久化字段一一对应。
  static pb.CloudSettingsDTO toProto(BackupSettings settings) {
    return pb.CloudSettingsDTO(
      autoBackup: settings.autoBackup,
      autoBackupIntervalHours: settings.intervalHours,
    );
  }
}
