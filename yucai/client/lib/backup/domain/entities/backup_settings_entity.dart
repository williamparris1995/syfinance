import 'package:equatable/equatable.dart';

/// 自动备份配置实体（CloudSettingsDTO 的 AutoBackup 子集）。
///
/// 对应 proto CloudSettingsDTO 的两个 auto-backup 字段：
/// - [autoBackup] ↔ `auto_backup`（是否启用服务端定时备份）
/// - [intervalHours] ↔ `auto_backup_interval_hours`（触发间隔，小时）
///
/// 云备份（WebDAV/provider）已于 2026-07-25 移除，CloudSettingsDTO 现仅
/// 保留这两个字段；entity 与 proto 一一对应。
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
