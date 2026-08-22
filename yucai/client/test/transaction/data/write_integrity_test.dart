// Feature F oracles — balance linkage (apply/reverse/update), FIFO
// insufficiency error, tag-junction idempotency, and restart persistence
// on a real temp-file database.
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db
    hide Holding, Security, Debt, Transaction, TransactionEntry;
import 'package:yucai_client/core/localdb/daos/account_dao.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/tag/data/tag_repository_impl.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

void main() {
  late db.AppDatabase database;
  late TransactionLocalDataSource txns;
  late HoldingLocalDataSource holding;
  late AccountDao accounts;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    txns = TransactionLocalDataSource(database, BalanceLocalUpdater(database));
    holding = HoldingLocalDataSource(database, txns);
    accounts = database.accountDao;
  });

  tearDown(() => database.close());

  Future<String> seedAccount(String name, int type, {int balance = 1000000}) {
    final id = 'acc-$name';
    return accounts.getAccountById(id).then((existing) async {
      if (existing != null) return id;
      await accounts.insertAccount(db.AccountsCompanion.insert(
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

  group('balance linkage', () {
    test('recordExpense moves the asset balance (credit−debit)', () async {
      final cash = await seedAccount('cash', 1, balance: 10000);
      final food = await seedAccount('food', 5);
      await txns.recordExpense(RecordExpenseParams(
        transactionDate: DateTime.utc(2026, 8, 22),
        expenseAccountId: food,
        assetAccountId: cash,
        amountCents: 5000,
      ));
      final after = (await accounts.getAccountById(cash))!;
      expect(after.currentBalanceCents, 5000);
      expect(after.version, 2); // linkage bumps the version
    });

    test('delete reverses the balance', () async {
      final cash = await seedAccount('cash2', 1, balance: 10000);
      final food = await seedAccount('food2', 5);
      final t = await txns.recordExpense(RecordExpenseParams(
        transactionDate: DateTime.utc(2026, 8, 22),
        expenseAccountId: food,
        assetAccountId: cash,
        amountCents: 5000,
      ));
      await txns.delete(t.id);
      expect((await accounts.getAccountById(cash))!.currentBalanceCents,
          10000);
    });

    test('update = reverse old + apply new', () async {
      final a = await seedAccount('ua', 1, balance: 0);
      final b = await seedAccount('ub', 1, balance: 0);
      final t = await txns.recordTransaction(RecordTransactionParams(
        transactionDate: DateTime.utc(2026, 8, 22),
        description: 'x',
        entries: [
          TransactionEntry(accountId: a, debitCents: 100, creditCents: 0),
          TransactionEntry(accountId: b, debitCents: 0, creditCents: 100),
        ],
      ));
      await txns.update(UpdateTransactionParams(
        id: t.id,
        version: t.version,
        description: 'y',
        entries: [
          TransactionEntry(accountId: a, debitCents: 300, creditCents: 0),
          TransactionEntry(accountId: b, debitCents: 0, creditCents: 300),
        ],
      ));
      expect((await accounts.getAccountById(a))!.currentBalanceCents, 300);
      expect((await accounts.getAccountById(b))!.currentBalanceCents, -300);
    });

    test('unknown account id rolls the whole packet back', () async {
      final a = await seedAccount('ra', 1);
      expect(
        () => txns.recordTransaction(RecordTransactionParams(
          transactionDate: DateTime.utc(2026, 8, 22),
          description: 'bad',
          entries: [
            TransactionEntry(accountId: a, debitCents: 50, creditCents: 0),
            TransactionEntry(
                accountId: 'ghost', debitCents: 0, creditCents: 50),
          ],
        )),
        throwsA(isA<ServerFailure>()),
      );
      expect((await accounts.getAccountById(a))!.currentBalanceCents, 1000000);
      expect(await database.transactionDao.getAllTransactions(), isEmpty);
    });

    test('holding buy moves cash via the shared linkage', () async {
      final cash = await seedAccount('h-cash', 1, balance: 10000);
      final inv = await seedAccount('h-inv', 1, balance: 0);
      final sec = await holding.createSecurity(
          symbol: 'F1', name: 'F1', type: SecurityType.stock, currency: 'CNY');
      await holding.buy(
        accountId: inv,
        securityId: sec.id,
        fromAccountId: cash,
        quantity: 10,
        priceCents: 100,
        tradeDate: '2026-08-01',
      );
      expect((await accounts.getAccountById(cash))!.currentBalanceCents, 9000);
      expect((await accounts.getAccountById(inv))!.currentBalanceCents, 1000);
    });
  });

  group('FIFO insufficiency + tag idempotency', () {
    test('selling more than the remaining lots errors', () async {
      final cash = await seedAccount('f-cash', 1);
      final inv = await seedAccount('f-inv', 1);
      final sec = await holding.createSecurity(
          symbol: 'F2', name: 'F2', type: SecurityType.stock, currency: 'CNY');
      await holding.buy(
          accountId: inv,
          securityId: sec.id,
          fromAccountId: cash,
          quantity: 10,
          priceCents: 100,
          tradeDate: '2026-08-01');
      expect(
        () => holding.sell(
            accountId: inv,
            securityId: sec.id,
            fromAccountId: cash,
            quantity: 20, // more than the lots hold
            priceCents: 100,
            tradeDate: '2026-08-02'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('adding the same tag twice is an idempotent success', () async {
      final tags = TagLocalDataSource(database);
      final tag = await tags.create(name: 't', color: '#000000');
      final a = await seedAccount('tag-a', 1);
      final t = await txns.recordTransaction(RecordTransactionParams(
        transactionDate: DateTime.utc(2026, 8, 22),
        description: 'x',
        entries: [
          TransactionEntry(accountId: a, debitCents: 1, creditCents: 0),
          TransactionEntry(accountId: a, debitCents: 0, creditCents: 1),
        ],
      ));
      await tags.addTagToTransaction(tagId: tag.id, transactionId: t.id);
      // Second application: no-op success, still exactly one junction row.
      await tags.addTagToTransaction(tagId: tag.id, transactionId: t.id);
      expect(await tags.getTransactionTags(t.id), hasLength(1));
      // Unknown sides are rejected.
      expect(
        () => tags.addTagToTransaction(
            tagId: 'ghost', transactionId: t.id),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  group('restart persistence (temp file db)', () {
    test('full guest chain survives close + reopen', () async {
      final dir = await Directory.systemTemp.createTemp('yucai-f-');
      final file = File('${dir.path}/restart.db');
      late db.AppDatabase db2;
      try {
        db2 = db.AppDatabase(NativeDatabase(file));
        final txns2 =
            TransactionLocalDataSource(db2, BalanceLocalUpdater(db2));
        final holding2 =
            HoldingLocalDataSource(db2, txns2);
        final accounts2 = db2.accountDao;
        await accounts2.insertAccount(db.AccountsCompanion.insert(
          id: 'cash',
          name: '现金',
          accountType: 1,
          category: 2,
          currencyCode: 'CNY',
          initialBalanceCents: 10000,
          currentBalanceCents: 10000,
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
        await accounts2.insertAccount(db.AccountsCompanion.insert(
          id: 'food',
          name: '餐饮',
          accountType: 5,
          category: 2,
          currencyCode: 'CNY',
          initialBalanceCents: 0,
          currentBalanceCents: 0,
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
        await txns2.recordExpense(RecordExpenseParams(
          transactionDate: DateTime.utc(2026, 8, 22),
          expenseAccountId: 'food',
          assetAccountId: 'cash',
          amountCents: 2500,
        ));
        await db2.close();

        // Reopen the same file: data + linked balance intact.
        final db3 = db.AppDatabase(NativeDatabase(file));
        final cashRow = await db3.accountDao.getAccountById('cash');
        expect(cashRow!.currentBalanceCents, 7500);
        expect(await db3.transactionDao.getAllTransactions(), hasLength(1));
        expect(await db3.transactionDao.getAllEntries(), hasLength(2));
        // Integrity check passes on the reopened store.
        final (ok, detail) = await db3.integrityCheck();
        expect(ok, isTrue, reason: detail);
        await db3.close();
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
