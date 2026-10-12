// F58 T2(ADR-1)— ShellDetailTitle port 单元测。
//
// FR-2 的标题注入通道:detail 页 set(实体名)/clear(离开清理),shell 顶栏
// 经 ValueListenableBuilder 消费。此处钉死 notifier 语义:set → 值变更通知;
// clear → null;双监听不串(ValueNotifier 基建行为,回归护栏)。
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/shell_detail_title.dart';

void main() {
  test('初值 null(加载前/清理后顶栏占位「…」口径)', () {
    final title = ShellDetailTitle();
    addTearDown(title.dispose);

    expect(title.value, isNull);
  });

  test('set → 值变更并通知监听者', () {
    final title = ShellDetailTitle();
    addTearDown(title.dispose);

    String? seen;
    title.addListener(() => seen = title.value);
    title.set('平安现金分期');

    expect(title.value, '平安现金分期');
    expect(seen, '平安现金分期', reason: '监听者应收到 set 后的最新值');
  });

  test('clear → 回 null 且通知', () {
    final title = ShellDetailTitle()..set('现金账户');
    addTearDown(title.dispose);

    var notified = 0;
    String? latest;
    title.addListener(() {
      notified++;
      latest = title.value;
    });
    title.clear();

    expect(title.value, isNull);
    expect(notified, 1);
    expect(latest, isNull);
  });

  test('双监听不串:同次变更各收一次,移除一方后仅另一方收', () {
    final title = ShellDetailTitle();
    addTearDown(title.dispose);

    var a = 0;
    var b = 0;
    void listenerA() => a++;
    void listenerB() => b++;
    title.addListener(listenerA);
    title.addListener(listenerB);

    title.set('A');
    expect(a, 1);
    expect(b, 1);

    title.removeListener(listenerA);
    title.set('B');
    expect(a, 1, reason: '已移除的监听不应再收通知');
    expect(b, 2);
  });
}
