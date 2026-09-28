/// F45 T1 Markdown 渲染器单测(ADR-2):布局树 → 字符串(标题层级/表格/
/// bars 列表/附注引用块/severity 符号前缀 —— LLD 契约)。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/report/export/markdown_report_renderer.dart';
import 'package:yucai_client/report/export/report_export_layout.dart';

import 'export_fixture.dart';

void main() {
  late String md;

  setUpAll(() {
    md = renderMarkdown(ReportExportLayout.build(fullDocument()));
  });

  test('render_文档标题与章节标题层级有序', () {
    expect(md.startsWith('# 御财财务报告 2026 年 8 月\n'), isTrue);
    final order = [
      '## 总览',
      '## 资产负债',
      '## 收支',
      '## 现金流',
      '## 预算执行',
      '## 投资绩效',
      '## 诊断与建议',
    ];
    var pos = 0;
    for (final h in order) {
      final at = md.indexOf(h);
      expect(at, greaterThanOrEqualTo(pos), reason: '$h 应按章节序出现');
      pos = at;
    }
  });

  test('render_kv组_标题三级与键值行', () {
    expect(md, contains('### 净资产变动 · 2026 年 8 月'));
    expect(md, contains('- 期初净资产:¥1,000,000.00'));
    expect(md, contains('- 期末净资产:¥1,250,000.00'));
    expect(md, contains('- 净资产变动:+¥250,000.00 (+25.0%)'));
    expect(md, contains('- 本月结余:+¥80,000.00'));
    expect(md, contains('- 储蓄率:40.0%'));
  });

  test('render_表格_表头分隔与合计行', () {
    expect(
        md,
        contains('| 活动 | 流入 | 流出 | 净额 |\n'
            '| --- | --- | --- | --- |\n'
            '| 经营活动 | ¥200,000.00 | ¥120,000.00 | +¥80,000.00 |\n'
            '| 投资活动 | ¥10,000.00 | ¥60,000.00 | -¥50,000.00 |\n'
            '| 融资活动 | ¥0.00 | ¥0.00 | ¥0.00 |\n'
            '| **合计** | **¥210,000.00** | **¥180,000.00** | **+¥30,000.00** |'));
    expect(md, contains('### 期初 → 期末 变动'));
    expect(md, contains('| **净资产** | **¥1,000,000.00** | **¥1,250,000.00** | **+¥250,000.00** |'));
  });

  test('render_bars_金额与占比_预算额度与severity符号', () {
    expect(md, contains('- 餐饮:¥70,000.00(58.3%)'));
    expect(md, contains('- 工资:¥150,000.00(75.0%)'));
    expect(md, contains('- 贷款:¥300,000.00(60.0%)'));
    // 预算行:showMax → 「actual / limit」;超支🔴 / 临界⚠ / 正常无符号。
    expect(md, contains('- 餐饮:¥70,000.00 / ¥100,000.00(70.0%)'));
    expect(md, contains('- ⚠ 交通:¥48,000.00 / ¥50,000.00(96.0%)'));
    expect(md, contains('- 🔴 娱乐:¥20,000.00 / ¥15,000.00(133.3%)'));
  });

  test('render_附注引用块与诊断符号前缀', () {
    expect(md, contains('> **口径说明**\n> · 口径行一\n> · 口径行二'));
    expect(md, contains('风险 · 1'));
    expect(md, contains('- 🔴 本期储蓄率 40.0%,连续低于 10% 警戒线。\n'
        '  建议:建议优先建立 3-6 个月应急备用金。'));
    expect(md, contains('- ⚠ 预算「娱乐」使用率 133.3%,已超支。\n'
        '  建议:建议上调预算额度或压缩非必要支出。'));
    expect(md, contains('- ℹ 现金可支撑约 6.0 个月基本支出。\n'
        '  建议:现金储备处于健康区间。'));
  });

  test('render_健康态与勾稽脚注文本', () {
    final healthy = renderMarkdown(ReportExportLayout.build(healthyMdaDocument()));
    expect(healthy, contains('本期诊断未发现需关注项'));
    expect(healthy, contains('储蓄率 40.0%、资产负债率 50.0%、现金可支撑约 6.0 个月,均在健康区间'));
    expect(md, contains('勾稽:三类活动净额合计 +¥30,000.00,与期末−期初现金余额一致。'));
  });
}
