# Debt 债务模块 client 移植 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 移植御财 Debt 债务模块 client(列表/详情/创建/还款,三端响应式),对齐 account/transaction client 模式 + OD 9 页原型。

**Architecture:** 数据层(domain entity + data remote_ds/repo/mapper + bloc)对齐 account module;UI 层(debts/detail/form 三页)对齐 accounts_page 模式 + OD 9 页设计(progress bar/摊还表/还款记账/到期提醒);路由加 /debts branch + AppShell nav。

**Tech Stack:** Flutter 3.44 + flutter_bloc + injectable(get_it DI) + grpc_dart + 御财 token。debt proto stub 已有(`lib/proto/debt/v1/debt.pbgrpc.dart` DebtServiceClient 7 RPC)。

## Global Constraints

- **对齐 account client 模式**:`@LazySingleton()` remote_ds(GrpcClient + AuthRetryCaller + mapper)、`Either<Failure, T>` repo_impl、Equatable entity、bloc(events/states 对齐 AccountBloc)。
- **debt proto stub 已有**:`DebtServiceClient`(`lib/proto/debt/v1/debt.pbgrpc.dart`),7 RPC:createDebt/updateDebt/deleteDebt/recordPayment/getDebt/listDebts/getUpcomingPayments。
- **DI**:新 remote_ds/repo 用 `@LazySingleton()`(injectable),`dart run build_runner build` 重新生成 injection.config。
- **三端响应式**:`ResponsiveLayout`(`Breakpoints.of(context)`,mobile/tablet/desktop),对齐 accounts_page/transactions_page。
- **御财 token**:奶油白 #f7f6f2 / 金 #b08d57 / 深色 #1c1e21 / 绿 #2d8a6e / 红 #c4544d / 边框 #e6e3dc / serif Georgia / mono tabular-nums。进度条 金色已还 + 灰底。
- **金额**:cents(int),mono tabular-nums 显示。
- **分支**:`debt-module`,BASE `80e3132`(spec commit)。

---

### Task 1: domain layer(Debt entity + repository abstract + value_objects)

**Files:**
- Create: `yucai/client/lib/debt/domain/entities/debt_entity.dart`
- Create: `yucai/client/lib/debt/domain/repositories/debt_repository.dart`
- Create: `yucai/client/lib/debt/domain/value_objects.dart`
- Test: `yucai/client/test/debt/domain/debt_entity_test.dart`

**Interfaces:**
- Consumes: 无
- Produces: `Debt`/`PaymentEntry`/`AmortizationMethod` entity + `DebtRepository` abstract(`Stream`/`Future<Either<Failure, T>>`)

- [ ] **Step 1: 写失败 test**

```dart
// test/debt/domain/debt_entity_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

void main() {
  test('Debt.progressRatio = (total - remaining) / total', () {
    final d = Debt(
      id: 'd1', accountId: 'a1', counterparty: '招行',
      interestRate: 4.2, amortization: AmortizationMethod.equalPrincipalInterest,
      startDate: DateTime(2024, 1, 1), dueDate: DateTime(2034, 1, 1),
      totalPrincipalCents: 280000000, remainingPrincipalCents: 210000000,
      version: 1, createdAt: DateTime(2024,1,1), updatedAt: DateTime(2024,1,1),
    );
    expect(d.progressRatio, closeTo(0.25, 0.001)); // (280-210)/280
  });

  test('PaymentEntry.status 逾期/待还/已还', () {
    final paid = PaymentEntry(id:'e1', paymentDate: DateTime(2024,2,1),
        principalCents: 100000, interestCents: 5000, totalCents: 105000,
        paid: true, paidCents: 105000, transactionId: 't1');
    expect(paid.status, PaymentStatus.paid);

    final overdue = PaymentEntry(id:'e2', paymentDate: DateTime(2020,1,1),
        principalCents: 100000, interestCents: 5000, totalCents: 105000,
        paid: false, paidCents: 0, transactionId: '');
    expect(overdue.status, PaymentStatus.overdue);

    final pending = PaymentEntry(id:'e3', paymentDate: DateTime(2099,1,1),
        principalCents: 100000, interestCents: 5000, totalCents: 105000,
        paid: false, paidCents: 0, transactionId: '');
    expect(pending.status, PaymentStatus.pending);
  });
}
```

- [ ] **Step 2: 运行测试，确认其失败**

Run: `cd yucai/client && flutter test test/debt/domain/debt_entity_test.dart`
Expected: FAIL(Debt/PaymentEntry 未定义)

- [ ] **Step 3: 实现 domain**

