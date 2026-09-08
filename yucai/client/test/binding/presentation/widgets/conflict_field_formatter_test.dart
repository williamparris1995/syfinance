// F18-T3(spec FR-5,design ADR-5):ConflictFieldFormatter 单测 —— 冲突面板
// 双栏摘要的纯函数面:
// - 9 模块(SyncModule 全值域)各自的 2-3 关键字段选取(键知识来自
//   envelope_codec 的 per-module 行形态);
// - 坏 payload 容错(null bytes / 非 JSON / JSON 非 Map / 无已知键)→
//   「(无法解析)」单行兜底;
// - 中文模块名映射(moduleLabel,模块徽章文案);
// - createdAt 相对时间(relativeTime,面板条目「x 分钟前」)。
//
// payload 构造直接用 envelope 形态的最小 JSON(PascalCase 键 + RFC3339 Z
// 时间戳 + cents 金额),与 envelope_codec 产出的行键集对齐(单一事实源在
// 生产侧,测试只钉消费面)。
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/binding/presentation/widgets/conflict_field_formatter.dart';
import 'package:yucai_client/core/localdb/sync_state.dart' show SyncModule;

/// envelope 行 JSON → payload bytes(port/server 携带的 wire 形态)。
Uint8List _p(Map<String, dynamic> row) =>
    Uint8List.fromList(utf8.encode(jsonEncode(row)));

