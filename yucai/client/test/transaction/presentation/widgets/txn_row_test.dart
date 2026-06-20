// TDD widget tests for TxnRow (Task 3: 转账双账户箭头).
//
// Covers the two rendering branches the spec (P0-3) demands:
//   - transfer (type==transfer): 「转出 → 转入」双账户 + arrow_forward icon
//     from = creditCents>0 entry (贷方=转出) / to = debitCents>0 entry (借方=转入)
//   - non-transfer (income/expense): single asset account + category chip
//
// The TxnRow takes a `Map<String, Account> accounts` so it can resolve
// accountId → name and decide asset-vs-category by AccountType.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';
import 'package:yucai_client/transaction/presentation/widgets/txn_row.dart';

Account _account(
  String id,
  String name, {
  AccountType accountType = AccountType.asset,
  AccountCategory category = AccountCategory.savings,
}) {
  return Account(
    id: id,
    name: name,
    accountType: accountType,
    category: category,
    currencyCode: 'CNY',
    initialBalanceCents: 0,
    currentBalanceCents: 0,
    ownership: Ownership.personal,
    status: AccountStatus.active,
  );
}

Widget _harness(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  group('TxnRow transfer branch', () {
    testWidgets('shows from → to accounts with arrow (desktop)', (tester) async {
      // 转账：贷 from（招商银行转出）/ 借 to（余额宝转入）。
      final Transaction txn = Transaction(
        id: 't1',
        transactionDate: DateTime(2026, 6, 19),
        description: '转账',
        entries: [
          TransactionEntry(
              accountId: 'from-id', debitCents: 0, creditCents: 10000),
          TransactionEntry(
              accountId: 'to-id', debitCents: 10000, creditCents: 0),
        ],
      );
      final accounts = {
        'from-id': _account('from-id', '招商银行'),
        'to-id': _account('to-id', '余额宝'),
      };

      await tester.pumpWidget(_harness(
        TxnRow(
          txn: txn,
          accounts: accounts,
          breakpoint: Breakpoint.desktop,
        ),
      ));

      expect(find.text('招商银行'), findsOneWidget);
      expect(find.text('余额宝'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('mobile card副行 shows from → to', (tester) async {
      final Transaction txn = Transaction(
        id: 't2',
        transactionDate: DateTime(2026, 6, 19),
        description: '转账 m',
        entries: [
          TransactionEntry(
              accountId: 'from-id', debitCents: 0, creditCents: 5000),
          TransactionEntry(
              accountId: 'to-id', debitCents: 5000, creditCents: 0),
        ],
      );
      final accounts = {
        'from-id': _account('from-id', '现金'),
        'to-id': _account('to-id', '支付宝'),
      };

      await tester.pumpWidget(_harness(
        TxnRow(
          txn: txn,
          accounts: accounts,
          breakpoint: Breakpoint.mobile,
        ),
      ));

      expect(find.text('现金'), findsOneWidget);
      expect(find.text('支付宝'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });
  });

  group('TxnRow non-transfer branch', () {
    testWidgets('expense: single asset account + category chip (desktop)',
        (tester) async {
      // 支出：借 餐饮（expense 分类账户）/ 贷 招商银行（asset）。
      final Transaction txn = Transaction(
        id: 'e1',
        transactionDate: DateTime(2026, 6, 19),
        description: '午餐',
        entries: [
          TransactionEntry(
              accountId: 'food-id', debitCents: 3000, creditCents: 0),
          TransactionEntry(
              accountId: 'bank-id', debitCents: 0, creditCents: 3000),
        ],
      );
      final accounts = {
        'food-id': _account('food-id', '餐饮',
            accountType: AccountType.expense, category: AccountCategory.savings),
        'bank-id': _account('bank-id', '招商银行'),
      };

      await tester.pumpWidget(_harness(
        TxnRow(
          txn: txn,
          accounts: accounts,
          breakpoint: Breakpoint.desktop,
        ),
      ));

      // 单资产账户显示一次；分类账户不作为账户标签出现。
      expect(find.text('招商银行'), findsOneWidget);
      // 分类 chip 显示分类 label（餐饮账户的 category label）。
      expect(find.text('储蓄'), findsOneWidget);
      // 非转账无箭头。
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });
  });
}
