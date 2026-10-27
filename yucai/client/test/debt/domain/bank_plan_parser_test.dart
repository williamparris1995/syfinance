// 银行还款计划表粘贴解析测试(v15,2026-10-27)。
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/debt/domain/bank_plan_parser.dart';

void main() {
  test('标准四列(日期 本金 利息 优惠)与表头/合计行忽略', () {
    const text = '''
期次  还款日  本金  利息  优惠
1  2026-11-24  1075.18  37.21  30.66
2  2026-12-24  1076.65  35.74  30.66
合计  25,000.00  890.00  735.84
''';
    final rows = parseBankPlan(text);
    expect(rows.length, 2, reason: '表头与合计行(无日期)忽略');
    expect(rows[0].date, DateTime.utc(2026, 11, 24));
    expect(rows[0].principalCents, 107518);
    expect(rows[0].interestCents, 3721);
    expect(rows[0].discountCents, 3066);
    expect(rows[0].totalCents, 111239);
    expect(rows[1].discountCents, 3066);
  });

  test('分隔符容错:制表符/逗号/中文逗号;日期 2026/12/24 与 2026.12.24', () {
    final rows = parseBankPlan(
        '2026/12/24\t1076.65\t35.74\n2026.1.24,1078,33.9,29');
    expect(rows.length, 2);
    // 按日期升序:1 月行在前。
    expect(rows[0].date, DateTime.utc(2026, 1, 24));
    expect(rows[0].principalCents, 107800);
    expect(rows[0].interestCents, 3390);
    expect(rows[0].discountCents, 2900);
    expect(rows[1].date, DateTime.utc(2026, 12, 24));
    expect(rows[1].interestCents, 3574);
    expect(rows[1].discountCents, 0, reason: '缺省无优惠');
  });

  test('同日重复取最后一行(银行分页场景);空/无日期文本抛 FormatException',
      () {
    final rows = parseBankPlan('2026-11-24 1.00 0.10\n2026-11-24 2.00 0.20');
    expect(rows.length, 1);
    expect(rows[0].principalCents, 200);
    expect(() => parseBankPlan('没有任何日期的文本 123'),
        throwsA(isA<FormatException>()));
    expect(() => parseBankPlan(''), throwsA(isA<FormatException>()));
  });
}