`yucai/client/lib/debt/domain/value_objects.dart`:
```dart
/// 摊还方法(对齐 proto AmortizationMethod)。
enum AmortizationMethod {
  equalPrincipalInterest, // 等额本息
  equalPrincipal,         // 等额本金
  lumpSum,                // 一次性
}

enum PaymentStatus { paid, pending, overdue }
```

`yucai/client/lib/debt/domain/entities/debt_entity.dart`:
```dart
import 'package:equatable/equatable.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

class Debt extends Equatable {
  const Debt({
    required this.id,
    required this.accountId,
    required this.counterparty,
    required this.interestRate,
    required this.amortization,
    required this.startDate,
    required this.dueDate,
    required this.totalPrincipalCents,
    required this.remainingPrincipalCents,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String accountId;       // 关联 loan 账户
  final String counterparty;    // 债权方
  final double interestRate;    // 年利率 %
  final AmortizationMethod amortization;
  final DateTime startDate;
  final DateTime dueDate;
  final int totalPrincipalCents;
  final int remainingPrincipalCents;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 已还比例 (total-remaining)/total,0~1。total=0 时 0。
  double get progressRatio => totalPrincipalCents <= 0
      ? 0
      : (totalPrincipalCents - remainingPrincipalCents) / totalPrincipalCents;

  @override
  List<Object?> get props => [id, version];
}

class PaymentEntry extends Equatable {
  const PaymentEntry({
    required this.id,
    required this.paymentDate,
    required this.principalCents,
    required this.interestCents,
    required this.totalCents,
    required this.paid,
    required this.paidCents,
    required this.transactionId,
  });

  final String id;
  final DateTime paymentDate;
  final int principalCents;
  final int interestCents;
  final int totalCents;
  final bool paid;
  final int paidCents;
  final String transactionId; // '' = 未关联交易

  /// 状态:已还(paid)/逾期(!paid && date<now)/待还(!paid && date>=now)。
  PaymentStatus get status {
    if (paid) return PaymentStatus.paid;
    return paymentDate.isBefore(DateTime.now())
        ? PaymentStatus.overdue
        : PaymentStatus.pending;
  }

  @override
  List<Object?> get props => [id, paidCents];
}

class DebtDetail extends Equatable {
  const DebtDetail({required this.debt, required this.schedule});
  final Debt debt;
  final List<PaymentEntry> schedule;
  @override
  List<Object?> get props => [debt.id];
}
```

`yucai/client/lib/debt/domain/repositories/debt_repository.dart`:
```dart
import 'package:dartz/dartz.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';

abstract class DebtRepository {
  Future<Either<Failure, List<Debt>>> list();
  Future<Either<Failure, DebtDetail>> get(String id);
  Future<Either<Failure, Debt>> create({
    required String accountId,
    required String counterparty,
    required double interestRate,
    required int amortizationIndex, // AmortizationMethod.index
    required DateTime startDate,
    required DateTime dueDate,
    required int totalPrincipalCents,
  });
  Future<Either<Failure, Debt>> update({
    required String id,
    required String counterparty,
    required double interestRate,
    required int version,
  });
  Future<Either<Failure, void>> delete(String id);
  Future<Either<Failure, PaymentEntry>> recordPayment({
    required String debtId,
    required String scheduleEntryId,
    required String fromAccountId,
  });
  Future<Either<Failure, List<Debt>>> upcomingPayments(int daysAhead);
}
```

- [ ] **Step 4: 运行测试，确认其通过**

Run: `cd yucai/client && flutter test test/debt/domain/debt_entity_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/debt/ yucai/client/test/debt/
git commit -m "feat(debt): domain layer — Debt/PaymentEntry entity + repository abstract"
```

---

### Task 2: data mapper(proto ↔ entity)

**Files:**
- Create: `yucai/client/lib/debt/data/mappers/debt_mapper.dart`
- Test: `yucai/client/test/debt/data/debt_mapper_test.dart`

**Interfaces:**
- Consumes: Task 1 `Debt`/`PaymentEntry`/`AmortizationMethod` + proto `DebtDTO`/`PaymentEntryDTO`/`AmortizationMethod`(debt.pb.dart)
- Produces: `DebtMapper`(proto ↔ entity 静态方法)

- [ ] **Step 1: 写失败 test**

