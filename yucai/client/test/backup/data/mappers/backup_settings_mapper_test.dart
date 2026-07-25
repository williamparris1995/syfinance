import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/backup/data/mappers/backup_settings_mapper.dart';
import 'package:yucai_client/backup/domain/entities/backup_settings_entity.dart';
import 'package:yucai_client/proto/backup/v1/backup.pb.dart' as pb;

void main() {
  group('BackupSettingsMapper.toDomain', () {
    test('maps autoBackup + intervalHours', () {
      final dto = pb.CloudSettingsDTO(autoBackup: true, autoBackupIntervalHours: 48);
      final s = BackupSettingsMapper.toDomain(dto);
      expect(s.autoBackup, true);
      expect(s.intervalHours, 48);
    });

    test('fallbacks interval=0 to 24h (tenant 无配置行时 server 返回零值)', () {
      final dto = pb.CloudSettingsDTO(autoBackup: false, autoBackupIntervalHours: 0);
      final s = BackupSettingsMapper.toDomain(dto);
      expect(s.intervalHours, 24);
      expect(s.autoBackup, false);
    });
  });

  group('BackupSettingsMapper.toProto', () {
    test('fills AutoBackup + intervalHours（与 service 持久化字段一一对应）', () {
      final proto = BackupSettingsMapper.toProto(
        const BackupSettings(autoBackup: true, intervalHours: 12),
      );
      expect(proto.autoBackup, true);
      expect(proto.autoBackupIntervalHours, 12);
    });
  });

  test('round-trip entity → proto → entity keeps AutoBackup fields', () {
    const original = BackupSettings(autoBackup: true, intervalHours: 168);
    final proto = BackupSettingsMapper.toProto(original);
    final back = BackupSettingsMapper.toDomain(proto);
    expect(back, original);
  });
}
