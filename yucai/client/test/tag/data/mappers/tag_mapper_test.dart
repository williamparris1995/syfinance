import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/tag/data/mappers/tag_mapper.dart';
import 'package:yucai_client/proto/tag/v1/tag.pb.dart' as pb;

void main() {
  test('maps all fields', () {
    final dto = pb.TagDTO(
      id: 't1',
      name: '日常',
      color: '#b08d57',
      version: Int64(3),
    );
    final t = TagMapper.toDomain(dto);
    expect(t.id, 't1');
    expect(t.name, '日常');
    expect(t.color, '#b08d57');
    expect(t.version, 3);
  });
}