```dart
// test/debt/data/debt_mapper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/debt/data/mappers/debt_mapper.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/proto/debt/v1/debt.pb.dart' as pb;

void main() {
  test('DebtMapper.toDomain: proto → entity', () {
    final dto = pb.DebtDTO()
      ..id = 'd1'
      ..accountId = 'a1'
      ..counterparty = '招行'
      ..interestRate = 4.2
      ..amortizationMethod = pb.AmortizationMethod.AMORTIZATION_EQUAL_PRINCIPAL_INTEREST
      ..startDate = '2024-01-01'
      ..dueDate = '2034-01-01'
      ..totalPrincipalCents = 280000000
      ..remainingPrincipalCents = 210000000
      ..version = 1;
    final d = DebtMapper.toDomain(dto);
    expect(d.id, 'd1');
    expect(d.amortization, AmortizationMethod.equalPrincipalInterest);
    expect(d.startDate, DateTime(2024, 1, 1));
  });

  test('DebtMapper.paymentEntryToDomain', () {
    final dto = pb.PaymentEntryDTO()
      ..id = 'e1'
      ..paymentDate = '2024-02-01'
      ..principalCents = 100000
      ..interestCents = 5000
      ..totalCents = 105000
      ..paid = true
      ..paidCents = 105000
      ..transactionId = 't1';
    final e = DebtMapper.paymentEntryToDomain(dto);
    expect(e.paid, true);
    expect(e.status, PaymentStatus.paid);
  });
}
```

- [ ] **Step 2: 运行测试，确认其失败**

Run: `cd yucai/client && flutter test test/debt/data/debt_mapper_test.dart`
Expected: FAIL(DebtMapper 未定义)

- [ ] **Step 3: 实现 mapper**

`yucai/client/lib/debt/data/mappers/debt_mapper.dart`:
```dart
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/proto/debt/v1/debt.pb.dart' as pb;

class DebtMapper {
  DebtMapper._();

  static Debt toDomain(pb.DebtDTO dto) {
    return Debt(
      id: dto.id,
      accountId: dto.accountId,
      counterparty: dto.counterparty,
      interestRate: dto.interestRate,
      amortization: _amortFromProto(dto.amortizationMethod),
      startDate: DateTime.parse(dto.startDate),
      dueDate: DateTime.parse(dto.dueDate),
      totalPrincipalCents: dto.totalPrincipalCents.toInt(),
      remainingPrincipalCents: dto.remainingPrincipalCents.toInt(),
      version: dto.version.toInt(),
      createdAt: dto.createdAt.toDateTime(),
      updatedAt: dto.updatedAt.toDateTime(),
    );
  }

  static PaymentEntry paymentEntryToDomain(pb.PaymentEntryDTO dto) {
    return PaymentEntry(
      id: dto.id,
      paymentDate: DateTime.parse(dto.paymentDate),
      principalCents: dto.principalCents.toInt(),
      interestCents: dto.interestCents.toInt(),
      totalCents: dto.totalCents.toInt(),
      paid: dto.paid,
      paidCents: dto.paidCents.toInt(),
      transactionId: dto.transactionId,
    );
  }

  static AmortizationMethod _amortFromProto(pb.AmortizationMethod m) {
    switch (m) {
      case pb.AmortizationMethod.AMORTIZATION_EQUAL_PRINCIPAL_INTEREST:
        return AmortizationMethod.equalPrincipalInterest;
      case pb.AmortizationMethod.AMORTIZATION_EQUAL_PRINCIPAL:
        return AmortizationMethod.equalPrincipal;
      case pb.AmortizationMethod.AMORTIZATION_LUMP_SUM:
        return AmortizationMethod.lumpSum;
      default:
        return AmortizationMethod.equalPrincipalInterest;
    }
  }

  static pb.AmortizationMethod amortToProto(AmortizationMethod m) {
    switch (m) {
      case AmortizationMethod.equalPrincipalInterest:
        return pb.AmortizationMethod.AMORTIZATION_EQUAL_PRINCIPAL_INTEREST;
      case AmortizationMethod.equalPrincipal:
        return pb.AmortizationMethod.AMORTIZATION_EQUAL_PRINCIPAL;
      case AmortizationMethod.lumpSum:
        return pb.AmortizationMethod.AMORTIZATION_LUMP_SUM;
    }
  }
}
```

- [ ] **Step 4: 运行测试，确认其通过**

Run: `cd yucai/client && flutter test test/debt/data/debt_mapper_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/debt/data/mappers/debt_mapper.dart yucai/client/test/debt/data/debt_mapper_test.dart
git commit -m "feat(debt): data mapper — proto DebtDTO ↔ entity"
```

---

### Task 3: data remote_ds(gRPC 7 RPC)

**Files:**
- Create: `yucai/client/lib/debt/data/debt_remote_ds.dart`
- Test: `yucai/client/test/debt/data/debt_remote_ds_test.dart`

