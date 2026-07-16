import 'package:equatable/equatable.dart';

/// 自动备份配置实体（CloudSettingsDTO 的 AutoBackup 子集）。
///
/// 对应 proto CloudSettingsDTO 的两个 auto-backup 字段：
/// - [autoBackup] ↔ `auto_backup`（是否启用服务端定时备份）
/// - [intervalHours] ↔ `auto_backup_interval_hours`（触发间隔，小时）
///
/// 其他 CloudSettingsDTO 字段（provider / webdav_* / oauth_token）属于
/// 云备份 provider 配置，当前 server 端 SaveCloudSettings 也只持久化
/// 这两个 auto-backup 字段（见 service.go 注释），故 entity 不建模它们 —
/// 客户端 UI 范围内仅 AutoBackup 可配。
class BackupSettings extends Equatable {
  const BackupSettings({
    required this.autoBackup,
    required this.intervalHours,
  });

  /// 默认配置（UI 首次进入、GetCloudSettings 在 tenant 无配置行时服务端
  /// 亦返回零值 — autoBackup=false, interval=0；UI 层 fallback 到 24h）。
  static const disabled = BackupSettings(autoBackup: false, intervalHours: 24);

  final bool autoBackup;
  final int intervalHours;

  @override
  List<Object?> get props => [autoBackup, intervalHours];
}
