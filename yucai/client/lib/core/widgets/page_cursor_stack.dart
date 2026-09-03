/// 每页起始 pageToken 栈(F9 自 transaction_bloc `_pageTokens` 提取,ADR-2)。
///
/// **落点理由**:本类是纯 Dart 状态助手(不 import Flutter),消费方是各
/// 模块 presentation 层的 bloc —— 按依赖方向放跨模块共享的 core,与
/// [PagerBar](渲染侧)同目录组成「分页共享对」:PagerBar 画翻页条,
/// PageCursorStack 记翻页游标。ADR-2 倾向 presentation 共享层,core/widgets
/// 即各模块 presentation 共用的位置(非 Widget 逻辑/配置类放 core/widgets
/// 有先例:debt_view_semantics —— 其本身 import Flutter,非纯 Dart)。
///
/// F7 不变式(照搬,行为逐位不变):
/// `stack[i]` = 取第 i 页(0 起)所用 pageToken,**第 0 页恒为空串**(首查
/// 不带 token);next 压入上一页返回的 nextToken(覆写同值幂等),prev
/// 复用栈内既有 token —— 不假设 token 语义(DS offset 串 / 服务器 opaque
/// cursor 均可回退);任一筛选/搜索/排序变化(Load 事件)[clear] 清栈重置。
class PageCursorStack {
  /// 内部栈:第 i 个元素 = 第 i 页(0 起)的起始 token;初始 `['']`
  /// (第 0 页恒为空串,与 F7 `_pageTokens` 初值逐位一致)。
  final List<String> _tokens = [''];

  /// 压入/覆写第 [pageIndex] 页的起始 [token](next 翻页时调用)。
  ///
  /// 语义照搬 F7 的栈维护逻辑:`pageIndex` 在栈内 → 同槽覆写(同值幂等,
  /// 重复 next 不产生脏槽);超出栈深 → 追加(bloc 正常流程 target 恰好
  /// == 栈深,单调前进不会留空洞)。
  void push(int pageIndex, String token) {
    if (pageIndex < _tokens.length) {
      _tokens[pageIndex] = token;
    } else {
      _tokens.add(token);
    }
  }

  /// 读取第 [pageIndex] 页的起始 token;越界(栈深不足/负页码)返回 null,
  /// 由调用方兜底(F7 prev 路径:栈深不足时整体回第 1 页)。
  String? tokenFor(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= _tokens.length) return null;
    return _tokens[pageIndex];
  }

  /// 清栈重置回初始不变式(仅剩第 0 页空串)。
  ///
  /// 任一筛选/搜索/排序变化(Load 事件)时调用 —— 换了查询就作废全部
  /// 历史页 token。与 F7 `_onLoad` 的 `clear() + add('')` 逐位等价。
  void clear() {
    _tokens
      ..clear()
      ..add('');
  }
}
