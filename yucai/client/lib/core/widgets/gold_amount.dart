import 'package:flutter/material.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';

/// 金色货币符号 + 金额数字(对齐 OD `<span class="gold cur">¥</span><span class="num">`)。
///
/// cur 单独着 [context.yucai.accent](可 override),num 默认 [context.yucai.fg]。
/// `cents` 为分(int),内部转元 + 千分位;`showFen` 控制是否带 `.00` 小数
/// (列表/详情大金额带 fen;表单 pv-sum 整元用 showFen:false)。
///
/// 用于 list rcv-amt / detail hero h-amt / form pv-sum 等需强调货币符号金色的金额。
class GoldAmount extends StatelessWidget {
  const GoldAmount({
    super.key,
    required this.cents,
    required this.preferred,
    this.curSize = 14,
    this.numSize = 16,
    this.numColor,
    this.numWeight = FontWeight.w700,
    this.curColor,
    this.numLetterSpacing,
    this.numFontFamily,
    this.numFontFamilyFallback,
    this.showFen = true,
  });

  final int cents;
  final String preferred;
  final double curSize;
  final double numSize;
  final Color? numColor;
  final FontWeight numWeight;
  final Color? curColor;
  final double? numLetterSpacing;
  final String? numFontFamily;
  final List<String>? numFontFamilyFallback;
  final bool showFen;

  String _fmtNum() {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final s = yuan.toString();
    final buf = StringBuffer(sign);
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    if (showFen) {
      final fen = (abs % 100).toString().padLeft(2, '0');
      return '$buf.$fen';
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: currencySymbol(preferred),
          style: TextStyle(
            fontSize: curSize,
            fontWeight: FontWeight.w700,
            color: curColor ?? context.yucai.accent,
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
        TextSpan(
          text: _fmtNum(),
          style: TextStyle(
            fontSize: numSize,
            fontWeight: numWeight,
            color: numColor ?? context.yucai.fg,
            letterSpacing: numLetterSpacing,
            fontFeatures: AppTypography.tabularFigures,
            fontFamily: numFontFamily,
            fontFamilyFallback: numFontFamilyFallback,
          ),
        ),
      ]),
    );
  }
}
