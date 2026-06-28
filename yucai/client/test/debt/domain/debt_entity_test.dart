import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

void main() {
  group('Debt.type', () {
    Debt buildDebt({DebtType? type}) {
      final base = Debt(
        id: 'd1',
        accountId: 'a1',
        counterparty: '招行',
        interestRate: 4.2,
        amortization: AmortizationMethod.equalPrincipalInterest,
        startDate: DateTime(2024, 1, 1),
        dueDate: DateTime(2034, 1, 1),
        totalPrincipalCents: 280000000,
        remainingPrincipalCents: 210000000,
        version: 1,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      if (type == null) return base;
      return Debt(
        id: base.id,
        accountId: base.accountId,
        counterparty: base.counterparty,
        interestRate: base.interestRate,
        amortization: base.amortization,
        startDate: base.startDate,
        dueDate: base.dueDate,
        totalPrincipalCents: base.totalPrincipalCents,
        remainingPrincipalCents: base.remainingPrincipalCents,
        version: base.version,
        createdAt: base.createdAt,
        updatedAt: base.updatedAt,
        type: type,
      );
    }

    test('defaults to borrowedIn when omitted', () {
      expect(buildDebt().type, DebtType.borrowedIn);
    });

    test('can be constructed as borrowedOut', () {
      expect(buildDebt(type: DebtType.borrowedOut).type, DebtType.borrowedOut);
    });
  });

  group('Debt.subtype', () {
    Debt buildDebt({String? subtype}) {
      final base = Debt(
        id: 'd1',
        accountId: 'a1',
        counterparty: '招行',
        interestRate: 4.2,
        amortization: AmortizationMethod.equalPrincipalInterest,
        startDate: DateTime(2024, 1, 1),
        dueDate: DateTime(2034, 1, 1),
        totalPrincipalCents: 280000000,
        remainingPrincipalCents: 210000000,
        version: 1,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      if (subtype == null) return base;
      return Debt(
        id: base.id,
        accountId: base.accountId,
        counterparty: base.counterparty,
        interestRate: base.interestRate,
        amortization: base.amortization,
        startDate: base.startDate,
        dueDate: base.dueDate,
        totalPrincipalCents: base.totalPrincipalCents,
        remainingPrincipalCents: base.remainingPrincipalCents,
        version: base.version,
        createdAt: base.createdAt,
        updatedAt: base.updatedAt,
        subtype: subtype,
      );
    }

    test('defaults to empty string when omitted', () {
      expect(buildDebt().subtype, '');
    });

    test('can be constructed with DebtSubtypes.creditCard', () {
      expect(
        buildDebt(subtype: DebtSubtypes.creditCard).subtype,
        DebtSubtypes.creditCard,
      );
    });
  });

  group('DebtSubtypes const', () {
    test('exposes all borrowedIn subtype keys', () {
      expect(DebtSubtypes.all, [
        DebtSubtypes.mortgage,
        DebtSubtypes.autoLoan,
        DebtSubtypes.creditCard,
        DebtSubtypes.family,
        DebtSubtypes.other,
      ]);
    });

    test('labels map covers every key with a Chinese label', () {
      for (final key in DebtSubtypes.all) {
        expect(DebtSubtypes.labels[key], isNotEmpty);
      }
      expect(DebtSubtypes.labels[DebtSubtypes.mortgage], '房贷');
      expect(DebtSubtypes.labels[DebtSubtypes.creditCard], '信用卡');
    });
  });

  group('ReceivableSubtypes const', () {
    test('exposes all borrowedOut subtype keys', () {
      expect(ReceivableSubtypes.all, [
        ReceivableSubtypes.personal,
        ReceivableSubtypes.business,
        ReceivableSubtypes.family,
        ReceivableSubtypes.other,
      ]);
    });

    test('labels map covers every key with a Chinese label', () {
      for (final key in ReceivableSubtypes.all) {
        expect(ReceivableSubtypes.labels[key], isNotEmpty);
      }
      expect(ReceivableSubtypes.labels[ReceivableSubtypes.business], '商业');
    });
  });

  test('Debt.progressRatio = (total - remaining) / total', () {
    final d = Debt(
      id: 'd1',
      accountId: 'a1',
      counterparty: '招行',
      interestRate: 4.2,
      amortization: AmortizationMethod.equalPrincipalInterest,
      startDate: DateTime(2024, 1, 1),
      dueDate: DateTime(2034, 1, 1),
      totalPrincipalCents: 280000000,
      remainingPrincipalCents: 210000000,
      version: 1,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );
    expect(d.progressRatio, closeTo(0.25, 0.001)); // (280-210)/280
  });

  test('PaymentEntry.status 逾期/待还/已还', () {
    final paid = PaymentEntry(
      id: 'e1',
      paymentDate: DateTime(2024, 2, 1),
      principalCents: 100000,
      interestCents: 5000,
      totalCents: 105000,
      paid: true,
      paidCents: 105000,
      transactionId: 't1',
    );
    expect(paid.status, PaymentStatus.paid);

    final overdue = PaymentEntry(
      id: 'e2',
      paymentDate: DateTime(2020, 1, 1),
      principalCents: 100000,
      interestCents: 5000,
      totalCents: 105000,
      paid: false,
      paidCents: 0,
      transactionId: '',
    );
    expect(overdue.status, PaymentStatus.overdue);

    final pending = PaymentEntry(
      id: 'e3',
      paymentDate: DateTime(2099, 1, 1),
      principalCents: 100000,
      interestCents: 5000,
      totalCents: 105000,
      paid: false,
      paidCents: 0,
      transactionId: '',
    );
    expect(pending.status, PaymentStatus.pending);
  });
}
