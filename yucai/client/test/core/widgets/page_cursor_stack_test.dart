// TDD RED → GREEN:F9-T1 PageCursorStack(token 栈助手)单测。
//
// F9 FR-1 / ADR-2:transaction_bloc 内 `_pageTokens` 栈逻辑提取为共享
// PageCursorStack,不变式注释照搬 F7 —— 行为逐位不变(NFR-1),本组单测
// 守住 F7 定下的栈不变式(next→prev→next 序列)。
//
// F7 不变式(照搬):
//   stack[i] = 取第 i 页(0 起)所用 pageToken;
//   第 0 页恒为空串(首查不带 token);
//   next 压入上一页返回的 nextToken(覆写同值幂等);prev 复用栈内 token;
//   任一筛选/搜索/排序变化(Load 事件)clear 清栈重置。
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/widgets/page_cursor_stack.dart';

void main() {
  group('PageCursorStack 初始不变式', () {
    test('第 0 页起始 token 恒为空串(首查不带 token)', () {
      final stack = PageCursorStack();
      expect(stack.tokenFor(0), '', reason: '第 0 页 = 首查,无 pageToken');
    });

    test('tokenFor 越界返回 null(栈深不足/非法页码)', () {
      final stack = PageCursorStack();
      expect(stack.tokenFor(-1), isNull, reason: '负页码非法');
      expect(stack.tokenFor(1), isNull, reason: '未 push 过第 2 页,栈深不足');
    });
  });

  group('PageCursorStack next→prev→next 序列不变式 (F7 FR-4)', () {
    test('往返翻页后 stack[i] 恒为第 i 页起始 token(prev 往返不污染栈)', () {
      final stack = PageCursorStack();

      // 第 1 页(pageIndex 0):起始 token 空串。
      expect(stack.tokenFor(0), '');

      // next → 第 2 页:压入第 1 页 Loaded 的 nextToken。
      stack.push(1, 'cursor1');
      expect(stack.tokenFor(1), 'cursor1');

      // prev → 回第 1 页:复用栈内既有 token(空串),不清栈不新增。
      expect(stack.tokenFor(0), '');

      // next → 再次前进第 2 页:tokenFor(1) 仍是同一 token
      // (不变式:stack[1] = 第 2 页起始 token,prev 往返不破坏)。
      expect(stack.tokenFor(1), 'cursor1');

      // 更深一页:第 3 页用第 2 页 Loaded 的 nextToken,栈深随之 +1。
      stack.push(2, 'cursor2');
      expect(stack.tokenFor(2), 'cursor2');
      // 历史页 token 不被深页 push 覆写。
      expect(stack.tokenFor(0), '');
      expect(stack.tokenFor(1), 'cursor1');
    });

    test('push 覆写同值幂等(next 重入不膨胀栈),异值同槽覆写', () {
      final stack = PageCursorStack();
      stack.push(1, 'a');
      stack.push(1, 'a'); // 同值覆写:幂等(重复 next 不产生脏槽)。
      expect(stack.tokenFor(1), 'a');
      stack.push(1, 'b'); // 异值覆写:同槽替换(新 token 顶掉旧 token)。
      expect(stack.tokenFor(1), 'b');
      // 覆写不推进栈深:第 3 页仍未压栈。
      expect(stack.tokenFor(2), isNull);
    });
  });

  group('PageCursorStack.clear', () {
    test('clear 重置回「第 0 页空串」初始不变式(筛选变化清栈重置)', () {
      final stack = PageCursorStack();
      stack.push(1, 'cursor1');
      stack.push(2, 'cursor2');

      stack.clear(); // 任一筛选/搜索/排序变化(Load 事件)清栈重置。

      expect(stack.tokenFor(0), '', reason: 'clear 后第 0 页仍恒为空串');
      expect(stack.tokenFor(1), isNull, reason: 'clear 抹掉历史页 token');
      expect(stack.tokenFor(2), isNull);
    });

    test('clear 后可重新走 next 序列(重置不残留)', () {
      final stack = PageCursorStack();
      stack.push(1, 'cursor1');
      stack.clear();
      stack.push(1, 'cursorNew');
      expect(stack.tokenFor(1), 'cursorNew', reason: '重置后新 token 正常压栈');
    });
  });
}