void main() {
  group('summarize:9 模块关键字段', () {
    test('account:名称/金额/日期(余额 cents → ¥)', () {
      final lines = ConflictFieldFormatter.summarize(SyncModule.account, _p({
        'ID': 'a-1',
        'Name': '现金账户',
        'CurrentBalanceCents': 123456,
        'OpeningDate': '2026-09-01T00:00:00.000Z',
      }));
      expect(lines, ['名称:现金账户', '金额:¥1234.56', '日期:2026-09-01']);
    });

    test('account:负金额带符号', () {
      final lines = ConflictFieldFormatter.summarize(SyncModule.account, _p({
        'Name': '信用卡',
        'CurrentBalanceCents': -500,
      }));
      expect(lines, ['名称:信用卡', '金额:-¥5.00']);
    });

    test('transaction:描述/金额(分录借方合计)/日期', () {
      final lines = ConflictFieldFormatter.summarize(SyncModule.transaction, _p({
        'ID': 't-1',
        'Description': '超市采购',
        'TransactionDate': '2026-09-05T08:30:00.000Z',
        'Entries': [
          {'ID': 'e-1', 'DebitCents': 8800, 'CreditCents': 0},
          {'ID': 'e-2', 'DebitCents': 0, 'CreditCents': 8800},
        ],
      }));
      expect(lines, ['描述:超市采购', '金额:¥88.00', '日期:2026-09-05']);
    });

    test('debt:对方/金额(本金)/日期(到期)', () {
      final lines = ConflictFieldFormatter.summarize(SyncModule.debt, _p({
        'Counterparty': '张三',
        'TotalPrincipalCents': 5000000,
        'DueDate': '2027-01-01T00:00:00.000Z',
      }));
      expect(lines, ['对方:张三', '金额:¥50000.00', '日期:2027-01-01']);
    });

    test('budget:名称/金额/月份', () {
      final lines = ConflictFieldFormatter.summarize(SyncModule.budget, _p({
        'Name': '九月预算',
        'TotalAmountCents': 300000,
        'Month': '2026-09',
      }));
      expect(lines, ['名称:九月预算', '金额:¥3000.00', '月份:2026-09']);
    });

    test('goal:名称/金额(目标)/日期(截止)', () {
      final lines = ConflictFieldFormatter.summarize(SyncModule.goal, _p({
        'Name': '应急基金',
        'TargetAmountCents': 10000000,
        'Deadline': '2027-06-30T00:00:00.000Z',
      }));
      expect(lines, ['名称:应急基金', '金额:¥100000.00', '日期:2027-06-30']);
    });

    test('holding:数量/成本/日期(无名称键,持仓头行形态)', () {
      final lines = ConflictFieldFormatter.summarize(SyncModule.holding, _p({
        'Quantity': 1.5,
        'AvgCostCents': 20500,
        'CreatedAt': '2026-08-01T00:00:00.000Z',
      }));
      expect(lines, ['数量:1.5', '成本:¥205.00', '日期:2026-08-01']);
    });

    test('holding_ledger:类型(1 买入)/金额/日期', () {
      final lines =
          ConflictFieldFormatter.summarize(SyncModule.holdingLedger, _p({
        'TradeType': 1,
        'AmountCents': 123000,
        'TradeDate': '2026-09-02T00:00:00.000Z',
      }));
      expect(lines, ['类型:买入', '金额:¥1230.00', '日期:2026-09-02']);
    });

    test('holding_ledger:类型 2 → 卖出', () {
      final lines =
          ConflictFieldFormatter.summarize(SyncModule.holdingLedger, _p({
        'TradeType': 2,
        'AmountCents': 100,
      }));
      expect(lines, ['类型:卖出', '金额:¥1.00']);
    });

    test('tag:名称/日期(无金额面)', () {
      final lines = ConflictFieldFormatter.summarize(SyncModule.tag, _p({
        'Name': '餐饮',
        'Color': '#ff0000',
        'UpdatedAt': '2026-09-06T12:00:00.000Z',
      }));
      expect(lines, ['名称:餐饮', '日期:2026-09-06']);
    });

    test('template:名称/金额/日期(下次执行)', () {
      final lines = ConflictFieldFormatter.summarize(SyncModule.template, _p({
        'Name': '房租月缴',
        'AmountCents': 250000,
        'NextDate': '2026-10-01T00:00:00.000Z',
      }));
      expect(lines, ['名称:房租月缴', '金额:¥2500.00', '日期:2026-10-01']);
    });

    test('缺键跳过:仅渲染存在的字段(不拼 null)', () {
      final lines = ConflictFieldFormatter.summarize(SyncModule.account, _p({
        'Name': '只有名字',
        'OpeningDate': null,
      }));
      expect(lines, ['名称:只有名字']);
    });
  });

  group('summarize:坏 payload 容错', () {
    test('null payload → 「(无法解析)」(F17 时代最小冲突面)', () {
      expect(ConflictFieldFormatter.summarize(SyncModule.account, null),
          ['(无法解析)']);
    });

    test('空 bytes → 「(无法解析)」', () {
      expect(ConflictFieldFormatter.summarize(SyncModule.tag, Uint8List(0)),
          ['(无法解析)']);
    });

    test('非 JSON bytes → 「(无法解析)」', () {
      expect(
          ConflictFieldFormatter.summarize(
              SyncModule.account, Uint8List.fromList([0xff, 0xfe, 0x01])),
          ['(无法解析)']);
    });

    test('JSON 非 Map(数组)→「(无法解析)」', () {
      expect(
          ConflictFieldFormatter.summarize(
              SyncModule.account,
              Uint8List.fromList(
                  utf8.encode(jsonEncode(['a', 'b'])))),
          ['(无法解析)']);
    });

    test('Map 但无任何已知键 → 「(无法解析)」(解析成功无可渲染字段)', () {
      expect(
          ConflictFieldFormatter.summarize(SyncModule.account, _p({'foo': 1})),
          ['(无法解析)']);
    });

    test('未知模块 → 走通用兜底不炸(渲染 ID 键)', () {
      final lines = ConflictFieldFormatter.summarize('future_module', _p({
        'ID': 'x-1',
        'Name': '未知实体',
      }));
      // 未知模块无键知识:ID/Name 两个稳定通用键兜底(不抛异常)。
      expect(lines, ['ID:x-1', '名称:未知实体']);
    });
  });

  group('moduleLabel:中文模块名映射', () {
    test('9 模块全值域', () {
      expect(ConflictFieldFormatter.moduleLabel(SyncModule.account), '账户');
      expect(ConflictFieldFormatter.moduleLabel(SyncModule.transaction), '交易');
      expect(ConflictFieldFormatter.moduleLabel(SyncModule.debt), '债务');
      expect(ConflictFieldFormatter.moduleLabel(SyncModule.budget), '预算');
      expect(ConflictFieldFormatter.moduleLabel(SyncModule.goal), '目标');
      expect(ConflictFieldFormatter.moduleLabel(SyncModule.holding), '持仓');
      expect(
          ConflictFieldFormatter.moduleLabel(SyncModule.holdingLedger), '持仓台账');
      expect(ConflictFieldFormatter.moduleLabel(SyncModule.tag), '标签');
      expect(ConflictFieldFormatter.moduleLabel(SyncModule.template), '模板');
    });

    test('未知模块回退原串(不炸)', () {
      expect(ConflictFieldFormatter.moduleLabel('other'), 'other');
    });
  });

  group('relativeTime:相对时间', () {
    final now = DateTime(2026, 9, 6, 12, 0, 0);

    test('null → 空串(不渲染)', () {
      expect(ConflictFieldFormatter.relativeTime(null, now: now), '');
    });

    test('30 秒前 → 刚刚', () {
      expect(
          ConflictFieldFormatter.relativeTime(
              now.subtract(const Duration(seconds: 30)),
              now: now),
          '刚刚');
    });

    test('5 分钟前 → 5 分钟前', () {
      expect(
          ConflictFieldFormatter.relativeTime(
              now.subtract(const Duration(minutes: 5)),
              now: now),
          '5 分钟前');
    });

    test('3 小时前 → 3 小时前', () {
      expect(
          ConflictFieldFormatter.relativeTime(
              now.subtract(const Duration(hours: 3)),
              now: now),
          '3 小时前');
    });

    test('2 天前 → 2 天前', () {
      expect(
          ConflictFieldFormatter.relativeTime(
              now.subtract(const Duration(days: 2)),
              now: now),
          '2 天前');
    });

    test('10 天前 → 日期串(yyyy-MM-dd)', () {
      expect(
          ConflictFieldFormatter.relativeTime(
              now.subtract(const Duration(days: 10)),
              now: now),
          '2026-08-27');
    });
  });
}