**Interfaces:**
- Consumes: Task 1 entity + Task 2 mapper + `GrpcClient`/`AuthRetryCaller`(core/network)+ proto `DebtServiceClient`
- Produces: `DebtRemoteDataSource`(@LazySingleton,7 方法 list/get/create/update/delete/recordPayment/upcomingPayments,throw GrpcError)

- [ ] **Step 1: 写失败 test**

参考 `test/account/data/account_remote_ds_test.dart` 的 mock GrpcClient/retry 模式。test `list()` 调 `_client.listDebt` + mapper → `List<Debt>`。

```dart
// test/debt/data/debt_remote_ds_test.dart —— mock DebtServiceClient,list() 返回 2 DebtDTO → 2 Debt
// (具体 mock 参考 account_remote_ds_test;此处省略 boilerplate,断言 list() 返 List<Debt> length 2)
```

> 注:remote_ds test mock gRPC client(对齐 account_remote_ds_test)。若 account_remote_ds_test 无现成 mock 模板,本 task test 可简化为「mapper 调用 + 异常透传」unit test,mock `DebtServiceClient` 用 mocktail。

- [ ] **Step 2: 运行测试，确认其失败**

Run: `cd yucai/client && flutter test test/debt/data/debt_remote_ds_test.dart`
Expected: FAIL(DebtRemoteDataSource 未定义)

- [ ] **Step 3: 实现 remote_ds**

`yucai/client/lib/debt/data/debt_remote_ds.dart`(对齐 `account_remote_ds.dart` 模式):
```dart
import 'package:fixnum/fixnum.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/debt/data/mappers/debt_mapper.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/proto/common/v1/pagination.pb.dart' as common;
import 'package:yucai_client/proto/debt/v1/debt.pb.dart' as pb;
import 'package:yucai_client/proto/debt/v1/debt.pbgrpc.dart' as grpc;

@LazySingleton()
class DebtRemoteDataSource {
  DebtRemoteDataSource(this._grpcClient, this._retry) {
    _client = grpc.DebtServiceClient(
      _grpcClient.channel,
      interceptors: [_grpcClient.authInterceptor],
    );
  }

  final GrpcClient _grpcClient;
  final AuthRetryCaller _retry;
  late final grpc.DebtServiceClient _client;

  Future<List<Debt>> list() async {
    return _retry.call(() async {
      final res = await _client.listDebts(pb.ListDebtsRequest(
        page: common.PageRequest(pageSize: 100),
      ));
      return res.debts.map(DebtMapper.toDomain).toList();
    });
  }

  Future<DebtDetail> get(String id) async {
    return _retry.call(() async {
      final res = await _client.getDebt(pb.GetDebtRequest(id: id));
      final d = res.debt;
      return DebtDetail(
        debt: DebtMapper.toDomain(d.debt),
        schedule: d.schedule.map(DebtMapper.paymentEntryToDomain).toList(),
      );
    });
  }

  Future<Debt> create({
    required String accountId,
    required String counterparty,
    required double interestRate,
    required int amortizationIndex,
    required DateTime startDate,
    required DateTime dueDate,
    required int totalPrincipalCents,
  }) async {
    return _retry.call(() async {
      final res = await _client.createDebt(pb.CreateDebtRequest(
        accountId: accountId,
        counterparty: counterparty,
        interestRate: interestRate,
        amortizationMethod: pb.AmortizationMethod.valueOf(amortizationIndex)!,
        startDate: _fmtDate(startDate),
        dueDate: _fmtDate(dueDate),
        totalPrincipalCents: Int64(totalPrincipalCents),
      ));
      return DebtMapper.toDomain(res.debt);
    });
  }

  Future<Debt> update({
    required String id,
    required String counterparty,
    required double interestRate,
    required int version,
  }) async {
    return _retry.call(() async {
      final res = await _client.updateDebt(pb.UpdateDebtRequest(
        id: id,
        counterparty: counterparty,
        interestRate: interestRate,
        version: Int64(version),
      ));
      return DebtMapper.toDomain(res.debt);
    });
  }

  Future<void> delete(String id) async {
    return _retry.call(() async {
      await _client.deleteDebt(pb.DeleteDebtRequest(id: id));
    });
  }

  Future<PaymentEntry> recordPayment({
    required String debtId,
    required String scheduleEntryId,
    required String fromAccountId,
  }) async {
    return _retry.call(() async {
      final res = await _client.recordPayment(pb.RecordPaymentRequest(
        debtId: debtId,
        scheduleEntryId: scheduleEntryId,
        fromAccountId: fromAccountId,
      ));
      return DebtMapper.paymentEntryToDomain(res.entry);
    });
  }

  Future<List<Debt>> upcomingPayments(int daysAhead) async {
    return _retry.call(() async {
      final res = await _client.getUpcomingPayments(
          pb.GetUpcomingPaymentsRequest(daysAhead: Int32(daysAhead)));
      return res.debts.map(DebtMapper.toDomain).toList();
    });
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
```

