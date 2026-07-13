import 'package:equatable/equatable.dart';

/// 本地备份实体。对应 proto BackupDTO 的本地展示子集 —— provider 字段不进
/// entity(本地备份 UI 范围内 provider 恒为 LOCAL；云备份后续独立 spec 再扩)。
class Backup extends Equatable {
  const Backup({
    required this.id,
    required this.filename,
    required this.sizeBytes,
    required this.checksum,
    required this.encrypted,
    required this.auto,
    required this.createdAt,
  });

  final String id;
  final String filename;
  final int sizeBytes; // bytes（proto Int64 → domain int，mapper .toInt()）
  final String checksum;
  final bool encrypted; // 加密备份（恢复需 password）
  final bool auto; // server scheduler 自动创建的备份（client 只展示标记）
  final DateTime? createdAt;

  /// 文件大小展示：<1MB 显示 KB（整数），≥1MB 显示 MB（1 位小数）。
  String get sizeDisplay {
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  @override
  List<Object?> get props =>
      [id, filename, sizeBytes, checksum, encrypted, auto, createdAt];
}
