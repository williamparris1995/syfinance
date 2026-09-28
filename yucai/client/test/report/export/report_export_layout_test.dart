/// F45 T1 布局树单测(ADR-2):手算 oracle 逐项断言(数字/顺序/severity)。
///
/// 布局树是导出侧唯一允许「遍历 VO」的地方(FR-5);两渲染器零数字计算,
/// 故本文件把每章节的块结构钉死 —— PDF/Markdown 渲染器只做同构映射。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/export/report_export_layout.dart';

import 'export_fixture.dart';

void main() {
  group('章节顺序(与页面 _chapters 同序)', () {
    test('fullDocument_builds七章节_标题同序', () {
      final layout = ReportExportLayout.build(fullDocument());
      expect(
        layout.sections.map((s) => s.title).toList(),
        ['总览', '资产负债', '收支', '现金流', '预算执行', '投资绩效', '诊断与建议'],
      );
    });

    test('minimalDocument_builds四章节_null章节缺席', () {
      final layout = ReportExportLayout.build(minimalDocument());
      expect(
        layout.sections.map((s) => s.title).toList(),
        ['总览', '资产负债', '收支', '现金流'],
      );
    });
  });

  group('总览章节(hero 数字+摘要+附注)', () {
    test('build_heroKv数字与页面hero同源', () {
      final ov = ReportExportLayout.build(fullDocument())
          .sections
          .first; // 「总览」
      final hero = ov.blocks.whereType<ReportKvBlock>().first;
      expect(hero.title, '净资产变动 · 2026 年 8 月');
      expect(hero.rows, [
        const ReportExportKvRow(
            label: '期初净资产', value: '¥1,000,000.00', tone: ReportExportTone.neutral),
        const ReportExportKvRow(
            label: '期末净资产', value: '¥1,250,000.00', tone: ReportExportTone.neutral),
        const ReportExportKvRow(
            label: '净资产变动',
            value: '+¥250,000.00 (+25.0%)',
            tone: ReportExportTone.positive),
        const ReportExportKvRow(
            label: '现金及等价物净变动',
            value: '+¥30,000.00',
            tone: ReportExportTone.positive),
        const ReportExportKvRow(
            label: '本位币', value: 'CNY', tone: ReportExportTone.neutral),
      ]);
    });

    test('build_摘要Kv四卡同源_诊断摘要计数行', () {
      final blocks = ReportExportLayout.build(fullDocument()).sections.first.blocks;
      final kvBlocks = blocks.whereType<ReportKvBlock>().toList();
      expect(kvBlocks, hasLength(2));
      expect(kvBlocks[1].title, '摘要');
      expect(kvBlocks[1].rows, [
        const ReportExportKvRow(
            label: '本月收入', value: '¥200,000.00', tone: ReportExportTone.positive),
        const ReportExportKvRow(
            label: '本月支出', value: '¥120,000.00', tone: ReportExportTone.neutral),
        const ReportExportKvRow(
            label: '本月结余', value: '+¥80,000.00', tone: ReportExportTone.positive),
        const ReportExportKvRow(
            label: '储蓄率', value: '40.0%', tone: ReportExportTone.positive),
      ]);
      final digest =
          blocks.whereType<ReportTextBlock>().map((b) => b.text).toList();
      expect(digest, contains('诊断摘要:1 风险 1 提示 1 关注,详见「诊断与建议」章节'));
    });

    test('build_附注note块按doc顺序', () {
      final blocks =
          ReportExportLayout.build(minimalDocument()).sections.first.blocks;
      final notes = blocks.whereType<ReportNoteBlock>().toList();
      expect(notes, hasLength(2));
      expect(notes[0].title, '口径说明');
      expect(notes[0].lines, ['口径行一']);
      expect(notes[1].title, '未包含项');
      expect(notes[1].lines,
          ['未包含:预算执行(本期无预算)', '未包含:投资绩效(本期无持仓)']);
    });
  });

  group('收支章节(bars + 摘要)', () {
    test('build_支出收入构成bars_科目名直出_合计展示', () {
      final blocks = ReportExportLayout.build(fullDocument())
          .sections
          .firstWhere((s) => s.title == '收支')
          .blocks;
      final bars = blocks.whereType<ReportBarsBlock>().toList();
      expect(bars, hasLength(2));
      expect(bars[0].title, '支出分类');
      expect(bars[0].totalCents, 12000000);
      expect(bars[0].bars, [
        const ReportExportBar(
            label: '餐饮',
            amountCents: 7000000,
            sharePct: 58.3,
            maxCents: 7000000),
        const ReportExportBar(
            label: '交通',
            amountCents: 5000000,
            sharePct: 41.7,
            maxCents: 7000000),
      ]);
      expect(bars[1].title, '收入构成');
      expect(bars[1].totalCents, 20000000);
      expect(bars[1].bars, [
        const ReportExportBar(
            label: '工资',
            amountCents: 15000000,
            sharePct: 75.0,
            maxCents: 15000000),
        const ReportExportBar(
            label: '奖金',
            amountCents: 5000000,
            sharePct: 25.0,
            maxCents: 15000000),
      ]);
    });

    test('build_摘要kv_日均与环比', () {
      final blocks = ReportExportLayout.build(fullDocument())
          .sections
          .firstWhere((s) => s.title == '收支')
          .blocks;
      final kv = blocks.whereType<ReportKvBlock>().single;
      expect(kv.title, '摘要');
      expect(kv.rows, [
        const ReportExportKvRow(
            label: '日均结余', value: '¥2,500.00', tone: ReportExportTone.neutral),
        const ReportExportKvRow(
            label: '较 2026 年 7 月',
            value: '+33.3%',
            tone: ReportExportTone.positive),
      ]);
    });

    test('build_首期无对比数据行', () {
      final blocks = ReportExportLayout.build(minimalDocument())
          .sections
          .firstWhere((s) => s.title == '收支')
          .blocks;
      final kv = blocks.whereType<ReportKvBlock>().single;
      expect(kv.rows.last.label, '对比期');
      expect(kv.rows.last.value, '首期无对比数据');
    });
  });

  group('现金流章节(三类活动表 + 勾稽脚注)', () {
    test('build_四行表含合计行_勾稽脚注', () {
      final blocks = ReportExportLayout.build(fullDocument())
          .sections
          .firstWhere((s) => s.title == '现金流')
          .blocks;
      final table = blocks.whereType<ReportTableBlock>().single;
      expect(table.title, '三类活动现金流');
      expect(table.header, ['活动', '流入', '流出', '净额']);
      expect(table.rows, [
        const ReportExportTableRow(cells: [
          '经营活动', '¥200,000.00', '¥120,000.00', '+¥80,000.00'
        ]),
        const ReportExportTableRow(
            cells: ['投资活动', '¥10,000.00', '¥60,000.00', '-¥50,000.00']),
        const ReportExportTableRow(
            cells: ['融资活动', '¥0.00', '¥0.00', '¥0.00']),
        const ReportExportTableRow(
            cells: ['合计', '¥210,000.00', '¥180,000.00', '+¥30,000.00'],
            emphasized: true),
      ]);
      final foot = blocks.whereType<ReportTextBlock>().single;
      expect(foot.text,
          '勾稽:三类活动净额合计 +¥30,000.00,与期末−期初现金余额一致。');
    });
  });

  group('预算执行章节(bars 三档 severity)', () {
    test('build_预算bars_满条基准为额度_severity三档', () {
      final blocks = ReportExportLayout.build(fullDocument())
          .sections
          .firstWhere((s) => s.title == '预算执行')
          .blocks;
      final bars = blocks.whereType<ReportBarsBlock>().single;
      expect(bars.title, '预算执行 · 2026 年 8 月');
      expect(bars.showMax, isTrue);
      expect(bars.totalCents, isNull);
      expect(bars.bars, [
        const ReportExportBar(
            label: '餐饮',
            amountCents: 7000000,
            sharePct: 70.0,
            maxCents: 10000000),
        const ReportExportBar(
            label: '交通',
            amountCents: 4800000,
            sharePct: 96.0,
            maxCents: 5000000,
            severity: MdaSeverity.warn),
        const ReportExportBar(
            label: '娱乐',
            amountCents: 2000000,
            sharePct: 133.3,
            maxCents: 1500000,
            severity: MdaSeverity.risk),
      ]);
    });
  });

  group('投资绩效章节(五数值 kv)', () {
    test('build_五卡kv_估算收益与TWR带符号', () {
      final blocks = ReportExportLayout.build(fullDocument())
          .sections
          .firstWhere((s) => s.title == '投资绩效')
          .blocks;
      final kv = blocks.whereType<ReportKvBlock>().single;
      expect(kv.title, '投资绩效');
      expect(kv.rows, [
        const ReportExportKvRow(
            label: '期初市值', value: '¥400,000.00', tone: ReportExportTone.neutral),
        const ReportExportKvRow(
            label: '期末市值', value: '¥460,000.00', tone: ReportExportTone.neutral),
        const ReportExportKvRow(
            label: '当期净买入', value: '¥30,000.00', tone: ReportExportTone.neutral),
        const ReportExportKvRow(
            label: '估算收益',
            value: '+¥30,000.00',
            tone: ReportExportTone.positive),
        const ReportExportKvRow(
            label: '区间 TWR', value: '+7.2%', tone: ReportExportTone.positive),
      ]);
    });
  });

  group('诊断与建议章节(severity 分组)', () {
    test('build_分组头加发现行_结论与建议两段', () {
      final blocks = ReportExportLayout.build(fullDocument())
          .sections
          .firstWhere((s) => s.title == '诊断与建议')
          .blocks;
      final texts = blocks.whereType<ReportTextBlock>().toList();
      expect(
        texts.map((b) => b.text),
        containsAllInOrder([
          '风险 · 1',
          '本期储蓄率 40.0%,连续低于 10% 警戒线。\n建议:建议优先建立 3-6 个月应急备用金。',
          '提示 · 1',
          '预算「娱乐」使用率 133.3%,已超支。\n建议:建议上调预算额度或压缩非必要支出。',
          '关注 · 1',
          '现金可支撑约 6.0 个月基本支出。\n建议:现金储备处于健康区间。',
        ]),
      );
      expect(texts[1].severity, MdaSeverity.risk);
      expect(texts[3].severity, MdaSeverity.warn);
      expect(texts[5].severity, MdaSeverity.info);
      expect(texts[0].severity, isNull); // 分组头无 severity
    });

    test('build_零发现健康态两行', () {
      final blocks = ReportExportLayout.build(healthyMdaDocument())
          .sections
          .firstWhere((s) => s.title == '诊断与建议')
          .blocks;
      final texts = blocks.whereType<ReportTextBlock>().map((b) => b.text).toList();
      expect(texts, [
        '本期诊断未发现需关注项',
        '储蓄率 40.0%、资产负债率 50.0%、现金可支撑约 6.0 个月,均在健康区间',
      ]);
    });
  });

  group('文件名安全化', () {
    test('safeFileStem_月报补零去空格_年报原样', () {
      expect(safeFileStem(ReportPeriod.monthly(2026, 8)), '2026年08月');
      expect(safeFileStem(ReportPeriod.monthly(2026, 11)), '2026年11月');
      expect(safeFileStem(ReportPeriod.yearly(2025)), '2025年度');
    });
  });

  group('资产负债章节(构成 bars + 变动表)', () {
    test('build_构成bars与账类中文标签_满条基准为最大行', () {
      final blocks = ReportExportLayout.build(fullDocument())
          .sections
          .firstWhere((s) => s.title == '资产负债')
          .blocks;
      final bars = blocks.whereType<ReportBarsBlock>().toList();
      expect(bars, hasLength(2));
      expect(bars[0].title, '资产构成 · 期末');
      expect(bars[0].totalCents, 100000000);
      expect(bars[0].showMax, isFalse);
      expect(bars[0].bars, [
        const ReportExportBar(
            label: '储蓄',
            amountCents: 60000000,
            sharePct: 60.0,
            maxCents: 60000000),
        const ReportExportBar(
            label: '投资',
            amountCents: 40000000,
            sharePct: 40.0,
            maxCents: 60000000),
      ]);
      expect(bars[1].title, '负债构成 · 期末');
      expect(bars[1].totalCents, 50000000);
      expect(bars[1].bars, [
        const ReportExportBar(
            label: '贷款',
            amountCents: 30000000,
            sharePct: 60.0,
            maxCents: 30000000),
        const ReportExportBar(
            label: '信用卡',
            amountCents: 20000000,
            sharePct: 40.0,
            maxCents: 30000000),
      ]);
      // 资产负债率行(VO 派生 debtRatioPct 直出)。
      final texts = blocks.whereType<ReportTextBlock>().map((b) => b.text);
      expect(texts, contains('资产负债率 50.0% · 期末负债 / 期末资产'));
    });

    test('build_变动表_净资产汇总行加分类行', () {
      final blocks = ReportExportLayout.build(fullDocument())
          .sections
          .firstWhere((s) => s.title == '资产负债')
          .blocks;
      final table = blocks.whereType<ReportTableBlock>().single;
      expect(table.title, '期初 → 期末 变动');
      expect(table.header, ['项目', '期初', '期末', '变动']);
      expect(table.rows, [
        const ReportExportTableRow(
            cells: ['净资产', '¥1,000,000.00', '¥1,250,000.00', '+¥250,000.00'],
            emphasized: true),
        const ReportExportTableRow(
            cells: ['储蓄', '¥550,000.00', '¥600,000.00', '+¥50,000.00']),
        const ReportExportTableRow(
            cells: ['投资', '¥350,000.00', '¥400,000.00', '+¥50,000.00']),
      ]);
    });
  });
}
