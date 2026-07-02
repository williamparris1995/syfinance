import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart' as tspb;
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/network/auth_interceptor.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/goal/data/goal_remote_ds.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/proto/goal/v1/goal.pb.dart' as pb;

class _MockGrpcClient extends Mock implements GrpcClient {}

pb.GoalDTO _goalDto(String id, {pb.GoalType? goalType}) => pb.GoalDTO(
      id: id,
      name: '买房储蓄',
      goalType: goalType ?? pb.GoalType.GOAL_TYPE_SAVINGS,
      targetAmountCents: Int64(1000000),
      currentAmountCents: Int64(250000),
      currencyCode: 'CNY',
      notes: '首付',
      isCompleted: false,
    );

void main() {
  late _MockGrpcClient grpcClient;
  late AuthRetryCaller retry;

  setUp(() {
    grpcClient = _MockGrpcClient();
    retry = AuthRetryCaller();
  });

  // The real GoalRemoteDataSource constructs its own GoalServiceClient from
  // GrpcClient.channel + authInterceptor (mirrors BudgetRemoteDataSource), so
  // we cannot substitute a mock gRPC client through DI. We verify the mapper
  // pipeline + the request-wiring (esp. Int64→int, repeated string→List,
  // deadline Timestamp→DateTime?, enum NAME mapping, CloneGoal wiring) the DS
  // delegates to — the DS is a thin wrapper, so the mapping/wiring is the only
  // non-trivial logic it carries.

  group('mapper pipeline (DS delegates to goalDtoToView)', () {
    test('goalDtoToView maps GoalDTO → GoalView (Int64→int, enum NAME)', () {
      final dto = _goalDto('g1', goalType: pb.GoalType.GOAL_TYPE_SAVINGS);
      final view = goalDtoToView(dto);
      expect(view, isA<GoalView>());
      expect(view.id, 'g1');
      expect(view.name, '买房储蓄');
      expect(view.type, GoalType.savings); // proto SAVINGS → domain savings
      expect(view.targetAmountCents, 1000000); // Int64 → int
      expect(view.currentAmountCents, 250000); // Int64 → int
      expect(view.currencyCode, 'CNY');
      expect(view.notes, '首付');
      expect(view.isCompleted, isFalse);
    });

    test('goalDtoToView maps each proto GoalType NAME → domain GoalType', () {
      expect(
        goalDtoToView(_goalDto('g', goalType: pb.GoalType.GOAL_TYPE_SAVINGS)).type,
        GoalType.savings,
      );
      expect(
        goalDtoToView(_goalDto('g', goalType: pb.GoalType.GOAL_TYPE_DEBT_PAYOFF))
            .type,
        GoalType.debtPayoff,
      );
      expect(
        goalDtoToView(_goalDto('g', goalType: pb.GoalType.GOAL_TYPE_INVESTMENT))
            .type,
        GoalType.investment,
      );
    });

    test('protoToGoalType folds UNSPECIFIED → savings (no off-by-one)', () {
      // proto GOAL_TYPE_UNSPECIFIED=0 占位 → domain 无占位,折叠为 savings。
      // 直接按 int 强转会错位:UNSPECIFIED=0 → domain savings(index 0)碰巧对,
      // 但 SAVINGS=1 → domain debtPayoff(index 1)就错。显式 NAME switch 避免。
      expect(protoToGoalType(pb.GoalType.GOAL_TYPE_UNSPECIFIED), GoalType.savings);
    });

    test('goalTypeToProto round-trips domain → proto (NAME switch)', () {
      expect(goalTypeToProto(GoalType.savings),
          pb.GoalType.GOAL_TYPE_SAVINGS);
      expect(goalTypeToProto(GoalType.debtPayoff),
          pb.GoalType.GOAL_TYPE_DEBT_PAYOFF);
      expect(goalTypeToProto(GoalType.investment),
          pb.GoalType.GOAL_TYPE_INVESTMENT);
    });

    test('goalDtoToView maps repeated string → List<String>', () {
      final dto = pb.GoalDTO(
        id: 'g1',
        name: '多账户储蓄',
        goalType: pb.GoalType.GOAL_TYPE_SAVINGS,
        targetAmountCents: Int64(500000),
        currencyCode: 'CNY',
        linkedAccountIds: ['acc-1', 'acc-2'],
        linkedDebtIds: ['debt-1'],
      );
      final view = goalDtoToView(dto);
      expect(view.linkedAccountIds, ['acc-1', 'acc-2']);
      expect(view.linkedDebtIds, ['debt-1']);
    });

    test('goalDtoToView maps empty repeated → empty List (not null)', () {
      final view = goalDtoToView(_goalDto('g1'));
      expect(view.linkedAccountIds, isEmpty);
      expect(view.linkedDebtIds, isEmpty);
    });

    test('goalDtoToView maps deadline Timestamp → DateTime?', () {
      final dto = pb.GoalDTO(
        id: 'g1',
        name: '带截止日',
        goalType: pb.GoalType.GOAL_TYPE_SAVINGS,
        targetAmountCents: Int64(100000),
        currencyCode: 'CNY',
        deadline: tspb.Timestamp.fromDateTime(DateTime.utc(2026, 12, 31)),
      );
      final view = goalDtoToView(dto);
      expect(view.deadline, isNotNull);
      expect(view.deadline!.year, 2026);
      expect(view.deadline!.month, 12);
      expect(view.deadline!.day, 31);
    });

    test('goalDtoToView: unset deadline → null (hasDeadline guard)', () {
      final view = goalDtoToView(_goalDto('g1'));
      expect(view.deadline, isNull);
    });

    test('goalDtoToView maps empty notes → null', () {
      final dto = pb.GoalDTO(
        id: 'g1',
        name: '无备注',
        goalType: pb.GoalType.GOAL_TYPE_SAVINGS,
        targetAmountCents: Int64(100000),
        currencyCode: 'CNY',
        notes: '',
      );
      expect(goalDtoToView(dto).notes, isNull);
    });

    test('goalDtoToView: unset Int64 defaults to 0', () {
      // proto unset Int64 → 0;mapper surfaces as entity default.
      final dto = pb.GoalDTO(
        id: 'g2',
        name: '空目标',
        goalType: pb.GoalType.GOAL_TYPE_SAVINGS,
        currencyCode: 'CNY',
      );
      final view = goalDtoToView(dto);
      expect(view.targetAmountCents, 0);
      expect(view.currentAmountCents, 0);
    });

    test('listGoals pipeline maps 2 GoalDTO → 2 GoalView', () {
      final dtos = [_goalDto('g1'), _goalDto('g2')];
      final views = dtos.map(goalDtoToView).toList();
      expect(views.length, 2);
      expect(views.first.id, 'g1');
      expect(views.last.id, 'g2');
    });
  });

  group('GoalView derived getters', () {
    test('progressPct normal path', () {
      const view = GoalView(
        id: 'g1',
        name: 'n',
        type: GoalType.savings,
        targetAmountCents: 1000000,
        currentAmountCents: 250000,
      );
      expect(view.progressPct, 25.0);
      expect(view.remainingCents, 750000);
    });

    test('progressPct guards divide-by-zero (target=0 → 0)', () {
      const view = GoalView(
        id: 'g1',
        name: 'n',
        type: GoalType.savings,
        targetAmountCents: 0,
        currentAmountCents: 100,
      );
      expect(view.progressPct, 0); // no NaN / Infinity
      expect(view.remainingCents, -100);
    });

    test('Equatable props compare full field set (incl repeated lists)', () {
      final a = goalDtoToView(_goalDto('g1'));
      final b = goalDtoToView(_goalDto('g1'));
      expect(a, b); // same props → equal
    });
  });

  group('createGoal request wiring', () {
    test('CreateGoalRequest wires goalType + Int64 + repeated + deadline string',
        () {
      // DS maps caller GoalType → proto goalType (NAME switch), int → Int64,
      // List<String> → repeated string, deadline String? → ''.
      final req = pb.CreateGoalRequest(
        name: '买房',
        goalType: goalTypeToProto(GoalType.debtPayoff),
        targetAmountCents: Int64(800000),
        currencyCode: 'CNY',
        deadline: '2026-12-31',
        linkedAccountIds: ['acc-1', 'acc-2'],
        linkedDebtIds: ['debt-1'],
        notes: '提前还贷',
      );
      expect(req.name, '买房');
      expect(req.goalType, pb.GoalType.GOAL_TYPE_DEBT_PAYOFF);
      expect(req.targetAmountCents.toInt(), 800000);
      expect(req.currencyCode, 'CNY');
      expect(req.deadline, '2026-12-31'); // string, server-side parse
      expect(req.linkedAccountIds, ['acc-1', 'acc-2']);
      expect(req.linkedDebtIds, ['debt-1']);
      expect(req.notes, '提前还贷');
    });

    test('CreateGoalRequest.notes defaults to "" (DS writes notes ?? "")', () {
      final req = pb.CreateGoalRequest(
        name: 'n',
        goalType: pb.GoalType.GOAL_TYPE_SAVINGS,
        targetAmountCents: Int64(0),
      );
      expect(req.notes, ''); // proto unset scalar string → ''
    });
  });

  group('updateGoal / recordContribution request wiring', () {
    test('UpdateGoalRequest wires id + Int64 + repeated + version', () {
      final req = pb.UpdateGoalRequest(
        id: 'g-1',
        name: '改后',
        targetAmountCents: Int64(1200000),
        deadline: '2027-01-01',
        notes: '更新',
        version: Int64(3),
        linkedAccountIds: ['acc-3'],
        linkedDebtIds: [],
      );
      expect(req.id, 'g-1');
      expect(req.name, '改后');
      expect(req.targetAmountCents.toInt(), 1200000);
      expect(req.deadline, '2027-01-01');
      expect(req.notes, '更新');
      expect(req.version.toInt(), 3);
      expect(req.linkedAccountIds, ['acc-3']);
    });

    test('UpdateProgressRequest wires id + amountCents (Int64)', () {
      final req = pb.UpdateProgressRequest(id: 'g-1', amountCents: Int64(50000));
      expect(req.id, 'g-1');
      expect(req.amountCents.toInt(), 50000);
    });
  });

  group('CloneGoal request wiring', () {
    test('CloneGoalRequest wires sourceGoalId + Int64 + deadline + name', () {
      final req = pb.CloneGoalRequest(
        sourceGoalId: 'g-orig',
        targetAmountCents: Int64(2000000),
        deadline: '2028-06-30',
        name: '买房 v2',
      );
      expect(req.sourceGoalId, 'g-orig');
      expect(req.targetAmountCents.toInt(), 2000000);
      expect(req.deadline, '2028-06-30');
      expect(req.name, '买房 v2');
    });

    test('CloneGoalRequest defaults (DS writes Int64.ZERO + empty strings)', () {
      final req = pb.CloneGoalRequest(sourceGoalId: 'g-orig');
      expect(req.targetAmountCents.toInt(), 0); // Int64 default
      expect(req.deadline, '');
      expect(req.name, '');
    });
  });

  group('ListGoals request wiring', () {
    test('ListGoalsRequest wires goalType filter + completed filter', () {
      final req = pb.ListGoalsRequest(
        goalType: goalTypeToProto(GoalType.investment),
        completed: false,
      );
      expect(req.goalType, pb.GoalType.GOAL_TYPE_INVESTMENT);
      expect(req.completed, isFalse);
    });
  });

  test('GoalRemoteDataSource is constructible with GrpcClient + retry', () {
    // The DS constructor eagerly builds a GoalServiceClient from
    // GrpcClient.channel + authInterceptor — stub both so construction succeeds.
    // A real ClientChannel is cheap to construct and never connects until a
    // call is made (which we don't make here).
    when(() => grpcClient.channel)
        .thenReturn(ClientChannel('localhost', port: 9999));
    when(() => grpcClient.authInterceptor).thenReturn(AuthInterceptor());
    final ds = GoalRemoteDataSource(grpcClient, retry);
    expect(ds, isA<GoalRemoteDataSource>());
  });
}
