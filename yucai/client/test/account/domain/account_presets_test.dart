// AccountPresets(F52 FR-1):建户预设目录 domain 纯常量 —— 恰四条/字段
// 完备/花呗固定账单日还款日/白条类日期空 + hint 非空。
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/account/domain/account_presets.dart';

void main() {
  test('目录恰含四条预设', () {
    expect(accountPresets, hasLength(4));
  });

  test('四条预设按序为 花呗/京东白条/美团月付/微信分付', () {
    expect(accountPresets.map((p) => p.name).toList(),
        ['花呗', '京东白条', '美团月付', '微信分付']);
  });

  test('字段完备:名称与机构均非空', () {
    for (final p in accountPresets) {
      expect(p.name, isNotEmpty, reason: 'name 不应为空');
      expect(p.institution, isNotEmpty, reason: '${p.name} institution 不应为空');
    }
  });

  test('花呗:蚂蚁消费金融,账单日 1/还款日 9,hint 空', () {
    final huabei = accountPresets.firstWhere((p) => p.name == '花呗');
    expect(huabei.institution, '蚂蚁消费金融');
    expect(huabei.billingDay, 1);
    expect(huabei.repaymentDay, 9);
    expect(huabei.hint, '');
  });

  test('白条类(京东白条/美团月付/微信分付):日期 null 且 hint 非空', () {
    final byName = {
      for (final p in accountPresets) p.name: p,
    };
    for (final name in ['京东白条', '美团月付', '微信分付']) {
      final p = byName[name];
      expect(p, isNotNull, reason: '$name 不在目录中');
      expect(p!.billingDay, isNull, reason: '$name billingDay 应为 null');
      expect(p.repaymentDay, isNull, reason: '$name repaymentDay 应为 null');
      expect(p.hint, isNotEmpty, reason: '$name hint 应非空');
    }
  });

  test('白条类机构与 hint 文案钉死', () {
    final byName = {
      for (final p in accountPresets) p.name: p,
    };
    expect(byName['京东白条']!.institution, '京东');
    expect(byName['美团月付']!.institution, '美团');
    expect(byName['微信分付']!.institution, '腾讯');
    const activationHint = '账单日按激活日,建后可改';
    expect(byName['京东白条']!.hint, activationHint);
    expect(byName['美团月付']!.hint, activationHint);
    expect(byName['微信分付']!.hint, activationHint);
  });
}
