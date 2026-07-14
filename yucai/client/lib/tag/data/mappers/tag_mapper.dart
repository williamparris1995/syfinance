import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/proto/tag/v1/tag.pb.dart' as pb;

/// proto TagDTO → domain Tag。version Int64 → int(.toInt(),对齐 debt/backup mapper)。
class TagMapper {
  TagMapper._();

  static Tag toDomain(pb.TagDTO dto) {
    return Tag(
      id: dto.id,
      name: dto.name,
      color: dto.color,
      version: dto.version.toInt(),
    );
  }
}
