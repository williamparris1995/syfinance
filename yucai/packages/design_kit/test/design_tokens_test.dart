// DesignTokens 增补字段契约(F58 ADR-2):accentGradient/actionShadow
//   向后兼容 —— 缺省空列表,既有构造点零改动;
//   copyWith —— 不传保留、显式传空可清;
//   lerp     —— 逐项插值,长度不齐取短;
//   ==/hashCode 感知新字段。
// F59 ADR-1 增补:dimmedOpacity(淡显/禁用共用降权透明度)——
//   向后兼容缺省 0.45;copyWith 不传保留;lerp 线性;== 感知差异。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:design_kit/design_kit.dart';

void main() {
  test('缺省构造:新字段默认空,既有构造点(含 light 兜底)零改动', () {
    const tokens = DesignTokens(
      surface: Color(0xFFFFFFFF),
      border: Color(0xFFEEF2F7),
      fg: Color(0xFF0F172A),
      muted: Color(0xFF64748B),
      accent: Color(0xFF059669),
      positive: Color(0xFF059669),
      negative: Color(0xFFE11D48),
    );
    expect(tokens.accentGradient, isEmpty);
    expect(tokens.actionShadow, isEmpty);
    expect(tokens.dimmedOpacity, 0.45, reason: 'F59:淡显/禁用降权透明度缺省 0.45');
    expect(DesignTokens.light.accentGradient, isEmpty);
    expect(DesignTokens.light.actionShadow, isEmpty);
    expect(DesignTokens.light.dimmedOpacity, 0.45);
  });

  test('copyWith:不传保留既有字段与新字段,显式传空可清空', () {
    const grad = [Color(0xFFB8860B), Color(0xFFFFD700)];
    final base = DesignTokens.light;
    final withGradient = base.copyWith(accentGradient: grad);
    expect(withGradient.accentGradient, grad);
    expect(withGradient.accent, base.accent, reason: '既有字段不受影响');
    expect(withGradient.copyWith().accentGradient, grad, reason: '不传=保留');
    expect(withGradient.copyWith(accentGradient: []).accentGradient, isEmpty,
        reason: '显式空列表可清空');
    expect(base.copyWith(dimmedOpacity: 0.3).dimmedOpacity, 0.3,
        reason: 'F59:dimmedOpacity 可注入覆盖');
    expect(base.copyWith().dimmedOpacity, base.dimmedOpacity,
        reason: 'F59:不传 = 保留');
  });

  test('lerp:颜色/阴影逐项插值,长度不齐取短', () {
    final a = DesignTokens.light.copyWith(
      dimmedOpacity: 0.2,
      accentGradient: const [Color(0xFF000000), Color(0xFF000000)],
      actionShadow: const [
        BoxShadow(color: Color(0xFF112233), offset: Offset(0, 2), blurRadius: 4),
        BoxShadow(color: Color(0xFF112233), offset: Offset(0, 8)),
      ],
    );
    final b = DesignTokens.light.copyWith(
      dimmedOpacity: 0.6,
      accentGradient: const [Color(0xFFFFFFFF)],
      actionShadow: const [
        BoxShadow(color: Color(0xFF332211), offset: Offset(0, 6), blurRadius: 8),
      ],
    );
    final mid = a.lerp(b, 0.5);
    // 渐变:2 对 1 → 取短 1 项,值 = Color.lerp 首项
    expect(mid.accentGradient.length, 1);
    expect(mid.accentGradient[0],
        Color.lerp(const Color(0xFF000000), const Color(0xFFFFFFFF), 0.5));
    // 阴影:2 对 1 → 取短 1 项,值 = BoxShadow.lerp 首项
    expect(mid.actionShadow.length, 1);
    expect(
      mid.actionShadow[0],
      BoxShadow.lerp(a.actionShadow[0], b.actionShadow[0], 0.5),
    );
    // F59:透明度线性插值 0.2 → 0.6 的中点 = 0.4
    expect(mid.dimmedOpacity, closeTo(0.4, 1e-9));
  });

  test('lerp:两侧皆空保持空;other 非 DesignTokens 返回 this', () {
    final a = DesignTokens.light;
    final mid = a.lerp(a, 0.5);
    expect(mid.accentGradient, isEmpty);
    expect(mid.actionShadow, isEmpty);
    expect(a.lerp(null, 0.3), same(a));
  });

  test('==/hashCode 感知新字段差异', () {
    const grad = [Color(0xFF001122)];
    final a = DesignTokens.light.copyWith(accentGradient: grad);
    expect(a == DesignTokens.light, isFalse);
    expect(a.hashCode == DesignTokens.light.hashCode, isFalse);
    expect(a == DesignTokens.light.copyWith(accentGradient: grad), isTrue);

    final b = DesignTokens.light.copyWith(
        actionShadow: const [BoxShadow(color: Color(0x33000000))]);
    expect(b == DesignTokens.light, isFalse);

    final c = DesignTokens.light.copyWith(dimmedOpacity: 0.4);
    expect(c == DesignTokens.light, isFalse, reason: 'F59:dimmedOpacity 感知差异');
    expect(c.hashCode == DesignTokens.light.hashCode, isFalse);
  });
}
