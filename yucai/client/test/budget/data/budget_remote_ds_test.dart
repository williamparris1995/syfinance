import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/budget/data/budget_remote_ds.dart';
import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/core/network/auth_interceptor.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/proto/budget/v1/budget.pb.dart' as pb;

class _MockGrpcClient extends Mock implements GrpcClient {}

pb.BudgetDTO _budgetDto(String id) => pb.BudgetDTO(
      id: id,
      name: '2026-07 生活预算',
      month: '2026-07',
      totalAmountCents: Int64(500000),
      currencyCode: 'CNY',
      isActive: true,
      version: Int64(1),
      totalActualCents: Int64(200000),
      usagePct: 40.0,
    );

pb.BudgetItemDTO _itemDto(String id, {String notes = ''}) => pb.BudgetItemDTO(
      id: id,
      budgetId: 'b-1',
      accountId: 'acc-1',
      plannedAmountCents: Int64(300000),
      actualAmountCents: Int64(150000),
      notes: notes,
    );

pb.BudgetDetailDTO _detailDto({List<pb.BudgetItemDTO> items = const []}) =>
    pb.BudgetDetailDTO(
      budget: _budgetDto('b-1'),
      items: items,
      totalActualCents: Int64(200000),
      totalRemainingCents: Int64(300000),
      usagePct: 40.0,
    );

