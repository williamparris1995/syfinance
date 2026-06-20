import 'package:equatable/equatable.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';

/// 用户面向分类类型（管理页 tab：支出分类 / 收入分类）。
/// 与会计 [AccountType] 一一对应（account-as-category）。
enum CategoryType { expense, income }

extension CategoryTypeX on CategoryType {
  String get label => this == CategoryType.expense ? '支出分类' : '收入分类';
  AccountType get accountType =>
      this == CategoryType.expense ? AccountType.expense : AccountType.income;
}

/// 系统预置分类名（服务端 SeedPresetCategories，10 个）。account proto 暂未暴露
/// is_system 字段，用名称匹配作为客户端 workaround —— 见 task-4.2 报告。
/// 一旦 account DTO 增加 is_system，应改为读字段。
const presetCategoryNames = <String>{
  // Expense (6)
  '餐饮', '交通', '购物', '娱乐', '居家', '医疗',
  // Income (4)
  '工资', '兼职', '理财收益', '红包',
};

/// 列表展示用的分类项 = Account + isSystem 派生 + 本月金额（占位）。
///
/// [monthlyAmountCents] 当前为 0 占位（Task 5.2 summary 接真实月度汇总）。
class CategoryItem extends Equatable {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.isSystem,
    required this.version,
    this.icon = '',
    this.color = '',
    this.parentId = '',
    this.monthlyAmountCents = 0,
    this.monthlyAmountReady = false,
  });

  factory CategoryItem.fromAccount(Account a) {
    return CategoryItem(
      id: a.id,
      name: a.name,
      type: a.accountType == AccountType.income
          ? CategoryType.income
          : CategoryType.expense,
      isSystem: presetCategoryNames.contains(a.name),
      version: a.version,
      icon: a.icon,
      color: a.color,
      parentId: a.parentId,
    );
  }

  final String id;
  final String name;
  final CategoryType type;
  final bool isSystem;
  final int version;
  final String icon;
  final String color;
  final String parentId;

  /// 本月金额（分）。占位 0，[monthlyAmountReady]=false 时 UI 显示「待统计」。
  final int monthlyAmountCents;
  final bool monthlyAmountReady;

  CategoryItem copyWith({
    int? monthlyAmountCents,
    bool? monthlyAmountReady,
  }) {
    return CategoryItem(
      id: id,
      name: name,
      type: type,
      isSystem: isSystem,
      version: version,
      icon: icon,
      color: color,
      parentId: parentId,
      monthlyAmountCents: monthlyAmountCents ?? this.monthlyAmountCents,
      monthlyAmountReady: monthlyAmountReady ?? this.monthlyAmountReady,
    );
  }

  @override
  List<Object?> get props => [
        id, name, type, isSystem, version, icon, color, parentId,
        monthlyAmountCents, monthlyAmountReady,
      ];
}

abstract class CategoryState extends Equatable {
  const CategoryState();
  @override
  List<Object?> get props => [];
}

class CategoryInitial extends CategoryState {}

class CategoryLoading extends CategoryState {
  const CategoryLoading(this.type, {this.categories = const []});
  final CategoryType type;
  final List<CategoryItem> categories;
  @override
  List<Object?> get props => [type, categories];
}

class CategoryLoaded extends CategoryState {
  const CategoryLoaded({required this.type, required this.categories});
  final CategoryType type;
  final List<CategoryItem> categories;
  @override
  List<Object?> get props => [type, categories];
}

class CategorySubmitting extends CategoryState {
  const CategorySubmitting({required this.type, required this.categories});
  final CategoryType type;
  final List<CategoryItem> categories;
  @override
  List<Object?> get props => [type, categories];
}

class CategoryError extends CategoryState {
  const CategoryError(this.message, {this.type, this.categories = const []});
  final String message;
  final CategoryType? type;
  final List<CategoryItem> categories;
  @override
  List<Object?> get props => [message, type, categories];
}
