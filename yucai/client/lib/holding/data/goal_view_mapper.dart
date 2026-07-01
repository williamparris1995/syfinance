// GoalView mapper(holding-D,Task 10)—— proto GoalDTO → domain GoalView。
//
// 跨模块映射:holding import goal proto。cents 字段为 proto Int64(getter),
// 用 `.toInt()` 转 domain int —— 对齐 C Task 12 holding_mapper 的 Int64 模式
// (avgCostCents / realizedCents 等同款 `.toInt()`),避免 Int64→int 类型错位。
//
// linked_account_id:proto 标量 string 默认空串,折叠为 null(domain 可空),
// 让 UI 层用 `linkedAccountId != null` 判断是否已关联,无需再比空串。
import 'package:yucai_client/holding/domain/entities/goal_view_entity.dart';
import 'package:yucai_client/proto/goal/v1/goal.pb.dart' as goalpb;

/// GoalDTO → GoalView。cents Int64→int,linkedAccountId 空串→null。
GoalView goalDtoToView(goalpb.GoalDTO dto) {
  return GoalView(
    id: dto.id,
    name: dto.name,
    targetCents: dto.targetAmountCents.toInt(),
    currentCents: dto.currentAmountCents.toInt(),
    progressPct: dto.progressPct,
    linkedAccountId: dto.linkedAccountId.isEmpty ? null : dto.linkedAccountId,
    isCompleted: dto.isCompleted,
  );
}
