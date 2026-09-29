import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 反馈⑦(表单历史填写票):「最近使用」描述建议下拉的过滤规则 ——
/// 纯内存过滤,表单打开时经 bloc 拉一次全量([suggestions],数据面由 DAO
/// 缺省 200 封顶防极端库),击键只过滤,绝不在每次击键打 DB。
///
/// 改版口径(输入全显+聚焦前十+两列,注释钉):
/// - **空值聚焦弹最近 [kEmptyQueryLimit] = 10 条**(聚焦即可见,唤起方便);
/// - 输入非空 → contains 大小写不敏感(前缀匹配是 contains 的子集,不单独
///   分档)**匹配全显、无截断** —— 上限交给数据面(DAO 200)与面板封顶
///   高度(内部滚动),过滤函数不再截 8;
/// - 无匹配 → 不弹(RawAutocomplete 空选项自动隐藏)。
const int kEmptyQueryLimit = 10;

/// [suggestions] 须已是 distinct + 最近倒序(DAO 口径);[query] 为输入框
/// 当前文本(原样传入,内部 trim + 小写)。聚焦前十取自本函数(空查询
/// take(kEmptyQueryLimit)),两列展示与封顶高度在字段层 `_SuggestionsPanel`。
List<String> filterDescriptionSuggestions(
    List<String> suggestions, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return suggestions.take(kEmptyQueryLimit).toList(growable: false);
  }
  return suggestions
      .where((s) => s.toLowerCase().contains(q))
      .toList(growable: false);
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

/// 建议浮层面板(改版:两列 + 封顶高度内部滚动):
/// - surface 底 + border 描边 + sm 圆角;
/// - **两列等宽**(GridView.count,childAspectRatio 6.0 ≈ 行高 1/6 列宽,
///   desktop 面板 520 宽 → 列 ~250、行高 ~42);单条文本超长省略号;
/// - **封顶高度 [kSuggestionsPanelMaxHeight] = 320**(design-v2 视觉:留出
///   ~7-8 行双列 ≈ 14-16 条可视,不遮表单下半屏;钉死)超出内部滚动;
/// - 键盘高亮 = 整格 surfaceAlt 背景(RawAutocomplete 线性 index,↓/↑ 逐格
///   移动,两列下沿行推进);
/// - 宽度自适应内容上限 520(窄视口自动收窄,不溢出屏幕)。
const double kSuggestionsPanelMaxWidth = 520;
const double kSuggestionsPanelMaxHeight = 320;

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
          constraints: const BoxConstraints(
              maxWidth: kSuggestionsPanelMaxWidth,
              maxHeight: kSuggestionsPanelMaxHeight),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              // 行高 = 列宽 / 6(desktop 520 面板 → 列 ~250 / 行 ~42);
              // 间距 6 与表单 grid 一档。
              childAspectRatio: 6.0,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            padding: const EdgeInsets.all(8),
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (BuildContext context, int index) {
              final option = options.elementAt(index);
              final highlighted = index == highlightedIndex;
              return InkWell(
                onTap: () => onSelected(option),
                child: ColoredBox(
                  color: highlighted
                      ? context.yucai.surfaceAlt
                      : Colors.transparent,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
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
