import 'package:yucai_client/backup/domain/entities/backup_settings_entity.dart';
import 'package:yucai_client/proto/backup/v1/backup.pb.dart' as pb;

/// proto CloudSettingsDTO ↔ domain BackupSettings（仅 AutoBackup 子集）。
///
/// 其他 CloudSettingsDTO 字段（provider / webdav_* / oauth_token）不在
/// entity 建模 —— 当前 server SaveCloudSettings 仅持久化这两个字段
/// （见 service.go 注释 "only AutoBackup + AutoBackupIntervalHours are
/// stored today"），客户端 UI 范围内仅 AutoBackup 可配。
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

  /// entity → DTO。只填 AutoBackup 两字段；其他字段保持 proto 默认零值
  /// （server 端不持久化它们，发送零值是幂等 noop）。
  static pb.CloudSettingsDTO toProto(BackupSettings settings) {
    return pb.CloudSettingsDTO(
      autoBackup: settings.autoBackup,
      autoBackupIntervalHours: settings.intervalHours,
    );
  }
}
