// Feature G oracles — exporter shape contract: the per-module JSON must match
// the server exporters' domain-struct marshal (PascalCase/int enums/ISO8601
// with Z/nested arrays/goal uuid arrays/holding sibling arrays).
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/backup/data/local_snapshot_exporter.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/account_dao.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

void main() {
  late db.AppDatabase database;
  late LocalSnapshotExporter exporter;
  late AccountDao accounts;
  late TransactionLocalDataSource txns;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    exporter = LocalSnapshotExporter(database);
    accounts = database.accountDao;
    txns = TransactionLocalDataSource(database, BalanceLocalUpdater(database));
  });

  tearDown(() => database.close());

  db.AccountsCompanion accountRow(String id, {int balance = 1000000}) =>
      db.AccountsCompanion.insert(
        id: id,
        name: 'Cash',
        accountType: 1,
        category: 2,
        currencyCode: 'CNY',
        initialBalanceCents: balance,
        currentBalanceCents: balance,
        ownership: 1,
        icon: '',
        color: '',
        chartCode: '1001',
        isSystem: false,
        sortOrder: 0,
        institution: '',
        cardNumberTail: '',
        notes: '',
        goldProductType: '',
        status: 1,
        version: 3,
        createdAt: DateTime.utc(2026, 8, 23),
        updatedAt: DateTime.utc(2026, 8, 23),
      );

  test('envelope top shape + version + module keys', () async {
    final bytes = await exporter.exportAll();
    final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    expect(envelope['version'], 1);
    expect(envelope['tenant_id'], isNotEmpty); // placeholder, server overrides
    expect(envelope['created_at'], isA<String>());
    final modules = envelope['modules'] as Map<String, dynamic>;
    expect(modules.keys, containsAll([
      'account', 'transaction', 'debt', 'budget',
      'goal', 'tag', 'template', 'holding',
    ]));
    // Empty store → all modules empty lists (holding → both arrays empty).
    expect(modules['account'], isEmpty);
    expect((modules['holding'] as Map)['holdings'], isEmpty);
  });

  test('account module field shape (server struct mirror)', () async {
    await accounts.insertAccount(accountRow('a1', balance: 50));
    final envelope = await _envelope(exporter);
    final account = (envelope['modules']['account'] as List).single;
    expect(account['ID'], 'a1');
    expect(account['Name'], 'Cash');
    expect(account['AccountType'], 1); // contract int, not enum name
    expect(account['CurrentBalanceCents'], 50);
    expect(account['ChartCode'], '1001');
    expect(account['Version'], 3);
    expect(account['DeletedAt'], isNull);
    expect(account['CreatedAt'], startsWith('2026-08-23T')); // ISO8601 w/ Z
    expect(account['CreatedAt'].toString().endsWith('Z'), isTrue);
    // Full field presence (47-key superset check on critical names).
    for (final key in [
      'ParentID', 'IsSystem', 'SortOrder', 'CreditLimitCents', 'OpeningDate',
      'GoldQuantity', 'LoanMonthlyCents', 'Status', 'UpdatedAt',
    ]) {
      expect(account.containsKey(key), isTrue, reason: key);
    }
  });

  test('transaction module nests entries (conversion rule 4)', () async {
    await accounts.insertAccount(accountRow('a1'));
    await txns.recordExpense(RecordExpenseParams(
      transactionDate: DateTime.utc(2026, 8, 23),
      expenseAccountId: 'a1',
      assetAccountId: 'a1',
      amountCents: 500,
    ));
    final envelope = await _envelope(exporter);
    final txn = (envelope['modules']['transaction'] as List).single;
    expect(txn['ID'], isNotEmpty); // description is '' by default
    expect(txn['Entries'], hasLength(2));
    final entry = (txn['Entries'] as List).first;
    expect(entry['AccountID'], 'a1');
    expect(entry['DebitCents'] + entry['CreditCents'], 500);
    expect(entry['ChartOfAccountCode'], isA<String>());
    expect(entry['TransactionID'], txn['ID']);
  });

  test('goal module aggregates link tables to uuid arrays (rule 3)', () async {
    await accounts.insertAccount(accountRow('g1'));
    final goals = database.goalDao;
    final now = DateTime.utc(2026, 8, 23);
    await goals.insertGoal(db.GoalsCompanion.insert(
      id: 'goal1',
      name: 'save',
      goalType: 1,
      targetAmountCents: 1000,
      currentAmountCents: 0,
      currencyCode: 'CNY',
      notes: '',
      isCompleted: false,
      version: 1,
      createdAt: now,
      updatedAt: now,
    ));
    await goals.insertAccountLink(
        db.GoalAccountLinksCompanion.insert(goalId: 'goal1', linkedId: 'g1'));
    final envelope = await _envelope(exporter);
    final goal = (envelope['modules']['goal'] as List).single;
    expect(goal['LinkedAccountIDs'], ['g1']);
    expect(goal['LinkedDebtIDs'], isEmpty);
  });

  test('holding module carries the two sibling arrays', () async {
    await accounts.insertAccount(accountRow('h-cash'));
    await accounts.insertAccount(accountRow('h-inv'));
    final holding = HoldingLocalDataSource(database, txns);
    final sec = await holding.createSecurity(
        symbol: 'G1', name: 'G1', type: SecurityType.stock, currency: 'CNY');
    await holding.buy(
      accountId: 'h-inv',
      securityId: sec.id,
      fromAccountId: 'h-cash',
      quantity: 2,
      priceCents: 100,
      tradeDate: '2026-08-23',
    );
    final envelope = await _envelope(exporter);
    final holdingModule = envelope['modules']['holding'] as Map;
    expect(holdingModule['holdings'], hasLength(1));
    expect(holdingModule['transactions'], hasLength(1));
    final h = (holdingModule['holdings'] as List).single;
    expect(h['Quantity'], 2);
    expect(h['AvgCostCents'], 100);
    final t = (holdingModule['transactions'] as List).single;
    expect(t['TradeType'], 1); // buy = contract int 1
    expect(t['FeeCents'], 0);
  });

  test('exporter is read-only (idempotent double export)', () async {
    await accounts.insertAccount(accountRow('r1'));
    final e1 = await _envelope(exporter);
    final e2 = await _envelope(exporter);
    expect(e1['modules']['account'], e2['modules']['account']);
    expect((await accounts.getAllAccounts()), hasLength(1));
  });
}

Future<Map<String, dynamic>> _envelope(LocalSnapshotExporter e) async {
  final bytes = await e.exportAll();
  return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
}
