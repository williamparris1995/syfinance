import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 御财主题 v2 —— A+B 亮暗双主题。
/// - [AppTheme.light] = 晨白:净白底 + 翡翠绿主色,无边框卡片 + 柔阴影。
/// - [AppTheme.dark]  = 墨鎏金:墨黑底 + 鎏金主色,描边分层。
/// 两套主题均把 [YucaiTheme] 语义令牌挂到 ThemeData.extensions,组件层经
/// `context.yucai` 读取;标题不再用 serif(v2 全无衬线)。
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(YucaiTheme.light(), Brightness.light);

  static ThemeData dark() => _build(YucaiTheme.dark(), Brightness.dark);

  static ThemeData _build(YucaiTheme t, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.accent,
      onPrimary: t.onAccent,
      primaryContainer: t.accentSoft,
      onPrimaryContainer: t.accentDeep,
      secondary: t.accent,
      onSecondary: t.onAccent,
      error: t.negative,
      onError: Colors.white,
      surface: t.surface,
      onSurface: t.fg,
      surfaceContainerHighest: t.surfaceAlt,
      outline: t.border,
      outlineVariant: t.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.bg,
      fontFamily: AppTypography.bodyFamily,
      fontFamilyFallback: AppTypography.bodyFallback,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      extensions: [t],
      dividerTheme: DividerThemeData(
        color: t.border,
        thickness: 1,
        space: 1,
      ),
    );

    // v2 全无衬线:标题不再单独 serif,仅统一字色。
    final text = base.textTheme.copyWith(
      displayLarge:
          base.textTheme.displayLarge?.copyWith(color: t.fg, fontWeight: w8),
      displayMedium:
          base.textTheme.displayMedium?.copyWith(color: t.fg, fontWeight: w8),
      displaySmall:
          base.textTheme.displaySmall?.copyWith(color: t.fg, fontWeight: w8),
      headlineLarge:
          base.textTheme.headlineLarge?.copyWith(color: t.fg, fontWeight: w7),
      headlineMedium:
          base.textTheme.headlineMedium?.copyWith(color: t.fg, fontWeight: w7),
      headlineSmall:
          base.textTheme.headlineSmall?.copyWith(color: t.fg, fontWeight: w7),
      titleLarge:
          base.textTheme.titleLarge?.copyWith(color: t.fg, fontWeight: w7),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(color: t.fg),
      bodySmall: base.textTheme.bodySmall?.copyWith(color: t.muted),
    );

    final isDark = brightness == Brightness.dark;

    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: t.fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        elevation: isDark ? 0 : 4,
        // 晨白柔阴影;墨鎏金 0 晕 + 描边分层。
        shadowColor: const Color(0x0D0F172A),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? t.surface : t.surfaceAlt,
        hintStyle: TextStyle(color: t.muted, fontSize: 14),
        labelStyle: TextStyle(color: t.muted, fontSize: 13),
        floatingLabelStyle: TextStyle(color: t.accentDeep, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(
              color: isDark ? t.border : Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(
              color: isDark ? t.border : Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: t.accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: t.negative),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.onAccent,
          disabledBackgroundColor: t.accent.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              const RoundedRectangleBorder(borderRadius: AppRadius.smBorder),
          textStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.surface,
          foregroundColor: t.fg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: AppRadius.smBorder,
              side: BorderSide(color: t.border)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.accentDeep,
          textStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.smBorder),
          ),
          side: const WidgetStatePropertyAll(BorderSide.none),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? t.onAccent : t.muted),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? t.accent : t.surfaceAlt),
      ),
      iconTheme: IconThemeData(color: t.fg, size: 20),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        elevation: 0,
        shape:
            const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.displayFamily,
          fontFamilyFallback: AppTypography.displayFallback,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: t.fg,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.fg,
        contentTextStyle: TextStyle(color: t.surface, fontSize: 14),
        shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.smBorder),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: t.surfaceAlt,
      ),
    );
  }

  static const w7 = FontWeight.w700;
  static const w8 = FontWeight.w800;
}
