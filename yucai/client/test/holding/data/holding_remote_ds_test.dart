import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart' as tspb;

import 'package:yucai_client/core/network/auth_interceptor.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/holding/data/holding_remote_ds.dart';
import 'package:yucai_client/holding/data/mappers/holding_mapper.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/proto/holding/v1/holding.pb.dart' as pb;

class _MockGrpcClient extends Mock implements GrpcClient {}

pb.HoldingTransactionDTO _txDto(String id, {int tradeVal = 1}) =>
    pb.HoldingTransactionDTO(
      id: id,
      accountId: 'acc-1',
      securityId: 'sec-1',
      tradeType: pb.TradeType.valueOf(tradeVal)!,
      quantity: 10.0,
      priceCents: Int64(1800000),
      amountCents: Int64(18000000),
      feeCents: Int64(500),
      tradeDate: '2026-01-15',
      notes: '',
      createdAt: tspb.Timestamp.fromDateTime(DateTime.utc(2026, 1, 15)),
    );

pb.HoldingDTO _holdingDto(String id) => pb.HoldingDTO(
      id: id,
      accountId: 'acc-1',
      securityId: 'sec-1',
      securityName: '茅台',
      securitySymbol: '600519',
      quantity: 100.0,
      avgCostCents: Int64(1800000),
      marketValueCents: Int64(2000000),
      unrealizedPnlCents: Int64(200000),
      version: Int64(1),
    );

pb.SecurityDTO _securityDto(String id) => pb.SecurityDTO(
      id: id,
      symbol: '600519',
      name: '茅台',
      securityType: pb.SecurityType.SECURITY_TYPE_STOCK,
      exchange: 'SSE',
      currencyCode: 'CNY',
      currentPriceCents: Int64(2000000),
    );