- [ ] **Step 4: 运行测试，确认其通过**

Run: `cd yucai/client && flutter test test/debt/data/debt_remote_ds_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/debt/data/debt_remote_ds.dart yucai/client/test/debt/data/debt_remote_ds_test.dart
git commit -m "feat(debt): data remote_ds — gRPC 7 RPC(DebtServiceClient)"
```

---

### Task 4: data repo_impl(Either<Failure>)

**Files:**
- Create: `yucai/client/lib/debt/data/debt_repository_impl.dart`
- Test: `yucai/client/test/debt/data/debt_repository_impl_test.dart`

**Interfaces:**
- Consumes: Task 1 `DebtRepository` abstract + Task 3 `DebtRemoteDataSource`
- Produces: `DebtRepositoryImpl`(@LazySingleton as DebtRepository,catch GrpcError → Failure)

- [ ] **Step 1: 写失败 test**

mock `DebtRemoteDataSource`(mocktail),test `list()` 成功(Right<List<Debt>>)+ 失败(Left<Failure>)。参考 `account_repository_impl_test.dart`。

- [ ] **Step 2: 运行测试，确认其失败**

Run: `cd yucai/client && flutter test test/debt/data/debt_repository_impl_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现 repo_impl**

`yucai/client/lib/debt/data/debt_repository_impl.dart`(对齐 `account_repository_impl.dart`):
```dart
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/debt/data/debt_remote_ds.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:grpc/grpc.dart';

