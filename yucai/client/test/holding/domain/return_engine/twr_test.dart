import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/holding/domain/return_engine/twr.dart';

void main() {
  test('手算序列(G oracle):3 段 HPR 1.1 → cum 0.331;年化同值(365d)', () {
    final subs = [
      const SubPeriodReturn(100, 110),
      const SubPeriodReturn(110, 121),
      const SubPeriodReturn(121, 133.1),
    ];
    final cum = cumulativeTwr(subs, 133.1, 133.1);
    expect(cum, isNotNull);
    expect((cum! - 0.331).abs(), lessThan(1e-9));
    final ann = annualizeTwr(cum, 365);
    expect(ann, isNotNull);
    expect((ann! - 0.331).abs(), lessThan(1e-6));
  });

  test('两年年化:(1.331)^(1/2)−1(G oracle)', () {
    final cum = cumulativeTwr([
      const SubPeriodReturn(100, 110),
      const SubPeriodReturn(110, 121),
      const SubPeriodReturn(121, 133.1),
    ], 133.1, 133.1)!;
    final ann = annualizeTwr(cum, 730)!;
    expect((ann - (math.pow(1.331, 0.5) - 1.0)).abs(), lessThan(1e-9));
  });

  test('零端点 sentinel:Begin=0 / End=0 / final=0(G oracle)', () {
    expect(cumulativeTwr([const SubPeriodReturn(0, 100)], 100, 100), isNull);
    expect(cumulativeTwr([const SubPeriodReturn(100, 0)], 100, 100), isNull);
    expect(cumulativeTwr([const SubPeriodReturn(100, 110)], 0, 110), isNull);
  });

  test('子区间空 → null;单日(days<1)返累计', () {
    expect(cumulativeTwr(const [], 100, 100), isNull);
    final ann = annualizeTwr(0.10, 0);
    expect(ann, isNotNull);
    expect((ann! - 0.10).abs(), lessThan(1e-12));
  });

  test('cumulative<-1 年化 sentinel → null(F10)', () {
    expect(annualizeTwr(-1.5, 365), isNull);
  });

  test('清仓重建分段链乘(G e2e oracle):段1 HPR1.1 终止尾1 + 段2 尾1.1,40 天年化', () {
    // 段1:subs=[{1000000→1100000}],终止 → tail=1(base/base)。
    final seg1 = cumulativeTwr([const SubPeriodReturn(1000000, 1100000)], 1100000, 1100000)!;
    // 段2:重建后空 subs → 尾 1100000/1000000 − 1(装配层单尾段语义)。
    const seg2 = 1100000 / 1000000 - 1.0;
    final chain = (1 + seg1) * (1 + seg2) - 1;
    expect((chain - 0.21).abs(), lessThan(1e-9));
    final ann = annualizeTwr(chain, 40)!;
    final want = math.pow(1.21, 365.0 / 40.0) - 1.0;
    expect((ann - want).abs(), lessThan(1e-9));
  });
}
