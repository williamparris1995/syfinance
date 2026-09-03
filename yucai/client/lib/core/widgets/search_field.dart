import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';

// ───────────── F9 FR-3/4/5(承 F7 FR-2 提交制语义):无 domain 依赖通用搜索框 ─────────────

/// 通用提交制搜索框(纯 UI,无任何模块 domain 依赖)。
///
/// **来源**:提取自 F7 的 `TxnSearchField`
/// (transaction/presentation/widgets/filter_bar.dart)的「提交制」形态 ——
/// F9-T3 需要给持仓/债务/债权/账户页加搜索,若各自仿写会产生 4 份雷同控件;
/// 复用 TxnSearchField 又会让各页反向依赖 transaction 模块。故把提交制语义
/// (onSubmitted 回车/搜索键 + suffix 清除钮离散提交,防逐键重载丢焦点)提取为
/// core 纯 UI 组件,行为逐位照搬(TxnSearchField 保留其草稿制 onChanged 形态
/// 服务 mobile 筛选 sheet,不动)。
///
/// - 受控组件:[value] 为当前**已提交**的搜索词('' = 无)。[value] 被外部真正
///   变更(如筛选重置)时同步回输入框;无关重建(value 未变)不回写,避免清空
///   未提交的输入缓冲。
/// - 清除钮随输入**实时**显隐:本组件监听 controller,「有无文本」翻转时
///   setState 重建 decoration(TxnSearchField 依赖父级重建才刷新 suffix,提取
///   时补上 listener,交互自洽不依赖调用方)。
/// - 颜色走 R8 语义令牌([BuildContext.yucai]),禁裸色。
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.value,
    this.onCommit,
    this.hintText = '搜索…',
  });

  /// 当前提交值(空串 = 无搜索)。
  final String value;

  /// 提交回调:onSubmitted(回车/搜索键)+ 清除钮。
  final ValueChanged<String>? onCommit;

  /// 占位文案(各页按匹配字段自定,如「搜索 symbol / 名称…」)。
  final String hintText;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller;

  /// 上次「有无文本」态,供 controller listener 判断是否需要重建(翻转才
  /// setState,逐键输入不触发多余重建)。
  late bool _hasText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value)
      ..addListener(_onControllerChanged);
    _hasText = _controller.text.isNotEmpty;
  }

  void _onControllerChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      // 仅在「空 ↔ 非空」翻转时重建:清除钮(suffixIcon)显隐依赖本组件
      // build,不监听则输入过程中清除钮不出现(见类注释)。
      setState(() => _hasText = hasText);
    }
  }

  @override
  void didUpdateWidget(covariant SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 仅当外部真正变更提交值(如重置)时回写输入框;无关重建(value 未变,
    // 如其它筛选维度变化触发的父级刷新)不回写,保留未提交的输入缓冲。
    if (oldWidget.value != widget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear(); // clear() 不触发 onSubmitted,需手动提交。
    widget.onCommit?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    return TextField(
      controller: _controller,
      // search 动作键(移动端「搜索」/桌面回车)→ onSubmitted 提交。
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon:
            Icon(LucideIcons.search, size: 16, color: context.yucai.muted),
        hintText: widget.hintText,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        suffixIcon: hasText
            ? IconButton(
                tooltip: '清除搜索',
                icon: Icon(LucideIcons.x, size: 15, color: context.yucai.muted),
                onPressed: _clear,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: context.yucai.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: context.yucai.border),
        ),
      ),
      // 提交制:回车/搜索键离散提交(照搬 TxnSearchField,防逐键提交丢焦点)。
      onSubmitted: widget.onCommit,
    );
  }
}
