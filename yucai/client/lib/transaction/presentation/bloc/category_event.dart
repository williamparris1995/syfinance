import 'package:equatable/equatable.dart';

import 'package:yucai_client/transaction/presentation/bloc/category_state.dart';

abstract class CategoryEvent extends Equatable {
  const CategoryEvent();
  @override
  List<Object?> get props => [];
}

/// 加载某类型的分类列表。
class LoadCategoriesRequested extends CategoryEvent {
  const LoadCategoriesRequested(this.type);
  final CategoryType type;
  @override
  List<Object?> get props => [type];
}

/// 新建分类。[id] 为空 → 创建；非空 → 更新。
class SaveCategoryRequested extends CategoryEvent {
  const SaveCategoryRequested({
    required this.type,
    required this.name,
    this.id = '',
    this.version = 0,
    this.icon = '',
    this.color = '',
    this.parentId = '',
  });

  final CategoryType type;
  final String name;
  final String id;
  final int version;
  final String icon;
  final String color;
  final String parentId;

  @override
  List<Object?> get props => [type, name, id, version, icon, color, parentId];
}

/// 删除分类。系统分类（is_system）在 bloc 内被拦截，不触达 RPC。
class DeleteCategoryRequested extends CategoryEvent {
  const DeleteCategoryRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

/// 本地拖动重排序（无服务端 RPC；Task 5 接持久化）。
/// 索引语义遵循 [ReorderableListView]：oldIndex 起始，newIndex 目标
/// （newIndex > oldIndex 时表示向下移）。
class ReorderCategoriesRequested extends CategoryEvent {
  const ReorderCategoriesRequested({required this.oldIndex, required this.newIndex});
  final int oldIndex;
  final int newIndex;
  @override
  List<Object?> get props => [oldIndex, newIndex];
}
