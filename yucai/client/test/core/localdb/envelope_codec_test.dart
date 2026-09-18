// F11 T3(2026-09-05):envelope 行序列化 codec(spec FR-4/FR-5,design ADR-2)。
// 断言的是 T2 集成测试钉死的 server 接受 wire 形态的 client 侧镜像:
// - PascalCase 键(Go 无 json tag 的 domain struct 默认命名即契约);
// - 枚举 int 直传(drift IntColumn ↔ server int 型 domain enum);
// - 时间戳 RFC3339 显式 Z(null 直传 null);
// - 子表嵌套(Entries/Schedule/Items/goal 链接数组);
// - 无 TenantID 键(鉴权 tenant 恒赢)且无 syncState 键(本地私有列不落 wire);
// - 产出可 jsonEncode(无 DateTime 泄漏)。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/envelope_codec.dart';
import 'package:yucai_client/core/localdb/sync_state.dart';

void main() {
  // 通用:wire 上绝不出现 tenant / syncState 键(所有模块断言共用)。
  bool carriesNoLocalKeys(Map<String, dynamic> row) =>
      !row.containsKey('TenantID') && !row.containsKey('syncState');

  group('envelopeTimestamp(RFC3339 显式 Z)', () {
    test('UTC DateTime → ISO8601 Z 串', () {
      expect(envelopeTimestamp(DateTime.utc(2026, 9, 3, 8, 30)),
          '2026-09-03T08:30:00.000Z');
    });

    test('本地时区 DateTime → 折算 UTC 后带 Z', () {
      // +8 时区 16:00 == UTC 08:00:折算后必须带 Z(Go time.RoundTrip 契约)。
      expect(
        envelopeTimestamp(DateTime(2026, 9, 3, 16)),
        endsWith('T08:00:00.000Z'),
      );
    });

    test('null → null(可空时间戳直传)', () {
      expect(envelopeTimestamp(null), isNull);
    });
  });

  group('accountRowToEnvelope', () {
    test('全键 PascalCase 集合 + int 枚举 + 版本/时间戳形态', () {
      final row = db.Account(
        id: 'acc-1',
        name: '现金',
        accountType: 1,
        category: 2,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        currentBalanceCents: 50000,
        ownership: 1,
        icon: 'wallet',
        color: '#102030',
        chartCode: '1001',
        isSystem: false,
        sortOrder: 0,
        institution: '',
        cardNumberTail: '',
        notes: 'from client',
        goldProductType: '',
        status: 1,
        version: 5,
        createdAt: DateTime.utc(2026, 9, 3, 8, 30),
        updatedAt: DateTime.utc(2026, 9, 3, 9),
        syncState: SyncState.pending,
      );

      final out = accountRowToEnvelope(row);

      // T2 syncAccountRow 的键集合逐字对齐(钉死键集,防字段漂移)。
      expect(out.keys, [
        'ID', 'Name', 'AccountType', 'Category', 'CurrencyCode',
        'InitialBalanceCents', 'CurrentBalanceCents', 'Ownership', 'Icon',
        'Color', 'ChartCode', 'ParentID', 'IsSystem', 'SortOrder',
        'Institution', 'CreditLimitCents', 'CardNumberTail', 'Notes',
        'OpeningDate', 'InterestRate', 'CreditBillingDay',
        'CreditRepaymentDay', 'CreditAnnualFeeCents', 'InvestCostCents',
        'InvestMarketValueCents', 'InvestReturnYtd', 'FixedPrincipalCents',
        'FixedStartDate', 'FixedMaturityDate', 'FixedTermMonths',
        'GoldProductType', 'GoldQuantity', 'GoldBuyPriceCents',
        'GoldCurrentPriceCents', 'EstatePurchasePriceCents',
        'EstateCurrentValueCents', 'EstatePurchaseDate',
        'EstateDepreciationRate', 'LoanOriginalCents', 'LoanRemainingCents',
        'LoanMonthlyCents', 'LoanNextPaymentDate', 'Status', 'Version',
        'DeletedAt', 'CreatedAt', 'UpdatedAt',
      ]);
      expect(out['ID'], 'acc-1');
      expect(out['AccountType'], 1); // int 枚举直传
      expect(out['Status'], 1);
      expect(out['Version'], 5); // 客户端版本直传(server 信任)
      expect(out['ParentID'], isNull); // 可空列 null 直传
      expect(out['DeletedAt'], isNull); // 本地删除=硬删+墓碑,无软删
      expect(out['CreatedAt'], '2026-09-03T08:30:00.000Z');
      expect(carriesNoLocalKeys(out), isTrue);
      expect(jsonEncode(out), isA<String>()); // 无 DateTime 泄漏
    });
  });

  group('transactionRowToEnvelope', () {
    test('头行 + 嵌套 Entries(分录 PascalCase 全键)', () {
      final head = db.Transaction(
        id: 'txn-1',
        transactionDate: DateTime.utc(2026, 9, 3),
        transactionTime: DateTime.utc(2026, 9, 3, 10, 15),
        description: 'salary',
        version: 2,
        createdAt: DateTime.utc(2026, 9, 3, 10, 15),
        updatedAt: DateTime.utc(2026, 9, 3, 10, 15),
        syncState: SyncState.pending,
      );
      final entries = [
        const db.TransactionEntry(
          id: 'e-1',
          transactionId: 'txn-1',
          accountId: 'acc-1',
          chartOfAccountCode: '1001',
          debitCents: 500,
          creditCents: 0,
          note: '',
        ),
        const db.TransactionEntry(
          id: 'e-2',
          transactionId: 'txn-1',
          accountId: 'acc-2',
          chartOfAccountCode: '4101',
          debitCents: 0,
          creditCents: 500,
          note: '',
        ),
      ];

      final out = transactionRowToEnvelope(head, entries);

      expect(out['ID'], 'txn-1');
      expect(out['Description'], 'salary');
      expect(out['TransactionDate'], '2026-09-03T00:00:00.000Z');
      expect(out['TransactionTime'], '2026-09-03T10:15:00.000Z');
      final nested = out['Entries'] as List;
      expect(nested, hasLength(2));
      expect(nested.first.keys,
          ['ID', 'TransactionID', 'AccountID', 'ChartOfAccountCode', 'DebitCents', 'CreditCents', 'Note']);
      expect(nested.first['TransactionID'], 'txn-1');
      expect(nested.first['DebitCents'], 500);
      expect(carriesNoLocalKeys(out), isTrue);
      expect(jsonEncode(out), isA<String>());
    });
  });

  group('debtRowToEnvelope', () {
    test('头行 + 嵌套 Schedule', () {
      final debt = db.Debt(
        id: 'debt-1',
        accountId: 'acc-1',
        counterparty: '银行',
        interestRate: 0.03,
        amortizationMethod: 2,
        cycle: 2,
        interval: 1,
        weekdayMask: 0,
        monthlyMode: 0,
        nth: 0,
        interestWaivedCents: 0,
        startDate: DateTime.utc(2026, 9, 1),
        dueDate: DateTime.utc(2026, 10, 1),
        totalPrincipalCents: 10000,
        debtType: 1,
        subtype: 'credit_card',
        contact: '',
        contractRef: '',
        guarantorName: '王担保',
        guarantorContact: '13800000000',
        collectionAccountId: null,
        version: 1,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
        syncState: SyncState.pending,
      );
      final schedule = [
        db.PaymentScheduleEntry(
          id: 's-1',
          debtId: 'debt-1',
          paymentDate: DateTime.utc(2026, 10, 1),
          principalCents: 9000,
          interestCents: 1000,
          totalCents: 10000,
          paidCents: 0,
          paid: false,
          transactionId: null,
        ),
      ];

      final out = debtRowToEnvelope(debt, schedule);

      expect(out['ID'], 'debt-1');
      expect(out['DebtType'], 1); // int 枚举直传
      expect(out['CollectionAccountID'], isNull);
      // F33-T4:上行(update 方向)envelope 逐字携带 subtype(PascalCase 直传)。
      expect(out['Subtype'], 'credit_card');
      // 担保人字段(2026-09):上行 envelope 逐字携带(PascalCase 直传)。
      expect(out['GuarantorName'], '王担保');
      expect(out['GuarantorContact'], '13800000000');
      final nested = out['Schedule'] as List;
      expect(nested.single.keys, [
        'ID', 'DebtID', 'PaymentDate', 'PrincipalCents', 'InterestCents',
        'TotalCents', 'PaidCents', 'Paid', 'TransactionID',
      ]);
      expect(nested.single['Paid'], isFalse);
      expect(carriesNoLocalKeys(out), isTrue);
      expect(jsonEncode(out), isA<String>());
    });
  });

  group('budgetRowToEnvelope', () {
    test('头行 + 嵌套 Items', () {
      final budget = db.Budget(
        id: 'b-1',
        name: '九月',
        month: '2026-09',
        totalAmountCents: 100000,
        currencyCode: 'CNY',
        isActive: true,
        version: 1,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
        syncState: SyncState.pending,
      );
      final items = [
        const db.BudgetItem(
          id: 'i-1',
          budgetId: 'b-1',
          accountId: 'acc-1',
          plannedAmountCents: 60000,
          actualAmountCents: 0,
          notes: '',
        ),
      ];

      final out = budgetRowToEnvelope(budget, items);

      expect(out['ID'], 'b-1');
      expect(out['Month'], '2026-09');
      expect(out['IsActive'], isTrue);
      final nested = out['Items'] as List;
      expect(nested.single.keys, [
        'ID', 'BudgetID', 'AccountID', 'PlannedAmountCents',
        'ActualAmountCents', 'Notes',
      ]);
      expect(carriesNoLocalKeys(out), isTrue);
      expect(jsonEncode(out), isA<String>());
    });
  });

  group('goalRowToEnvelope', () {
    test('链接 uuid 数组(Link 表 → 数组形态)', () {
      final goal = db.Goal(
        id: 'g-1',
        name: '应急金',
        goalType: 1,
        targetAmountCents: 100000,
        currentAmountCents: 0,
        currencyCode: 'CNY',
        deadline: null,
        notes: '',
        isCompleted: false,
        completedAt: null,
        version: 1,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
        syncState: SyncState.pending,
      );

      final out = goalRowToEnvelope(goal, ['acc-1', 'acc-2'], ['debt-1']);

      expect(out['ID'], 'g-1');
      expect(out['GoalType'], 1); // int 枚举直传
      expect(out['LinkedAccountIDs'], ['acc-1', 'acc-2']);
      expect(out['LinkedDebtIDs'], ['debt-1']);
      expect(out['Deadline'], isNull);
      expect(carriesNoLocalKeys(out), isTrue);
      expect(jsonEncode(out), isA<String>());
    });
  });

  group('holdingRowToEnvelope', () {
    test('单持仓行形态(server HoldingWriter 契约:非备份模块双子数组形态)',
        () {
      final holding = db.Holding(
        id: 'h-1',
        accountId: 'acc-1',
        securityId: 'sec-1',
        quantity: 0, // 孤儿分红合成头行的 qty=0 形态也在值域内
        avgCostCents: 0,
        version: 1,
        createdAt: DateTime.utc(2026, 9, 4),
        updatedAt: DateTime.utc(2026, 9, 4),
        syncState: SyncState.pending,
      );

      final out = holdingRowToEnvelope(holding);

      expect(out.keys, [
        'ID', 'AccountID', 'SecurityID', 'Quantity', 'AvgCostCents',
        'Version', 'CreatedAt', 'UpdatedAt',
      ]);
      expect(out['Quantity'], 0.0);
      expect(carriesNoLocalKeys(out), isTrue);
      expect(jsonEncode(out), isA<String>());
    });
  });

  group('holdingTxnRowToEnvelope', () {
    test('台账行 PascalCase 全键(备份 envelope 双子数组内的行形态)', () {
      final txn = db.HoldingTransaction(
        id: 't-1',
        accountId: 'acc-1',
        securityId: 'sec-1',
        tradeType: 3, // dividend(drift int 枚举)
        quantity: 10,
        priceCents: 5,
        amountCents: 50,
        feeCents: 0,
        realizedPnlCents: 0,
        tradeDate: DateTime.utc(2026, 9, 4),
        transactionId: null,
        notes: '',
        createdAt: DateTime.utc(2026, 9, 4),
      );

      final out = holdingTxnRowToEnvelope(txn);

      expect(out.keys, [
        'ID', 'AccountID', 'SecurityID', 'TradeType', 'Quantity', 'PriceCents',
        'AmountCents', 'FeeCents', 'RealizedPnLCents', 'TradeDate',
        'TransactionID', 'Notes', 'CreatedAt',
      ]);
      expect(out['TradeType'], 3); // int 枚举直传
      expect(carriesNoLocalKeys(out), isTrue);
      expect(jsonEncode(out), isA<String>());
    });
  });

  group('tagRowToEnvelope / templateRowToEnvelope', () {
    test('tag 扁平行', () {
      final out = tagRowToEnvelope(db.Tag(
        id: 'tag-1',
        name: '餐饮',
        color: '#FF0000',
        version: 3,
        createdAt: DateTime.utc(2026, 9, 4),
        updatedAt: DateTime.utc(2026, 9, 4),
        syncState: SyncState.pending,
      ));
      expect(out.keys,
          ['ID', 'Name', 'Color', 'Version', 'DeletedAt', 'CreatedAt', 'UpdatedAt']);
      expect(out['Name'], '餐饮');
      expect(carriesNoLocalKeys(out), isTrue);
      expect(jsonEncode(out), isA<String>());
    });

    test('template 扁平行(可空列 null 直传)', () {
      final out = templateRowToEnvelope(db.TransactionTemplate(
        id: 'tpl-1',
        name: '月租',
        description: '',
        amountCents: 300000,
        direction: 1,
        sourceAccountId: 'acc-1',
        destinationAccountId: null,
        cycle: 2,
        cycleDays: 0,
        billingDay: 1,
        interval: 1,
        weekdayMask: 0,
        monthlyMode: 0,
        nth: 0,
        nextDate: DateTime.utc(2026, 10, 1),
        startDate: DateTime.utc(2026, 8, 1),
        endDate: null,
        autoRecord: false,
        paused: false,
        lastTransactionId: null,
        category: '',
        version: 2,
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 9, 4),
        syncState: SyncState.pending,
      ));
      expect(out['ID'], 'tpl-1');
      expect(out['Direction'], 1); // int 枚举直传
      expect(out['DestinationAccountID'], isNull);
      expect(out['NextDate'], '2026-10-01T00:00:00.000Z');
      expect(carriesNoLocalKeys(out), isTrue);
      expect(jsonEncode(out), isA<String>());
    });
  });
}
