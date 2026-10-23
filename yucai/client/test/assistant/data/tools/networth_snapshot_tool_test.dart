// F64-T3 TDD RED → GREEN:networth_snapshot 只读工具(FR-2/ADR-6)。
//
// 口径:与 home 净资产大卡同源 —— NetWorthSnapshotSource port(DI 适配
// NetWorthLocalDataSource)+ BaseCurrencySource 微 port(组合根适配
// CurrencySettings.getBaseCurrency,评审 fixlist M1;NFR-1 逐分
// 一致的前提是同一取数通道,这里用 port 契约钉形状,真库逐分比对见
// tools_caliber_test.dart)。
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/assistant/data/tools/networth_snapshot_tool.dart';
import 'package:yucai_client/assistant/domain/networth_port.dart';
import 'package:yucai_client/assistant/domain/base_currency_port.dart';
import 'package:yucai_client/holding/domain/entities/net_worth_entity.dart';

class _FakeSource implements NetWorthSnapshotSource {
  _FakeSource(this.view);
  final NetWorthView view;
  String? lastBaseCurrency;

  @override
  Future<NetWorthView> fetch({required String baseCurrency}) async {
    lastBaseCurrency = baseCurrency;
    return view;
  }
}

class _ThrowingSource implements NetWorthSnapshotSource {
  @override
  Future<NetWorthView> fetch({required String baseCurrency}) async {
    throw StateError('local db unavailable');
  }
}

class _FakeBaseCurrency implements BaseCurrencySource {
  _FakeBaseCurrency(this._base);
  final String _base;

  @override
  Future<String> getBaseCurrency() async => _base;
}

void main() {
  group('networth_snapshot tool contract', () {
    test('name/schema: no parameters, OpenAI object schema', () {
      final tool = NetWorthSnapshotTool(
          _FakeSource(const NetWorthView(
            totalAssetsCents: 0,
            totalLiabilitiesCents: 0,
            netWorthCents: 0,
            currency: 'CNY',
          )),
          _FakeBaseCurrency('CNY'));
      expect(tool.name, 'networth_snapshot');
      expect(tool.description, isNotEmpty);
      expect(tool.parametersSchema['type'], 'object');
      // 无参工具:不声明任何必填参数。
      expect(tool.parametersSchema.containsKey('required'), isFalse);
    });

    test('execute: dual caliber cents + yuan strings, currency, asOf ISO8601',
        () async {
      final tool = NetWorthSnapshotTool(
          _FakeSource(const NetWorthView(
            totalAssetsCents: 123456789, // ¥1,234,567.89
            totalLiabilitiesCents: 4567, // ¥45.67
            netWorthCents: 123452222, // ¥1,234,522.22
            currency: 'CNY',
          )),
          _FakeBaseCurrency('CNY'));

      final result = await tool.execute(const {});
      expect(result, isA<ToolData>());
      final json = (result as ToolData).json;

      expect(json['totalAssetsCents'], 123456789);
      expect(json['totalLiabilitiesCents'], 4567);
      expect(json['netWorthCents'], 123452222);
      expect(json['currency'], 'CNY');

      // 元字符串:两位小数 + 千分位(与 core DueReminderPolicy.formatYuan
      // 同式 —— 工具复用该 core 纯函数,见实现注释)。
      final formatted = json['formatted'] as Map<String, Object>;
      expect(formatted['totalAssets'], '1,234,567.89');
      expect(formatted['totalLiabilities'], '45.67');
      expect(formatted['netWorth'], '1,234,522.22');

      // asOf:可解析 ISO8601 时刻。
      final asOf = DateTime.parse(json['asOf'] as String);
      expect(asOf.isBefore(DateTime.now().add(const Duration(seconds: 1))),
          isTrue);
    });

    test('execute: base currency flows from BaseCurrencySource into fetch',
        () async {
      final source = _FakeSource(const NetWorthView(
        totalAssetsCents: 1,
        totalLiabilitiesCents: 0,
        netWorthCents: 1,
        currency: 'USD',
      ));
      final tool = NetWorthSnapshotTool(source, _FakeBaseCurrency('USD'));
      await tool.execute(const {});
      expect(source.lastBaseCurrency, 'USD');
    });

    test('execute: negative net worth keeps sign in yuan string', () async {
      final tool = NetWorthSnapshotTool(
          _FakeSource(const NetWorthView(
            totalAssetsCents: 100,
            totalLiabilitiesCents: 200,
            netWorthCents: -100,
            currency: 'CNY',
          )),
          _FakeBaseCurrency('CNY'));
      final json = (await tool.execute(const {}) as ToolData).json;
      expect((json['formatted'] as Map<String, Object>)['netWorth'], '-1.00');
    });

    test('execute: source failure becomes self-correcting ToolError, no throw',
        () async {
      final tool =
          NetWorthSnapshotTool(_ThrowingSource(), _FakeBaseCurrency('CNY'));
      final result = await tool.execute(const {});
      expect(result, isA<ToolError>());
      expect((result as ToolError).message, isNotEmpty);
    });

    test('execute: unexpected args ignored (lenient, no params tool)',
        () async {
      final tool = NetWorthSnapshotTool(
          _FakeSource(const NetWorthView(
            totalAssetsCents: 0,
            totalLiabilitiesCents: 0,
            netWorthCents: 0,
            currency: 'CNY',
          )),
          _FakeBaseCurrency('CNY'));
      final result =
          await tool.execute({'page': 3, 'junk': 'value'}); // 无视多余参数
      expect(result, isA<ToolData>());
    });
  });
}