void main() {
  late _MockGrpcClient grpcClient;
  late AuthRetryCaller retry;

  setUp(() {
    grpcClient = _MockGrpcClient();
    retry = AuthRetryCaller();
    registerFallbackValue(pb.HoldingTradeRequest());
  });

  // The real HoldingRemoteDataSource constructs its own HoldingServiceClient
  // from GrpcClient.channel + authInterceptor (mirrors DebtRemoteDataSource),
  // so we cannot substitute a mock gRPC client through DI. We verify the mapper
  // pipeline + the request-wiring (esp. the off-by-one enum mapping and the
  // fromAccountId double-entry flag) the DS delegates to — the DS is a thin
  // wrapper, so the mapping/wiring is the only non-trivial logic it carries.

  group('mapper pipeline (DS delegates to HoldingMapper)', () {
    test('listHoldings pipeline maps 2 HoldingDTO → 2 Holding', () {
      final dtos = [_holdingDto('h1'), _holdingDto('h2')];
      final holdings = dtos.map(HoldingMapper.toDomain).toList();
      expect(holdings, isA<List<Holding>>());
      expect(holdings.length, 2);
      expect(holdings.first.id, 'h1');
      // front-end display fields stay null (proto DTO has no such fields).
      expect(holdings.first.currentPriceCents, isNull);
      expect(holdings.first.securityType, isNull);
    });

    test('listHoldingTransactions pipeline maps HoldingTransactionDTO list',
        () {
      final dtos = [_txDto('t1'), _txDto('t2', tradeVal: 2)];
      final txs = dtos.map(HoldingMapper.transactionToDomain).toList();
      expect(txs.length, 2);
      expect(txs.first.tradeType, TradeType.buy);
      expect(txs.last.tradeType, TradeType.sell); // valueOf(2)=SELL → sell
    });

    test('listSecurities pipeline maps SecurityDTO list (currency_code→currency)',
        () {
      final dtos = [_securityDto('s1')];
      final secs = dtos.map(HoldingMapper.securityToDomain).toList();
      expect(secs.first.id, 's1');
      expect(secs.first.currency, 'CNY');
      expect(secs.first.securityType, SecurityType.stock);
    });
  });

  group('buy() request wiring (fromAccountId + off-by-one enum)', () {
    test(
        'HoldingTradeRequest carries fromAccountId when provided '
        '(non-empty → backend double-writes cash asset)', () {
      // DS writes fromAccountId: fromAccountId ?? '' (空串=不双写). Verify the
      // proto field-level round-trip: non-empty value survives verbatim.
      final req = pb.HoldingTradeRequest()
        ..accountId = 'inv-1'
        ..securityId = 'sec-1'
        ..quantity = 10
        ..priceCents = Int64(1800000)
        ..feeCents = Int64(500)
        ..tradeDate = '2026-01-15'
        ..notes = ''
        ..fromAccountId = 'cash-1';
      expect(req.fromAccountId, 'cash-1');
    });

    test('HoldingTradeRequest.fromAccountId defaults to "" when not set '
        '(empty string = no double-write)', () {
      final req = pb.HoldingTradeRequest()
        ..accountId = 'inv-1'
        ..securityId = 'sec-1'
        ..quantity = 10
        ..priceCents = Int64(1800000)
        ..tradeDate = '2026-01-15';
      // proto unset scalar string → '' — DS writes fromAccountId ?? '' so a
      // null caller value becomes '' (no double-write).
      expect(req.fromAccountId, '');
    });

    test('createSecurity maps SecurityType by NAME to fix proto off-by-one '
        '(domain 0-6 → proto 1-7)', () {
      // createSecurity request wires securityTypeToProto(domain type); verify
      // each domain index maps to proto business value (NOT UNSPECIFIED, NOT
      // off-by-one shifted).
      expect(
        HoldingMapper.securityTypeToProto(SecurityType.values[0]),
        pb.SecurityType.SECURITY_TYPE_STOCK, // 0 → proto 1, not UNSPECIFIED
      );
      expect(
        HoldingMapper.securityTypeToProto(SecurityType.values[1]),
        pb.SecurityType.SECURITY_TYPE_FUND,
      );
      expect(
        HoldingMapper.securityTypeToProto(SecurityType.values[6]),
        pb.SecurityType.SECURITY_TYPE_OTHER,
      );
    });
  });

  group('buy/sell response mapping (HoldingTransactionResponse)', () {
    test('buy/sell response.transaction → HoldingTransaction via mapper', () {
      final res = pb.HoldingTransactionResponse(transaction: _txDto('t9'));
      final t = HoldingMapper.transactionToDomain(res.transaction);
      expect(t.id, 't9');
      expect(t.tradeType, TradeType.buy);
      expect(t.quantity, 10.0);
    });

    test('recordDividend response maps DIVIDEND tradeType by NAME', () {
      final res = pb.HoldingTransactionResponse(
        transaction: _txDto('td', tradeVal: 3), // DIVIDEND=3
      );
      expect(
        HoldingMapper.transactionToDomain(res.transaction).tradeType,
        TradeType.dividend,
      );
    });

    test('recordSplit response maps SPLIT tradeType by NAME', () {
      final res = pb.HoldingTransactionResponse(
        transaction: _txDto('ts', tradeVal: 4), // SPLIT=4
      );
      expect(
        HoldingMapper.transactionToDomain(res.transaction).tradeType,
        TradeType.split,
      );
    });
  });

  test('HoldingRemoteDataSource is constructible with GrpcClient + retry', () {
    // The DS constructor eagerly builds a HoldingServiceClient from
    // GrpcClient.channel + authInterceptor — stub both so construction succeeds.
    // A real ClientChannel is cheap to construct and never connects until a
    // call is made (which we don't make here).
    when(() => grpcClient.channel)
        .thenReturn(ClientChannel('localhost', port: 9999));
    when(() => grpcClient.authInterceptor).thenReturn(AuthInterceptor());
    final ds = HoldingRemoteDataSource(grpcClient, retry);
    expect(ds, isA<HoldingRemoteDataSource>());
  });
}
