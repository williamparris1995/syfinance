import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 反馈⑦(表单历史填写票):「最近使用」描述建议下拉的过滤规则 ——
/// 纯内存过滤,表单打开时经 bloc 拉一次全量([suggestions]),击键只过滤,
/// 绝不在每次击键打 DB。
///
/// 交互决定(钉):**空值聚焦弹最近 [kEmptyQueryLimit] 条**(聚焦即可见,
/// 唤起方便);输入非空 → contains 大小写不敏感匹配(前缀匹配是 contains
/// 的子集,不单独分档),上限 [kTypedQueryLimit]。无匹配 → 不弹
/// (RawAutocomplete 空选项自动隐藏)。
const int kEmptyQueryLimit = 3;
const int kTypedQueryLimit = 8;

/// [suggestions] 须已是 distinct + 最近倒序(DAO 口径);[query] 为输入框
/// 当前文本(原样传入,内部 trim + 小写)。
List<String> filterDescriptionSuggestions(
    List<String> suggestions, String query) {
  final q = query.trim().toLowerCase();
  final Iterable<String> matched = q.isEmpty
      ? suggestions.take(kEmptyQueryLimit)
      : suggestions.where((s) => s.toLowerCase().contains(q));
  return matched.take(kTypedQueryLimit).toList(growable: false);
}

/// 「交易对象 / 商户」输入框 + 「最近使用」历史建议下拉(反馈⑦)。
///
/// - 键盘:↑/↓ 移动高亮,回车填入高亮项(RawAutocomplete 内建 Action);
/// - 鼠标:点击选项填入(InkWell);
/// - [controller] 由表单页持有并预填(编辑/复制模式)/读取(提交),
///   RawAutocomplete 选中时直接写入该 controller;
/// - 面板样式走 design-v2 令牌(零裸色);无建议([suggestions] 空)时
///   退化为普通输入框(不弹任何浮层)。
class DescriptionSuggestionsField extends StatefulWidget {
  const DescriptionSuggestionsField({
    super.key,
    required this.controller,
    this.suggestions = const [],
    this.decoration,
  });

  final TextEditingController controller;

  /// distinct 近期描述(倒序)。空 = 无历史(新建库/加载失败降级)。
  final List<String> suggestions;

  /// 覆盖输入框装饰;缺省为表单既有的「交易对象 / 商户」label/hint。
  final InputDecoration? decoration;

  @override
  State<DescriptionSuggestionsField> createState() =>
      _DescriptionSuggestionsFieldState();
}

class _DescriptionSuggestionsFieldState
    extends State<DescriptionSuggestionsField> {
  /// RawAutocomplete 契约:外部提供 textEditingController 时必须同时提供
  /// focusNode(断言成对);字段无跨页焦点需求,内部自持自销。
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  InputDecoration get _decoration => widget.decoration ??
      const InputDecoration(
        labelText: '交易对象 / 商户',
        hintText: '例如：永辉超市、美团外卖',
      );

  @override
  Widget build(BuildContext context) {
    // 无历史 → 纯输入框(不包 RawAutocomplete,行为与反馈⑦之前逐位一致)。
    if (widget.suggestions.isEmpty) {
      return TextFormField(
        controller: widget.controller,
        decoration: _decoration,
      );
    }
    return RawAutocomplete<String>(
      focusNode: _focusNode,
      textEditingController: widget.controller,
      optionsBuilder: (value) =>
          filterDescriptionSuggestions(widget.suggestions, value.text),
      // onSelected 缺省:RawAutocomplete._select 已把选中项写入
      // textEditingController(displayStringForOption 对 String 为恒等)。
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController textEditingController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) =>
          TextFormField(
            key: const ValueKey('txn_form_payee_field'),
            controller: textEditingController,
            focusNode: focusNode,
            onFieldSubmitted: (value) => onFieldSubmitted(),
            decoration: _decoration,
          ),
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<String> onSelected,
        Iterable<String> options,
      ) =>
          _SuggestionsPanel(options: options, onSelected: onSelected),
    );
  }
}

/// 建议浮层面板:surface 底 + border 描边 + sm 圆角;行 = 时钟 icon(muted)
/// + 描述(fg);键盘高亮行 = surfaceAlt 底。宽度自适应内容,上限 360、
/// 高度上限 ~8 行,超出滚动。
class _SuggestionsPanel extends StatelessWidget {
  const _SuggestionsPanel({required this.options, required this.onSelected});

  final Iterable<String> options;
  final AutocompleteOnSelected<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final highlightedIndex = AutocompleteHighlightedOption.of(context);
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        color: context.yucai.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.smBorder,
          side: BorderSide(color: context.yucai.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 336),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (BuildContext context, int index) {
              final option = options.elementAt(index);
              final highlighted = index == highlightedIndex;
              return InkWell(
                onTap: () => onSelected(option),
                child: ColoredBox(
                  color: highlighted ? context.yucai.surfaceAlt : Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    child: Row(
                      children: [
                        Icon(LucideIcons.clock,
                            size: 14, color: context.yucai.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            option,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: context.yucai.fg, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
