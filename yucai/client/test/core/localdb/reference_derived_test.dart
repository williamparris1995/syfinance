import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/localdb/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('reference data (local-owned, FR-2 own-table class)', () {
    test('currency lookup + active filter', () async {
      await db.referenceDao.insertCurrency(CurrenciesCompanion.insert(
        code: 'CNY',
        name: 'Yuan',
        symbol: '¥',
        exchangeRate: 1.0,
        isActive: true,
      ));
      await db.referenceDao.insertCurrency(CurrenciesCompanion.insert(
        code: 'USD',
        name: 'Dollar',
        symbol: r'$',
        exchangeRate: 7.2,
        isActive: false,
      ));
      expect((await db.referenceDao.getCurrencyByCode('CNY'))!.name, 'Yuan');
      expect(
          await db.referenceDao.watchActiveCurrencies().first, hasLength(1));
    });

    test('security + price history + rate history inserts', () async {
      await db.referenceDao.insertSecurity(SecuritiesCompanion.insert(
        id: 'sec1',
        symbol: '600519.SH',
        name: 'Kweichow Moutai',
        securityType: 'stock',
        exchange: 'SSE',
        currencyCode: 'CNY',
        currentPriceCents: 145000,
        createdAt: DateTime.utc(2026, 8, 20),
      ));
      await db.referenceDao.insertSecurityPriceHistory(
          SecurityPriceHistoriesCompanion.insert(
        id: 'ph1',
        securityId: 'sec1',
        priceDate: DateTime.utc(2026, 8, 19),
        priceCents: 144900,
        currencyCode: 'CNY',
        source: 'yahoo',
        createdAt: DateTime.utc(2026, 8, 20),
      ));
      await db.referenceDao
          .insertRateHistory(RateHistoriesCompanion.insert(
        id: 'rh1',
        currencyCode: 'USD',
        rateDate: DateTime.utc(2026, 8, 19),
        exchangeRate: 7.19,
        createdAt: DateTime.utc(2026, 8, 20),
      ));
      expect((await db.referenceDao.getSecurityById('sec1'))!.symbol,
          '600519.SH');
      expect(await db.select(db.securityPriceHistories).get(), hasLength(1));
      expect(await db.select(db.rateHistories).get(), hasLength(1));
    });
  });

  group('derived tables (minimal CRUD until E/H write paths)', () {
    test('snapshot inserts + filtered watches', () async {
      await db.derivedDao.insertDebtProgressSnapshot(
          DebtProgressSnapshotsCompanion.insert(
        id: 'dps1',
        debtId: 'd1',
        snapshotDate: DateTime.utc(2026, 8, 20),
        totalPrincipalCents: 100,
        remainingPrincipalCents: 80,
        paidTotalCents: 20,
        createdAt: DateTime.utc(2026, 8, 20),
      ));
      await db.derivedDao.insertGoalProgressSnapshot(
          GoalProgressSnapshotsCompanion.insert(
        id: 'gps1',
        goalId: 'g1',
        snapshotDate: DateTime.utc(2026, 8, 20),
        currentAmountCents: 42,
        createdAt: DateTime.utc(2026, 8, 20),
      ));
      await db.derivedDao.insertHoldingSnapshot(
          HoldingSnapshotsCompanion.insert(
        id: 'hs1',
        holdingId: 'h1',
        securityId: 'sec1',
        accountId: 'a1',
        snapshotDate: DateTime.utc(2026, 8, 20),
        marketValueCents: 1000,
        unrealizedPnlCents: 100,
        currencyCode: 'CNY',
        createdAt: DateTime.utc(2026, 8, 20),
      ));
      await db.derivedDao.insertHoldingLot(HoldingLotsCompanion.insert(
        id: 'hl1',
        holdingId: 'h1',
        securityId: 'sec1',
        acquiredDate: DateTime.utc(2026, 8, 1),
        acquiredTradeId: 'ht1',
        priceCents: 990,
        quantity: 1.5,
        remainingQuantity: 1.5,
      ));

      expect(
          await db.derivedDao.watchDebtProgressByDebt('d1').first,
          hasLength(1));
      expect(
          await db.derivedDao.watchGoalProgressByGoal('g1').first,
          hasLength(1));
      expect(
          await db.derivedDao.watchHoldingSnapshots('h1').first, hasLength(1));
      expect(await db.select(db.holdingLots).get(), hasLength(1));
    });
  });
}