@LazySingleton(as: DebtRepository)
class DebtRepositoryImpl implements DebtRepository {
  DebtRepositoryImpl(this._remote);
  final DebtRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<Debt>>> list() async => _guard(() => _remote.list());
  @override
  Future<Either<Failure, DebtDetail>> get(String id) async => _guard(() => _remote.get(id));
  @override
  Future<Either<Failure, Debt>> create({required String accountId, required String counterparty, required double interestRate, required int amortizationIndex, required DateTime startDate, required DateTime dueDate, required int totalPrincipalCents}) async =>
      _guard(() => _remote.create(accountId: accountId, counterparty: counterparty, interestRate: interestRate, amortizationIndex: amortizationIndex, startDate: startDate, dueDate: dueDate, totalPrincipalCents: totalPrincipalCents));
  @override
  Future<Either<Failure, Debt>> update({required String id, required String counterparty, required double interestRate, required int version}) async =>
      _guard(() => _remote.update(id: id, counterparty: counterparty, interestRate: interestRate, version: version));
  @override
  Future<Either<Failure, void>> delete(String id) async => _guard(() => _remote.delete(id));
  @override
  Future<Either<Failure, PaymentEntry>> recordPayment({required String debtId, required String scheduleEntryId, required String fromAccountId}) async =>
      _guard(() => _remote.recordPayment(debtId: debtId, scheduleEntryId: scheduleEntryId, fromAccountId: fromAccountId));
  @override
  Future<Either<Failure, List<Debt>>> upcomingPayments(int daysAhead) async => _guard(() => _remote.upcomingPayments(daysAhead));

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() f) async {
    try {
      return Right(await f());
    } on GrpcError catch (e) {
      return Left(ServerFailure(e.message ?? 'gRPC error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
```

- [ ] **Step 4: 运行测试，确认其通过**

Run: `cd yucai/client && flutter test test/debt/data/debt_repository_impl_test.dart`
Expected: PASS

- [ ] **Step 5: 重新生成 DI + 提交**

```bash
cd yucai/client && dart run build_runner build --delete-conflicting-outputs
git add yucai/client/lib/debt/data/debt_repository_impl.dart yucai/client/lib/core/di/injection.config.dart yucai/client/test/debt/data/debt_repository_impl_test.dart
git commit -m "feat(debt): data repo_impl — Either<Failure> + DI register"
```

---

### Task 5: bloc(events/states/bloc)

**Files:**
- Create: `yucai/client/lib/debt/presentation/bloc/debt_event.dart`
- Create: `yucai/client/lib/debt/presentation/bloc/debt_state.dart`
- Create: `yucai/client/lib/debt/presentation/bloc/debt_bloc.dart`
- Test: `yucai/client/test/debt/presentation/bloc/debt_bloc_test.dart`

**Interfaces:**
- Consumes: Task 1/4 `DebtRepository` + entity
- Produces: `DebtBloc` + events(LoadDebts/LoadDebt/Create/Update/Delete/RecordPayment) + states(Initial/Loading/Loaded/DetailLoaded/Submitting/Error)

- [ ] **Step 1: 写失败 test**

参考 `account_bloc_test.dart`。test `LoadDebtsRequested` → mock repo list → `DebtsLoaded([debt])`。test `LoadDebtRequested(id)` → `DebtDetailLoaded`。

- [ ] **Step 2: 运行测试，确认其失败**

Run: `cd yucai/client && flutter test test/debt/presentation/bloc/debt_bloc_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现 bloc**

`debt_event.dart`(对齐 account_event):`LoadDebtsRequested` / `LoadDebtRequested(id)` / `CreateDebtRequested(params)` / `UpdateDebtRequested(params)` / `DeleteDebtRequested(id)` / `RecordPaymentRequested(debtId, entryId, fromAccountId)`。

`debt_state.dart`:`DebtInitial` / `DebtLoading` / `DebtsLoaded(List<Debt> debts)` / `DebtDetailLoaded(DebtDetail detail)` / `DebtSubmitting(List<Debt> last)` / `DebtError(String message, {List<Debt> last})`。

`debt_bloc.dart`(对齐 AccountBloc,inject `DebtRepository` + 用例或直接调 repo):
```dart
class DebtBloc extends Bloc<DebtEvent, DebtState> {
  DebtBloc(this._repo) : super(DebtInitial()) {
    on<LoadDebtsRequested>(_onLoadDebts);
    on<LoadDebtRequested>(_onLoadDebt);
    on<CreateDebtRequested>(_onCreate);
    on<UpdateDebtRequested>(_onUpdate);
    on<DeleteDebtRequested>(_onDelete);
    on<RecordPaymentRequested>(_onRecordPayment);
  }
  final DebtRepository _repo;
  // _onLoadDebts: emit DebtLoading → repo.list → DebtsLoaded or DebtError
  // _onLoadDebt: emit DebtLoading → repo.get → DebtDetailLoaded
  // _onCreate/_onUpdate: emit DebtSubmitting → repo.create/update → add(LoadDebtsRequested)
  // _onDelete: emit DebtSubmitting → repo.delete → add(LoadDebtsRequested)
  // _onRecordPayment: repo.recordPayment → add(LoadDebtRequested(debtId)) 刷新详情
}
```

> 完整 handler 代码对齐 `account_bloc.dart` 的 `_onLoad`/`_onUpdate` 模式(emit Loading → repo → Loaded/Error,写操作后 `add(LoadDebtsRequested)` 刷新)。

- [ ] **Step 4: 运行测试，确认其通过**

Run: `cd yucai/client && flutter test test/debt/presentation/bloc/debt_bloc_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/debt/presentation/bloc/ yucai/client/test/debt/presentation/
git commit -m "feat(debt): bloc — events/states/handlers(Load/CRUD/Payment)"
```

---

### Task 6: debts_page(列表 + 三端响应式)

**Files:**
- Create: `yucai/client/lib/debt/presentation/pages/debts_page.dart`
- Test: `yucai/client/test/debt/presentation/pages/debts_page_test.dart`

**Interfaces:**
- Consumes: Task 5 `DebtBloc` + Task 1 `Debt`(progressRatio) + `ResponsiveLayout`
- Produces: `DebtsPage`(总债务概览 progress + 债务卡列表 + 三端)

- [ ] **Step 1: 写失败 test**

参考 `accounts_page_test.dart` harness(mock DebtBloc + debts)。test:总债务概览(总负债/剩余/progress)+ 债务卡(counterparty/剩余/progress)+ 三端(desktop/tablet/mobile viewport)。

- [ ] **Step 2: 运行测试，确认其失败**

Run: `cd yucai/client && flutter test test/debt/presentation/pages/debts_page_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现 debts_page**

对齐 OD `debts.html`/`debts-tablet.html`/`debts-mobile.html`(总债务概览 + 债务卡 + progress bar)+ `ResponsiveLayout`(desktop 表格/tablet 2 列/mobile 单列卡)。复用 `accounts_page` 的 `_sumcard`/`_fullCard`/`_compactCard` 模式 + `DataCard`/`AppColors`/`AppTypography.tabularFigures`。

关键组件:
- `_OverviewCard`:总负债 + 剩余 + progress bar(已还比例 sum(progressRatio * total)/sum(total))+ 下次还款(min dueDate)
- `_DebtCard`:counterparty + 类型 badge + 剩余本金(大字 mono)+ progress bar(progressRatio)+ 利率 + 到期 + 下次还款 + 操作
- `ResponsiveLayout`:desktop GridView / tablet 2 列 / mobile 单列

- [ ] **Step 4: 运行测试，确认其通过**

Run: `cd yucai/client && flutter test test/debt/presentation/pages/debts_page_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/debt/presentation/pages/debts_page.dart yucai/client/test/debt/presentation/pages/debts_page_test.dart
git commit -m "feat(debt): debts_page 列表 + 三端响应式 + progress bar"
```

---

### Task 7: debt_detail_page(详情 + schedule + RecordPayment + 三端)

**Files:**
- Create: `yucai/client/lib/debt/presentation/pages/debt_detail_page.dart`
- Test: `yucai/client/test/debt/presentation/pages/debt_detail_page_test.dart`

**Interfaces:**
- Consumes: Task 5 `DebtBloc`(LoadDebtRequested → DebtDetailLoaded) + Task 1 `DebtDetail`/`PaymentEntry`
- Produces: `DebtDetailPage`(Hero + StatCard + schedule 表/卡 + RecordPayment + 三端)

- [ ] **Step 1: 写失败 test**

参考 `account_detail_page_test.dart`。test:Hero(剩余本金 + progress)+ StatCard(本金/利率/到期/摊还)+ schedule(每期 日期/本金/利息/合计/状态)+ 三端(desktop 表/mobile 卡列表)。

- [ ] **Step 2: 运行测试，确认其失败**

Run: `cd yucai/client && flutter test test/debt/presentation/pages/debt_detail_page_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现 debt_detail_page**

对齐 OD `debt-detail.html`/`debt-detail-tablet.html`/`debt-detail-mobile.html`(Hero 深色金渐变 + StatCard + schedule 表/卡 + RecordPayment)。复用 `account_detail_page` 的 `_hero`(深色金渐变)+ `DataCard`/`_StatIconSquare` 模式。

关键组件:
- `_Hero`:counterparty + 类型 + 剩余本金(大字)+ progress bar(progressRatio)+ 较上月(后续,fallback 显示到期)
- `_StatRow`:总本金 / 利率 / 到期 / 摊还 / 已还期数
- `_ScheduleTable`(desktop/tablet):每期行(日期/本金/利息/合计/状态badge/记账按钮)
- `_ScheduleCardList`(mobile):每期卡(期次·日期 + 状态 + 本金/利息/合计 + 记账按钮)
- `RecordPayment`:点待还期「记账」→ 弹 from_account 选择 → `RecordPaymentRequested` → 刷新
- 筛选:全部/待还/已还/逾期(segmented)

- [ ] **Step 4: 运行测试，确认其通过**

Run: `cd yucai/client && flutter test test/debt/presentation/pages/debt_detail_page_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/debt/presentation/pages/debt_detail_page.dart yucai/client/test/debt/presentation/pages/debt_detail_page_test.dart
git commit -m "feat(debt): debt_detail_page Hero + 摊还表 + RecordPayment + 三端"
```

---

### Task 8: debt_form_page(创建/编辑 + 预览 + 三端)

**Files:**
- Create: `yucai/client/lib/debt/presentation/pages/debt_form_page.dart`
- Test: `yucai/client/test/debt/presentation/pages/debt_form_page_test.dart`

**Interfaces:**
- Consumes: Task 5 `DebtBloc`(CreateDebtRequested/UpdateDebtRequested) + Task 1 `Debt` + accounts list(选关联账户,`AccountRepository.list`)
- Produces: `DebtFormPage`(表单 + 实时预览 + 三端 step wizard)

- [ ] **Step 1: 写失败 test**

参考 `account_form_page_test.dart`。test:字段(债权方/类型/账户/本金/利率/摊还/日期)+ 提交(CreateDebtRequested)+ 三端(desktop 分区/mobile step wizard)。

- [ ] **Step 2: 运行测试，确认其失败**

Run: `cd yucai/client && flutter test test/debt/presentation/pages/debt_form_page_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现 debt_form_page**

对齐 OD `debt-form.html`/`debt-form-tablet.html`/`debt-form-mobile.html`(表单分区 + 实时预览 + step wizard)。复用 `account_form_page` 的 `FormCard`/`TypeTabs`/`categoryFieldsWidget` 模式。

关键组件:
- 表单:债权方(TextInput)+ 类型(房贷/车贷/信用卡/亲友借款/其他 单选)+ 关联账户(loan 账户下拉,`AccountRepository.list` filter loan)+ 本金(AmountInput)+ 利率(TextInput %)+ 摊还(单选 等额本息/等额本金/一次性)+ 起止日期(DatePickerInput)
- 实时预览:基于 摊还 + 本金 + 利率 算还款计划前 5 期(本地计算,client-side amortization)
- 三端:desktop 分区(tablet 双列)/mobile step wizard(Step1 基本信息 → Step2 金额利率 → Step3 日期,顶部进度指示)
- 提交:CreateDebtRequested(accountId/counterparty/interestRate/amortizationIndex/startDate/dueDate/totalPrincipalCents)

> 摊还预览计算:client-side 算(等额本息/等额本金/一次性 月供 + 前 5 期)。简化:等额本息 月供 = P*r*(1+r)^n / ((1+r)^n - 1);等额本金 月供 = (P/n) + (剩余* r);一次性 = 到期还本付息。n = 月份 = (dueDate - startDate) 月数。

- [ ] **Step 4: 运行测试，确认其通过**

Run: `cd yucai/client && flutter test test/debt/presentation/pages/debt_form_page_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/debt/presentation/pages/debt_form_page.dart yucai/client/test/debt/presentation/pages/debt_form_page_test.dart
git commit -m "feat(debt): debt_form_page 创建/编辑 + 摊还预览 + 三端 step wizard"
```

---

### Task 9: router + AppShell nav + DI 收尾

**Files:**
- Modify: `yucai/client/lib/app/router.dart`(加 /debts branch + /debts/:id + /debts/new)
- Modify: `yucai/client/lib/app/widgets/app_shell.dart`(加 branch 3 债务 nav item)
- Test: `yucai/client/test/debt/presentation/pages/debts_page_test.dart`(已 Task 6,此处加路由集成)

**Interfaces:**
- Consumes: Task 5-8 DebtBloc + 3 pages
- Produces: `/debts` route + AppShell 债务 nav(branch 3)

- [ ] **Step 1: 写失败 test**

test `/debts` 路由渲染 DebtsPage(mock DebtBloc)。参考 router 现有 /accounts test。

- [ ] **Step 2: 运行测试，确认其失败**

Run: `cd yucai/client && flutter test test/debt/`
Expected: FAIL(/debts route 未注册)

- [ ] **Step 3: 加 router branch + AppShell nav**

`router.dart`:加 StatefulShellBranch(branches list 加第 4):
```dart
StatefulShellBranch(
  routes: [
    GoRoute(
      path: '/debts',
      builder: (_, __) => BlocProvider<DebtBloc>(
        create: (_) => DebtBloc(getIt<DebtRepository>())..add(LoadDebtsRequested()),
        child: const DebtsPage(),
      ),
      routes: [
        GoRoute(path: 'new', builder: (_, __) => const DebtFormPage()),
        GoRoute(path: ':id', builder: (_, state) => BlocProvider<DebtBloc>(
          create: (_) => DebtBloc(getIt<DebtRepository>())..add(LoadDebtRequested(state.pathParameters['id']!)),
          child: DebtDetailPage(id: state.pathParameters['id']!),
        )),
      ],
    ),
  ],
),
```

`app_shell.dart`:
- `_branchTitle` case 3 → '债务管理'
- `_Sidebar`/`_BottomNav` nav items 加 `_NavItem('债务', Icons.account_balance_wallet_outlined, 3, route: '/debts')`

- [ ] **Step 4: 运行测试，确认其通过**

Run: `cd yucai/client && flutter test test/debt/`
Expected: PASS(全 debt test)

- [ ] **Step 5: 重新生成 DI + 全量验证 + 提交**

```bash
cd yucai/client && dart run build_runner build --delete-conflicting-outputs
cd yucai/client && flutter test
cd yucai/client && flutter analyze lib/debt/ lib/app/
git add yucai/client/lib/app/ yucai/client/lib/core/di/injection.config.dart
git commit -m "feat(debt): router /debts branch + AppShell nav + DI 收尾"
```

---

## Self-Review

**1. Spec 覆盖**:
- §4 数据层(domain/data/bloc) → Task 1-5 ✓
- §5.1 debts_page → Task 6 ✓
- §5.2 debt_detail_page → Task 7 ✓
- §5.3 debt_form_page → Task 8 ✓
- §6 路由 → Task 9 ✓

**2. 占位扫描**:Task 3 remote_ds test 参考现成 mock 模式(account_remote_ds_test)无 placeholder。Task 5 bloc handler + Task 6-8 UI 参考现成 account 模式 + OD 原型,关键组件列明。✓

**3. 类型一致**:`Debt`/`PaymentEntry`/`DebtDetail`/`AmortizationMethod`(Task 1)贯穿 Task 2-9。`DebtRepository` 7 方法签名(Task 1 abstract)Task 3-4 impl 一致。bloc events/states(Task 5)Task 6-8 调用一致。

无 gap,类型一致。
