// F10 T1(2026-09-03):transaction repo 三态写路由 + FR-1b 写降级行为钉。
// - boundRemote + NetworkFailure(grpc unavailable)→ 降级落本地,数据不丢;
// - boundRemote + 其他 Failure(校验)→ 不降级,原样 Left,本地无写入;
// - guest → 本地,零远端调用(R6 行为不变);
// - boundOfflineLocal(断网)→ 本地,零远端调用;
// - boundRemote 远端成功 → 远端结果直返,本地不动(在线路径不变)。
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:drift/native.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db
    hide Transaction, TransactionEntry;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/data/transaction_remote_ds.dart';
import 'package:yucai_client/transaction/data/transaction_repository_impl.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

class _MockRemote extends Mock implements TransactionRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late db.AppDatabase database;
  late SessionModeTracker tracker;
  late TransactionLocalDataSource local;
  late TransactionRepositoryImpl repo;
  late String cash;
  late String food;

  final sampleDate = DateTime(2026, 9, 3);

  // 双分录写所需的两个账户(照 write_integrity_test 的 seedAccount 范式)。
  Future<String> seedAccount(String name, int type, {int balance = 100000}) {
    final id = 'acc-$name';
    return database.accountDao.getAccountById(id).then((existing) async {
      if (existing != null) return id;
      await database.accountDao.insertAccount(db.AccountsCompanion.insert(
        id: id,
        name: name,
        accountType: type,
        category: 2,
        currencyCode: 'CNY',
        initialBalanceCents: balance,
        currentBalanceCents: balance,
        ownership: 1,
        icon: '',
        color: '',
        chartCode: '',
        isSystem: false,
        sortOrder: 0,
        institution: '',
        cardNumberTail: '',
        notes: '',
        goldProductType: '',
        status: 1,
        version: 1,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ));
      return id;
    });
  }

  RecordExpenseParams params() => RecordExpenseParams(
        transactionDate: sampleDate,
        description: '午餐',
        expenseAccountId: food,
        assetAccountId: cash,
        amountCents: 5000,
      );

  setUp(() async {
    remote = _MockRemote();
    database = db.AppDatabase(NativeDatabase.memory());
    local = TransactionLocalDataSource(database, BalanceLocalUpdater(database));
    tracker = SessionModeTracker();
    repo = TransactionRepositoryImpl(remote, local, tracker);
    registerFallbackValue(RecordExpenseParams(
      transactionDate: sampleDate,
      expenseAccountId: '',
      assetAccountId: '',
      amountCents: 0,
    ));
    cash = await seedAccount('cash', 1);
    food = await seedAccount('food', 5);
  });

  tearDown(() => database.close());

  test('boundRemote + NetworkFailure → 降级落本地(数据不丢)', () async {
    tracker.isGuest = false;
    when(() => remote.recordExpense(any()))
        .thenThrow(const GrpcError.unavailable('down'));

    final result = await repo.recordExpense(params());

    expect(result.isRight(), isTrue);
    verify(() => remote.recordExpense(any())).called(1);
    // 落库断言:本地管道确实持有该笔交易。
    final page = await local.list(const ListTransactionsParams());
    expect(page.transactions, hasLength(1));
    expect(page.transactions.first.description, '午餐');
  });

  test('boundRemote + ValidationFailure → 不降级,本地无写入', () async {
    tracker.isGuest = false;
    when(() => remote.recordExpense(any()))
        .thenThrow(const GrpcError.invalidArgument('bad amount'));

    final result = await repo.recordExpense(params());

    expect(result.fold((l) => l, (_) => null), isA<ValidationFailure>());
    final page = await local.list(const ListTransactionsParams());
    expect(page.transactions, isEmpty);
  });

  test('guest → 本地写,零远端调用(R6 行为不变)', () async {
    final result = await repo.recordExpense(params());

    expect(result.isRight(), isTrue);
    verifyNoMoreInteractions(remote);
    final page = await local.list(const ListTransactionsParams());
    expect(page.transactions, hasLength(1));
  });

  test('boundOfflineLocal(connectivity 断网)→ 本地写,零远端调用', () async {
    tracker
      ..isGuest = false
      ..online = false;
    final result = await repo.recordExpense(params());

    expect(result.isRight(), isTrue);
    verifyNoMoreInteractions(remote);
    final page = await local.list(const ListTransactionsParams());
    expect(page.transactions, hasLength(1));
  });

  test('boundRemote 远端成功 → 远端结果直返,本地不动(在线路径不变)',
      () async {
    tracker.isGuest = false;
    // 远端样例实体(mock 返回值,本地库未持有)。
    final remoteTxn = Transaction(
      id: 'remote-t1',
      transactionDate: sampleDate,
      description: '远端午餐',
      entries: const <TransactionEntry>[
        TransactionEntry(
            id: 're1', accountId: 'acc-food', debitCents: 5000, creditCents: 0),
        TransactionEntry(
            id: 're2', accountId: 'acc-cash', debitCents: 0, creditCents: 5000),
      ],
      version: 3,
    );
    when(() => remote.recordExpense(any())).thenAnswer((_) async => remoteTxn);

    final result = await repo.recordExpense(params());

    expect(result.isRight(), isTrue);
    verify(() => remote.recordExpense(any())).called(1);
    // 在线成功路径不落本地(R6 语义:远端权威,镜像刷新才回填 —— 测试内
    // mirror 为 null,故本地保持空)。
    final page = await local.list(const ListTransactionsParams());
    expect(page.transactions, isEmpty);
  });
}
