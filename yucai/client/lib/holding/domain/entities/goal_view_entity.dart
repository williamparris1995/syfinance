// GoalView entity(holding-D,Task 10)—— holding 模块消费 goal 数据的只读视图。
//
// 字段对齐 goal.proto GoalDTO(id / name / target_amount_cents /
// current_amount_cents / progress_pct / linked_account_id / is_completed)。
// D-goal **零 DTO 改**,holding 侧仅建一个等宽视图 entity;deadline 在 GoalDTO
// 中存在但 holding 关联场景不需要,故不纳入(若 Task 11 需要再扩)。
//
// 复用方:Task 11 presentation goal_link 把 List<GoalView> 喂给下拉,按
// linked_account 客户端 filter(避免 proto/repo 加 linked_account filter;
// investment goals 数量少,首批客户端 filter 足够)。
import 'package:equatable/equatable.dart';

/// 投资目标只读视图(holding 模块消费 goal 数据的投影)。
///
/// cents 字段为 int(proto Int64 经 mapper `.toInt()`,对齐 C Task 12
/// holding_mapper Int64→int 模式)。[linkedAccountId] 可空(目标未关联账户时
/// 为 null;mapper 把空串折叠为 null)。
class GoalView extends Equatable {
  const GoalView({
    required this.id,
    required this.name,
    required this.targetCents,
    required this.currentCents,
    required this.progressPct,
    this.linkedAccountId,
    this.isCompleted = false,
  });

  final String id;
  final String name;
  final int targetCents;
  final int currentCents;
  final double progressPct;
  final String? linkedAccountId;
  final bool isCompleted;

  @override
  List<Object?> get props => [
        id,
        name,
        targetCents,
        currentCents,
        progressPct,
        linkedAccountId,
        isCompleted,
      ];
}
