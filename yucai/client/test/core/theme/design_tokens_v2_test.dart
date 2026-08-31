import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/theme/app_theme.dart';

void main() {
  group('YucaiTheme v2 tokens (A+B dual theme)', () {
    final light = YucaiTheme.light();
    final dark = YucaiTheme.dark();

    test('light = 晨白:净白底 + 翡翠绿主色', () {
      expect(light.bg, const Color(0xFFF8FAFC));
      expect(light.surface, Colors.white);
      expect(light.accent, const Color(0xFF059669));
      expect(light.accentDeep, const Color(0xFF047857));
      expect(light.onAccent, Colors.white);
      expect(light.fg, const Color(0xFF0F172A));
      expect(light.muted, const Color(0xFF64748B));
      expect(light.positive, const Color(0xFF059669));
      expect(light.negative, const Color(0xFFE11D48));
      // 亮色侧栏 = 白底 + 翡翠激活(替代 v1 深色侧栏)。
      expect(light.sidebarBg, Colors.white);
      expect(light.sidebarActiveBg, const Color(0xFFECFDF5));
      expect(light.sidebarActiveFg, const Color(0xFF047857));
    });

    test('dark = 墨鎏金:墨黑底 + 鎏金主色', () {
      expect(dark.bg, const Color(0xFF0B0E13));
      expect(dark.surface, const Color(0xFF141922));
      expect(dark.border, const Color(0xFF232B38));
      expect(dark.accent, const Color(0xFFE8C07A));
      expect(dark.accentDeep, const Color(0xFFC9964A));
      expect(dark.onAccent, const Color(0xFF1A1408));
      expect(dark.fg, const Color(0xFFF2F4F8));
      expect(dark.muted, const Color(0xFF8B93A3));
      expect(dark.positive, const Color(0xFF34D399));
      expect(dark.negative, const Color(0xFFF87171));
      expect(dark.info, const Color(0xFF22D3EE));
      // 暗色侧栏 = 墨黑一体 + 金色激活。
      expect(dark.sidebarBg, const Color(0xFF0E1219));
      expect(dark.sidebarActiveFg, const Color(0xFFE8C07A));
    });

    test('light/dark differ on identity-critical tokens', () {
      expect(light.accent, isNot(dark.accent));
      expect(light.bg, isNot(dark.bg));
      expect(light.surface, isNot(dark.surface));
    });

    test('lerp interpolates accent between themes', () {
      final mid = light.lerp(dark, 0.5);
      expect(
        mid.accent,
        Color.lerp(const Color(0xFF059669), const Color(0xFFE8C07A), 0.5),
      );
    });

    test('copyWith overrides only the given field', () {
      final copy = light.copyWith(accent: const Color(0xFF123456));
      expect(copy.accent, const Color(0xFF123456));
      expect(copy.bg, light.bg);
      expect(copy, isNot(light));
    });

    test('equality is value-based', () {
      expect(YucaiTheme.light(), YucaiTheme.light());
      expect(YucaiTheme.dark(), isNot(YucaiTheme.light()));
    });
  });

  group('AppTheme v2 (ThemeData wiring)', () {
    test('light() is light-brightened and carries YucaiTheme extension', () {
      final theme = AppTheme.light();
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF8FAFC));
      expect(theme.colorScheme.primary, const Color(0xFF059669));
      final yucai = theme.extension<YucaiTheme>();
      expect(yucai, YucaiTheme.light());
    });

    test('dark() is dark-brightened and carries YucaiTheme extension', () {
      final theme = AppTheme.dark();
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0B0E13));
      expect(theme.colorScheme.primary, const Color(0xFFE8C07A));
      expect(theme.colorScheme.onPrimary, const Color(0xFF1A1408));
      expect(theme.extension<YucaiTheme>(), YucaiTheme.dark());
    });

    test('v2 is all-sans: display family no longer serif Georgia', () {
      // v1 用 Georgia serif 标题;v2 全无衬线(Windows 中文 serif 发虚)。
      expect(AppTypography.displayFamily, isNot('Georgia'));
      expect(AppTypography.displayFamily, AppTypography.bodyFamily);
    });

    test('legacy AppColors re-pointed to v2 light tokens (transition shim)',
        () {
      expect(AppColors.bg, const Color(0xFFF8FAFC));
      expect(AppColors.accent, const Color(0xFF059669));
      expect(AppColors.accentSoft, const Color(0xFFECFDF5));
      // v1 值不再出现。
      expect(AppColors.bg, isNot(const Color(0xFFF7F6F2)));
      expect(AppColors.accent, isNot(const Color(0xFFB08D57)));
    });

    test('v2 radius scale bumped one notch (sm 12 / lg 16 / xl 24)', () {
      expect(AppRadius.sm, 12.0);
      expect(AppRadius.lg, 16.0);
      expect(AppRadius.xl, 24.0);
    });
  });

  group('context.yucai follows the ambient theme (F4 dark-awareness)', () {
    testWidgets('reads dark tokens under AppTheme.dark()', (tester) async {
      YucaiTheme? captured;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) {
            captured = context.yucai;
            return const SizedBox.shrink();
          },
        ),
      ));
      expect(captured, isNotNull);
      expect(captured!.bg, const Color(0xFF0B0E13));
      expect(captured!.accent, const Color(0xFFE8C07A));
    });

    testWidgets('reads light tokens under AppTheme.light()', (tester) async {
      YucaiTheme? captured;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            captured = context.yucai;
            return const SizedBox.shrink();
          },
        ),
      ));
      expect(captured!.bg, const Color(0xFFF8FAFC));
      expect(captured!.accent, const Color(0xFF059669));
    });

    testWidgets('falls back to light tokens under a bare MaterialApp '
        '(test harnesses mounting pages without AppTheme)', (tester) async {
      YucaiTheme? captured;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context.yucai;
            return const SizedBox.shrink();
          },
        ),
      ));
      expect(captured, YucaiTheme.light());
    });
  });
}
