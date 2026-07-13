import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/backup/data/mappers/backup_mapper.dart';
import 'package:yucai_client/proto/backup/v1/backup.pb.dart' as pb;

void main() {
  group('BackupMapper.toDomain', () {
    test('maps all scalar fields, createdAt null when absent', () {
      final dto = pb.BackupDTO(
        id: 'b1',
        filename: 'backup-2026-07-13.zip',
        sizeBytes: Int64(1048576),
        checksum: 'abc123',
        encrypted: true,
        auto: true,
      );
      final b = BackupMapper.toDomain(dto);
      expect(b.id, 'b1');
      expect(b.filename, 'backup-2026-07-13.zip');
      expect(b.sizeBytes, 1048576);
      expect(b.checksum, 'abc123');
      expect(b.encrypted, true);
      expect(b.auto, true);
      expect(b.createdAt, isNull);
    });

    test('sizeDisplay KB under 1MB, MB at/above 1MB', () {
      final small = BackupMapper.toDomain(pb.BackupDTO(
        id: 'b',
        filename: 'x',
        sizeBytes: Int64(2048),
        checksum: '',
        encrypted: false,
        auto: false,
      ));
      expect(small.sizeDisplay, '2 KB');

      final mb = BackupMapper.toDomain(pb.BackupDTO(
        id: 'b',
        filename: 'x',
        sizeBytes: Int64(1572864), // 1.5 MB
        checksum: '',
        encrypted: false,
        auto: false,
      ));
      expect(mb.sizeDisplay, '1.5 MB');
    });
  });
}
