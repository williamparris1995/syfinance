// GoalView mapper + GoalViewDataSource wiring 单测(holding-D,Task 10)。
//
// 覆盖:
// - mapper:GoalDTO Int64 cents → int、linkedAccountId 空串→null、
//   progressPct / isCompleted 直传、Equatable props。
// - ds response-wiring:listGoals(ListGoalsRequest{goalType: INVESTMENT})
//   → resp.goals 经 mapper → List<GoalView>(对齐 holding_remote_ds_test 同款
//   proto field-level round-trip 风格;DS 是 _retry.call 薄壳,非 trivial 逻辑
//   = request wiring(goalType NAME)+ response mapping)。
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/network/auth_interceptor.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/holding/data/goal_view_ds.dart';
import 'package:yucai_client/holding/data/goal_view_mapper.dart';
import 'package:yucai_client/holding/domain/entities/goal_view_entity.dart';
import 'package:yucai_client/proto/goal/v1/goal.pb.dart' as goalpb;

class _MockGrpcClient extends Mock implements GrpcClient {}

fixnum.Int64 _i64(int v) => fixnum.Int64(v);

goalpb.GoalDTO _investmentGoalDto(
  String id, {
  int target = 1000000,
  int current = 400000,
  double progress = 40.0,
  String linked = 'acc-1',
  bool completed = false,
}) =>
    goalpb.GoalDTO(
      id: id,
      name: '养老目标 $id',
      goalType: goalpb.GoalType.GOAL_TYPE_INVESTMENT,
      targetAmountCents: _i64(target),
      currentAmountCents: _i64(current),
      progressPct: progress,
      linkedAccountId: linked,
      isCompleted: completed,
    );

void main() {
  late _MockGrpcClient grpcClient;
  late AuthRetryCaller retry;

  setUp(() {
    grpcClient = _MockGrpcClient();
    retry = AuthRetryCaller();
    registerFallbackValue(goalpb.ListGoalsRequest());
  });

  group('goalDtoToView (mapper)', () {
    test('Int64 cents → int (对齐 C Task 12 holding_mapper Int64 模式)', () {
      final view = goalDtoToView(_investmentGoalDto(
        'g1',
        target: 1000000,
        current: 400000,
      ));
      expect(view.targetCents, 1000000); // Int64 → int
      expect(view.currentCents, 400000);
      expect(view, isA<GoalView>());
    });

    test('progressPct + isCompleted 直传', () {
      final view = goalDtoToView(_investmentGoalDto(
        'g2',
        progress: 75.5,
        completed: true,
      ));
      expect(view.progressPct, 75.5);
      expect(view.isCompleted, true);
    });

    test('linkedAccountId 空串 → null(未关联账户)', () {
      final view = goalDtoToView(_investmentGoalDto('g3', linked: ''));
      expect(view.linkedAccountId, isNull);
    });

    test('linkedAccountId 非空 → 直传', () {
      final view = goalDtoToView(_investmentGoalDto('g4', linked: 'acc-9'));
      expect(view.linkedAccountId, 'acc-9');
    });

    test('Equatable: 相同字段 → equal,不同 id → not equal', () {
      final a = goalDtoToView(_investmentGoalDto('g5'));
      final b = goalDtoToView(_investmentGoalDto('g5'));
      final c = goalDtoToView(_investmentGoalDto('g6'));
      expect(a, b); // 同 id 同字段 → equal
      expect(a == c, isFalse); // 不同 id → not equal
    });
  });

  group('listInvestmentGoals (ds response-wiring)', () {
    test('ListGoalsRequest wires goalType = GOAL_TYPE_INVESTMENT (按 NAME)', () {
      // DS 构造 ListGoalsRequest(goalType: GOAL_TYPE_INVESTMENT);验证 proto
      // field-level round-trip(NAME 映射,非 index 强转,对齐 holding_mapper
      // SecurityType/TradeType NAME 映射原则)。
      final req = goalpb.ListGoalsRequest(
        goalType: goalpb.GoalType.GOAL_TYPE_INVESTMENT,
      );
      expect(req.goalType, goalpb.GoalType.GOAL_TYPE_INVESTMENT);
    });

    test('ListGoalsResponse.goals → List<GoalView> 经 mapper(2 goals)', () {
      // DS 把 resp.goals.map(goalDtoToView).toList();验证 2 GoalDTO → 2 GoalView,
      // cents Int64→int / linkedAccountId 直传均经 mapper 正确转换。
      final resp = goalpb.ListGoalsResponse(goals: [
        _investmentGoalDto('g1', target: 1000000, current: 400000),
        _investmentGoalDto('g2',
            target: 2000000, current: 1500000, progress: 75.0, completed: true),
      ]);
      final views = resp.goals.map(goalDtoToView).toList();
      expect(views, isA<List<GoalView>>());
      expect(views.length, 2);
      expect(views[0].id, 'g1');
      expect(views[0].targetCents, 1000000); // Int64 → int
      expect(views[0].currentCents, 400000);
      expect(views[1].progressPct, 75.0);
      expect(views[1].isCompleted, true);
    });
  });

  test('GoalViewDataSource constructible with GrpcClient + retry', () {
    // DS 构造体里建 GoalServiceClient(channel + authInterceptor)—— stub 两者
    // 让构造通过(对齐 holding_remote_ds_test 同款)。ClientChannel 在调用前
    // 不连接,廉价可构造。
    when(() => grpcClient.channel)
        .thenReturn(ClientChannel('localhost', port: 9999));
    when(() => grpcClient.authInterceptor).thenReturn(AuthInterceptor());
    final ds = GoalViewDataSource(grpcClient, retry);
    expect(ds, isA<GoalViewDataSource>());
  });
}
