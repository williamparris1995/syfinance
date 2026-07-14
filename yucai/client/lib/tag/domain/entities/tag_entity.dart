import 'package:equatable/equatable.dart';

/// 交易标签实体。对应 proto TagDTO(id/name/color/version)。
class Tag extends Equatable {
  const Tag({
    required this.id,
    required this.name,
    required this.color,
    required this.version,
  });

  final String id;
  final String name;   // 标签名
  final String color;  // #RRGGBB
  final int version;   // proto Int64 → domain int(.toInt())

  @override
  List<Object?> get props => [id, name, color, version];
}