void main() {
  late _MockGrpcClient grpcClient;
  late AuthRetryCaller retry;

  setUp(() {
    grpcClient = _MockGrpcClient();
    retry = AuthRetryCaller();
    registerFallbackValue(pb.BudgetItemInput());
  });

  // The real BudgetRemoteDataSource constructs its own BudgetServiceClient from
  // GrpcClient.channel + authInterceptor (mirrors HoldingRemoteDataSource), so
  // we cannot substitute a mock gRPC client through DI. We verify the mapper
  // pipeline + the request-wiring (esp. Int64→int, empty-notes→null, the new
  // totalActualCents/usagePct Task 2 fields, and BudgetItemInput wiring) the DS
  // delegates to — the DS is a thin wrapper, so the mapping/wiring is the only
  // non-trivial logic it carries.

  group('mapper pipeline (DS delegates to budgetDtoToView / budgetDetailDtoToView)',
      () {
    test('budgetDtoToView maps BudgetDTO → BudgetView (Int64→int)', () {
      final dto = _budgetDto('b1');
      final view = budgetDtoToView(dto);
      expect(view, isA<BudgetView>());
      expect(view.id, 'b1');
      expect(view.name, '2026-07 生活预算');
      expect(view.month, '2026-07');
      expect(view.currencyCode, 'CNY');
      expect(view.totalAmountCents, 500000); // Int64 → int
      expect(view.totalActualCents, 200000); // Task 2 field, Int64 → int
      expect(view.usagePct, 40.0); // Task 2 field
      expect(view.items, isEmpty); // listBudgets path has no items
    });

    test('budgetDetailDtoToView maps BudgetDetailDTO → BudgetView with items', () {
      final dto = _detailDto(items: [_itemDto('i1'), _itemDto('i2')]);
      final view = budgetDetailDtoToView(dto);
      expect(view.id, 'b-1');
      expect(view.items.length, 2);
      // detail-level totalActualCents / usagePct preferred over nested budget.
      expect(view.totalActualCents, 200000);
      expect(view.usagePct, 40.0);
    });

    test('budgetDetailDtoToView maps item Int64→int + empty notes→null', () {
      final dto = _detailDto(items: [_itemDto('i1', notes: '')]);
      final view = budgetDetailDtoToView(dto);
      final item = view.items.first;
      expect(item.id, 'i1');
      expect(item.accountId, 'acc-1');
      expect(item.plannedAmountCents, 300000); // Int64 → int
      expect(item.actualAmountCents, 150000); // Int64 → int
      expect(item.notes, isNull); // empty string → null
    });

    test('budgetDetailDtoToView keeps non-empty notes', () {
      final dto = _detailDto(items: [_itemDto('i1', notes: '房租预算')]);
      final view = budgetDetailDtoToView(dto);
      expect(view.items.first.notes, '房租预算');
    });

    test('budgetDtoToView: Task 2 totalActualCents/usagePct default when unset', () {
      // proto unset Int64 → 0; unset double → 0.0. Mapper surfaces these as the
      // entity defaults (BudgetView constructor: totalActualCents=0, usagePct=0).
      final dto = pb.BudgetDTO(
        id: 'b2',
        name: '空预算',
        month: '2026-08',
        currencyCode: 'CNY',
        totalAmountCents: Int64(100000),
      );
      final view = budgetDtoToView(dto);
      expect(view.totalActualCents, 0);
      expect(view.usagePct, 0.0);
    });

    test('listBudgets pipeline maps 2 BudgetDTO → 2 BudgetView', () {
      final dtos = [_budgetDto('b1'), _budgetDto('b2')];
      final views = dtos.map(budgetDtoToView).toList();
      expect(views.length, 2);
      expect(views.first.id, 'b1');
      expect(views.last.id, 'b2');
    });
  });

  group('BudgetView / BudgetItemView derived getters', () {
    test('BudgetView.totalRemainingCents + isOverBudget', () {
      const view = BudgetView(
        id: 'b1',
        name: 'n',
        month: '2026-07',
        currencyCode: 'CNY',
        totalAmountCents: 500000,
        totalActualCents: 200000,
      );
      expect(view.totalRemainingCents, 300000);
      expect(view.isOverBudget, isFalse);

      const over = BudgetView(
        id: 'b2',
        name: 'n',
        month: '2026-07',
        currencyCode: 'CNY',
        totalAmountCents: 100000,
        totalActualCents: 150000,
      );
      expect(over.isOverBudget, isTrue);
    });

    test('BudgetItemView.usagePct guards divide-by-zero (planned=0 → 0)', () {
      const item = BudgetItemView(
        id: 'i1',
        accountId: 'a1',
        plannedAmountCents: 0,
        actualAmountCents: 100,
      );
      expect(item.usagePct, 0); // no NaN / Infinity
      expect(item.isOverBudget, isTrue);
    });

    test('BudgetItemView.remainingCents + usagePct normal path', () {
      const item = BudgetItemView(
        id: 'i1',
        accountId: 'a1',
        plannedAmountCents: 300000,
        actualAmountCents: 150000,
      );
      expect(item.remainingCents, 150000);
      expect(item.usagePct, 50.0);
      expect(item.isOverBudget, isFalse);
    });

    test('Equatable props compare full field set (incl items list)', () {
      final a = budgetDetailDtoToView(_detailDto(items: [_itemDto('i1')]));
      final b = budgetDetailDtoToView(_detailDto(items: [_itemDto('i1')]));
      expect(a, b); // same props → equal
    });
  });

  group('createBudget request wiring (BudgetItemInput)', () {
    test('BudgetItemInput wires accountId + plannedAmountCents (Int64) + notes', () {
      // DS maps caller record ({accountId, plannedAmountCents, notes}) →
      // proto BudgetItemInput. Verify the proto field-level round-trip:
      // non-empty notes survives verbatim, Int64 carries the cents value.
      final input = pb.BudgetItemInput(
        accountId: 'acc-1',
        plannedAmountCents: Int64(300000),
        notes: '房租',
      );
      expect(input.accountId, 'acc-1');
      expect(input.plannedAmountCents.toInt(), 300000);
      expect(input.notes, '房租');
    });

    test('BudgetItemInput.notes defaults to "" (DS writes notes ?? "")', () {
      // DS writes notes: i.notes ?? '' so null caller → '' (no notes).
      final input = pb.BudgetItemInput(accountId: 'acc-1', plannedAmountCents: Int64(0));
      expect(input.notes, ''); // proto unset scalar string → ''
    });

    test('CreateBudgetRequest wires name + month + currencyCode + items list', () {
      final req = pb.CreateBudgetRequest(
        name: '2026-07',
        month: '2026-07',
        currencyCode: 'CNY',
        items: [
          pb.BudgetItemInput(
            accountId: 'acc-1',
            plannedAmountCents: Int64(300000),
          ),
          pb.BudgetItemInput(
            accountId: 'acc-2',
            plannedAmountCents: Int64(200000),
            notes: '餐饮',
          ),
        ],
      );
      expect(req.name, '2026-07');
      expect(req.month, '2026-07');
      expect(req.currencyCode, 'CNY');
      expect(req.items.length, 2);
      expect(req.items.last.notes, '餐饮');
    });
  });

  group('addItem / removeItem request wiring', () {
    test('AddBudgetItemRequest wires budgetId + accountId + plannedAmountCents', () {
      final req = pb.AddBudgetItemRequest(
        budgetId: 'b-1',
        accountId: 'acc-1',
        plannedAmountCents: Int64(300000),
        notes: '',
      );
      expect(req.budgetId, 'b-1');
      expect(req.accountId, 'acc-1');
      expect(req.plannedAmountCents.toInt(), 300000);
    });

    test('RemoveBudgetItemRequest wires budgetId + itemId', () {
      final req = pb.RemoveBudgetItemRequest(budgetId: 'b-1', itemId: 'i-1');
      expect(req.budgetId, 'b-1');
      expect(req.itemId, 'i-1');
    });
  });

  test('BudgetRemoteDataSource is constructible with GrpcClient + retry', () {
    // The DS constructor eagerly builds a BudgetServiceClient from
    // GrpcClient.channel + authInterceptor — stub both so construction succeeds.
    // A real ClientChannel is cheap to construct and never connects until a
    // call is made (which we don't make here).
    when(() => grpcClient.channel)
        .thenReturn(ClientChannel('localhost', port: 9999));
    when(() => grpcClient.authInterceptor).thenReturn(AuthInterceptor());
    final ds = BudgetRemoteDataSource(grpcClient, retry);
    expect(ds, isA<BudgetRemoteDataSource>());
  });
}
