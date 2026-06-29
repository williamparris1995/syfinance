import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:flutter_test/flutter_test.dart';
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart' as tspb;

import 'package:yucai_client/holding/data/mappers/holding_mapper.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/proto/holding/v1/holding.pb.dart' as pb;

void main() {
  group('SecurityType NAME mapping (off-by-one)', () {
    test('securityTypeFromProto: every business value by NAME', () {
      // ⚠️ proto SECURITY_TYPE_STOCK=1 ↔ domain stock=0 (off-by-one).
      // Assert by symbol NAME, NOT by int index.
      expect(
        HoldingMapper.securityTypeFromProto(pb.SecurityType.SECURITY_TYPE_STOCK),
        SecurityType.stock,
      );
      expect(
        HoldingMapper.securityTypeFromProto(pb.SecurityType.SECURITY_TYPE_FUND),
        SecurityType.fund,
      );
      expect(
        HoldingMapper.securityTypeFromProto(pb.SecurityType.SECURITY_TYPE_ETF),
        SecurityType.etf,
      );
      expect(
        HoldingMapper.securityTypeFromProto(pb.SecurityType.SECURITY_TYPE_BOND),
        SecurityType.bond,
      );
      expect(
        HoldingMapper.securityTypeFromProto(pb.SecurityType.SECURITY_TYPE_GOLD),
        SecurityType.gold,
      );
      expect(
        HoldingMapper.securityTypeFromProto(
            pb.SecurityType.SECURITY_TYPE_OPTION),
        SecurityType.option,
      );
      expect(
        HoldingMapper.securityTypeFromProto(pb.SecurityType.SECURITY_TYPE_OTHER),
        SecurityType.other,
      );
    });

    test('securityTypeFromProto: UNSPECIFIED(0) collapses to other', () {
      // UNSPECIFIED must NOT map by int (would become stock=0). Collapse to
      // 'other' (the catch-all, matching domain intent for unknown securities).
      expect(
        HoldingMapper.securityTypeFromProto(
            pb.SecurityType.SECURITY_TYPE_UNSPECIFIED),
        SecurityType.other,
      );
    });

    test('securityTypeToProto: every domain value', () {
      expect(
        HoldingMapper.securityTypeToProto(SecurityType.stock),
        pb.SecurityType.SECURITY_TYPE_STOCK,
      );
      expect(
        HoldingMapper.securityTypeToProto(SecurityType.fund),
        pb.SecurityType.SECURITY_TYPE_FUND,
      );
      expect(
        HoldingMapper.securityTypeToProto(SecurityType.etf),
        pb.SecurityType.SECURITY_TYPE_ETF,
      );
      expect(
        HoldingMapper.securityTypeToProto(SecurityType.bond),
        pb.SecurityType.SECURITY_TYPE_BOND,
      );
      expect(
        HoldingMapper.securityTypeToProto(SecurityType.gold),
        pb.SecurityType.SECURITY_TYPE_GOLD,
      );
      expect(
        HoldingMapper.securityTypeToProto(SecurityType.option),
        pb.SecurityType.SECURITY_TYPE_OPTION,
      );
      expect(
        HoldingMapper.securityTypeToProto(SecurityType.other),
        pb.SecurityType.SECURITY_TYPE_OTHER,
      );
    });

    test('securityTypeToProto ∘ securityTypeFromProto is identity', () {
      // Round-trip over all proto business values (excludes UNSPECIFIED, which
      // has no inverse in domain).
      for (final proto in [
        pb.SecurityType.SECURITY_TYPE_STOCK,
        pb.SecurityType.SECURITY_TYPE_FUND,
        pb.SecurityType.SECURITY_TYPE_ETF,
        pb.SecurityType.SECURITY_TYPE_BOND,
        pb.SecurityType.SECURITY_TYPE_GOLD,
        pb.SecurityType.SECURITY_TYPE_OPTION,
        pb.SecurityType.SECURITY_TYPE_OTHER,
      ]) {
        expect(
          HoldingMapper.securityTypeToProto(
              HoldingMapper.securityTypeFromProto(proto)),
          proto,
        );
      }
    });
  });

  group('TradeType NAME mapping (off-by-one)', () {
    test('tradeTypeFromProto: every business value by NAME', () {
      // ⚠️ proto TRADE_TYPE_BUY=1 ↔ domain buy=0 (off-by-one).
      expect(
        HoldingMapper.tradeTypeFromProto(pb.TradeType.TRADE_TYPE_BUY),
        TradeType.buy,
      );
      expect(
        HoldingMapper.tradeTypeFromProto(pb.TradeType.TRADE_TYPE_SELL),
        TradeType.sell,
      );
      expect(
        HoldingMapper.tradeTypeFromProto(pb.TradeType.TRADE_TYPE_DIVIDEND),
        TradeType.dividend,
      );
      expect(
        HoldingMapper.tradeTypeFromProto(pb.TradeType.TRADE_TYPE_SPLIT),
        TradeType.split,
      );
    });

    test('tradeTypeFromProto: UNSPECIFIED(0) collapses to buy', () {
      // UNSPECIFIED → buy (sensible default; matches the most common trade
      // action and avoids the off-by-one int trap that would yield buy=0
      // by accident — here it is explicit).
      expect(
        HoldingMapper.tradeTypeFromProto(pb.TradeType.TRADE_TYPE_UNSPECIFIED),
        TradeType.buy,
      );
    });

    test('tradeTypeToProto: every domain value', () {
      expect(
        HoldingMapper.tradeTypeToProto(TradeType.buy),
        pb.TradeType.TRADE_TYPE_BUY,
      );
      expect(
        HoldingMapper.tradeTypeToProto(TradeType.sell),
        pb.TradeType.TRADE_TYPE_SELL,
      );
      expect(
        HoldingMapper.tradeTypeToProto(TradeType.dividend),
        pb.TradeType.TRADE_TYPE_DIVIDEND,
      );
      expect(
        HoldingMapper.tradeTypeToProto(TradeType.split),
        pb.TradeType.TRADE_TYPE_SPLIT,
      );
    });

    test('tradeTypeToProto ∘ tradeTypeFromProto is identity', () {
      for (final proto in [
        pb.TradeType.TRADE_TYPE_BUY,
        pb.TradeType.TRADE_TYPE_SELL,
        pb.TradeType.TRADE_TYPE_DIVIDEND,
        pb.TradeType.TRADE_TYPE_SPLIT,
      ]) {
        expect(
          HoldingMapper.tradeTypeToProto(
              HoldingMapper.tradeTypeFromProto(proto)),
          proto,
        );
      }
    });
  });

  group('HoldingMapper.toDomain (HoldingDTO → Holding)', () {
    test('maps all core fields; front-end display fields stay null', () {
      final dto = pb.HoldingDTO(
        id: 'h1',
        accountId: 'acc-1',
        securityId: 'sec-1',
        securityName: '茅台',
        securitySymbol: '600519',
        quantity: 100.0,
        avgCostCents: $fixnum.Int64(1800000),
        marketValueCents: $fixnum.Int64(2000000),
        unrealizedPnlCents: $fixnum.Int64(200000),
        version: $fixnum.Int64(3),
      );
      final h = HoldingMapper.toDomain(dto);
      expect(h.id, 'h1');
      expect(h.accountId, 'acc-1');
      expect(h.securityId, 'sec-1');
      expect(h.securityName, '茅台');
      expect(h.securitySymbol, '600519');
      expect(h.quantity, 100.0);
      expect(h.avgCostCents, 1800000);
      expect(h.marketValueCents, 2000000);
      expect(h.unrealizedPnlCents, 200000);
      expect(h.version, 3);
      // proto HoldingDTO has no price/pnlPct/securityType/currency → all null.
      expect(h.currentPriceCents, isNull);
      expect(h.pnlPct, isNull);
      expect(h.securityType, isNull);
      expect(h.currency, isNull);
    });
  });

  group('HoldingMapper.securityToDomain (SecurityDTO → Security)', () {
    test('maps all fields incl currency_code → currency', () {
      final dto = pb.SecurityDTO(
        id: 'sec-1',
        symbol: '600519',
        name: '茅台',
        securityType: pb.SecurityType.SECURITY_TYPE_STOCK,
        exchange: 'SSE',
        currencyCode: 'CNY',
        currentPriceCents: $fixnum.Int64(2000000),
        // toDateTime() returns UTC; compare in UTC to avoid TZ mismatch.
        createdAt: tspb.Timestamp.fromDateTime(DateTime.utc(2026, 1, 2)),
      );
      final s = HoldingMapper.securityToDomain(dto);
      expect(s.id, 'sec-1');
      expect(s.symbol, '600519');
      expect(s.name, '茅台');
      expect(s.securityType, SecurityType.stock);
      expect(s.exchange, 'SSE');
      expect(s.currency, 'CNY'); // currency_code → currency
      expect(s.currentPriceCents, 2000000);
      expect(s.createdAt, DateTime.utc(2026, 1, 2));
    });

    test('securityType UNSPECIFIED → other; null createdAt stays null', () {
      final dto = pb.SecurityDTO(
        id: 'sec-2',
        symbol: 'X',
        name: 'Unknown',
        securityType: pb.SecurityType.SECURITY_TYPE_UNSPECIFIED,
        currencyCode: 'USD',
        currentPriceCents: $fixnum.Int64(0),
      );
      final s = HoldingMapper.securityToDomain(dto);
      expect(s.securityType, SecurityType.other);
      expect(s.exchange, ''); // unset proto scalar defaults to ''
      expect(s.createdAt, isNull);
    });
  });

  group(
      'HoldingMapper.transactionToDomain (HoldingTransactionDTO → HoldingTransaction)',
      () {
    test('maps all fields incl tradeType by NAME', () {
      final dto = pb.HoldingTransactionDTO(
        id: 't1',
        accountId: 'acc-1',
        securityId: 'sec-1',
        tradeType: pb.TradeType.TRADE_TYPE_BUY,
        quantity: 10.0,
        priceCents: $fixnum.Int64(1800000),
        amountCents: $fixnum.Int64(18000000),
        feeCents: $fixnum.Int64(500),
        tradeDate: '2026-01-15',
        notes: 'first buy',
        // toDateTime() returns UTC; compare in UTC to avoid TZ mismatch.
        createdAt: tspb.Timestamp.fromDateTime(DateTime.utc(2026, 1, 15)),
      );
      final t = HoldingMapper.transactionToDomain(dto);
      expect(t.id, 't1');
      expect(t.accountId, 'acc-1');
      expect(t.securityId, 'sec-1');
      expect(t.tradeType, TradeType.buy);
      expect(t.quantity, 10.0);
      expect(t.priceCents, 1800000);
      expect(t.amountCents, 18000000);
      expect(t.feeCents, 500);
      expect(t.tradeDate, '2026-01-15');
      expect(t.notes, 'first buy');
      expect(t.createdAt, DateTime.utc(2026, 1, 15));
    });

    test('SELL/DIVIDEND/SPLIT map by NAME (not int)', () {
      for (final entry in {
        pb.TradeType.TRADE_TYPE_SELL: TradeType.sell,
        pb.TradeType.TRADE_TYPE_DIVIDEND: TradeType.dividend,
        pb.TradeType.TRADE_TYPE_SPLIT: TradeType.split,
      }.entries) {
        final dto = pb.HoldingTransactionDTO(
          id: 't',
          accountId: 'a',
          securityId: 's',
          tradeType: entry.key,
          quantity: 1,
          priceCents: $fixnum.Int64(1),
          amountCents: $fixnum.Int64(1),
          feeCents: $fixnum.Int64(0),
          tradeDate: '2026-01-01',
        );
        expect(HoldingMapper.transactionToDomain(dto).tradeType, entry.value);
      }
    });

    test('UNSPECIFIED tradeType → buy; null createdAt stays null', () {
      final dto = pb.HoldingTransactionDTO(
        id: 't2',
        accountId: 'a',
        securityId: 's',
        tradeType: pb.TradeType.TRADE_TYPE_UNSPECIFIED,
        quantity: 1,
        priceCents: $fixnum.Int64(1),
        amountCents: $fixnum.Int64(1),
        feeCents: $fixnum.Int64(0),
        tradeDate: '2026-01-01',
      );
      final t = HoldingMapper.transactionToDomain(dto);
      expect(t.tradeType, TradeType.buy);
      expect(t.notes, ''); // unset scalar default
      expect(t.createdAt, isNull);
    });
  });
}
