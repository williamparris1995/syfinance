import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 御财亮色主题。映射设计令牌到 Material 3 [ThemeData]：
/// - 主色 = 御财金，背景 = 奶油白
/// - 标题（display/headline/title）= serif，正文 = sans
/// - 输入框、按钮、卡片、圆角全部对齐设计规范。
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      primaryContainer: AppColors.accentSoft,
      onPrimaryContainer: AppColors.accentHover,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      error: AppColors.negative,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.fg,
      surfaceContainerHighest: AppColors.surfaceAlt,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: AppTypography.bodyFamily,
      fontFamilyFallback: AppTypography.bodyFallback,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );

    // 标题层级用 serif；正文沿用默认 sans。
    final serif = TextStyle(
      fontFamily: AppTypography.displayFamily,
      fontFamilyFallback: AppTypography.displayFallback,
      color: AppColors.fg,
    );
    final serifText = base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.merge(serif),
      displayMedium: base.textTheme.displayMedium?.merge(serif),
      displaySmall: base.textTheme.displaySmall?.merge(serif),
      headlineLarge: base.textTheme.headlineLarge?.merge(serif),
      headlineMedium: base.textTheme.headlineMedium?.merge(serif),
      headlineSmall: base.textTheme.headlineSmall?.merge(serif),
      titleLarge: base.textTheme.titleLarge?.merge(serif),
    );

    return base.copyWith(
      textTheme: serifText,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
        floatingLabelStyle:
            const TextStyle(color: AppColors.accent, fontSize: 13),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: AppColors.accent, width: 1.4),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: AppColors.negative),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.smBorder),
          textStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.fg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.smBorder,
              side: BorderSide(color: AppColors.border)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.muted,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.fg, size: 20),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        titleTextStyle: const TextStyle(
          fontFamily: AppTypography.displayFamily,
          fontFamilyFallback: AppTypography.displayFallback,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.fg,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.fg,
        contentTextStyle:
            const TextStyle(color: AppColors.surface, fontSize: 14),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smBorder),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.border,
      ),
    );
  }
}
