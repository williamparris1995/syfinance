// 常用目标模板(spec §11 ④,client 常量,无 server)。创建时「从模板」快捷预填
// type/target/deadline/name(关联账户/债务仍手选)。
//
// 设计源:OD 原型 + spec §11 ④。4 常用模板覆盖典型储蓄/投资场景。模板与
// GoalFormPage 解耦:GoalFormPage 消费 kGoalTemplates 列表,tap → 预填字段,
// 用户可继续改 type(改则清 _linkedIds 现有逻辑)。
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/goal/domain/entities/goal_entity.dart';

/// 常用目标模板(spec §11 ④,client 常量,无 server)。创建时「从模板」快捷预填。
class GoalTemplate {
  const GoalTemplate({
    required this.name,
    required this.goalType,
    required this.targetAmountCents,
    required this.deadlineMonths,
    required this.description,
    required this.icon,
  });
  final String name;
  final GoalType goalType;
  final int targetAmountCents; // 预设目标额(cents)
  final int deadlineMonths; // 预设期限(月,从今起)
  final String description;
  final IconData icon;
}

/// 4 常用模板(对齐 OD 原型 + spec §11 ④)。
const List<GoalTemplate> kGoalTemplates = [
  GoalTemplate(
    name: '应急基金',
    goalType: GoalType.savings,
    targetAmountCents: 8000000, // ¥80000.00
    deadlineMonths: 12,
    description: '3-6 个月家庭支出储备',
    icon: LucideIcons.piggyBank,
  ),
  GoalTemplate(
    name: '买房首付',
    goalType: GoalType.savings,
    targetAmountCents: 100000000, // ¥1000000.00
    deadlineMonths: 60,
    description: '首付 30% 储蓄目标',
    icon: LucideIcons.home,
  ),
  GoalTemplate(
    name: '教育金',
    goalType: GoalType.investment,
    targetAmountCents: 50000000, // ¥500000.00
    deadlineMonths: 120,
    description: '子女教育投资增值',
    icon: LucideIcons.graduationCap,
  ),
  GoalTemplate(
    name: '退休金',
    goalType: GoalType.investment,
    targetAmountCents: 300000000, // ¥3000000.00
    deadlineMonths: 240,
    description: '退休养老投资组合',
    icon: LucideIcons.palmtree,
  ),
];
