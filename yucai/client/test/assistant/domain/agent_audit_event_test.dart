// F71-T1 TDD:AgentAuditEvent 值类型(design LLD 字段契约 + toString
// 全 ASCII 门 —— 镜像 write_action_test 口径;createdAt 缺省盖戳/可注入)。
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/assistant/domain/agent_audit_event.dart';

void main() {
  test('字段保真 + createdAt 缺省盖戳', () {
    final before = DateTime.now();
    final e = AgentAuditEvent(
      tool: 'transaction_add',
      summary: 'TransactionAdd(direction=out, amountCents=3500)',
      ok: false,
      reason: 'versionConflict',
      idempotencyKey: 'key-1',
    );
    final after = DateTime.now();

    expect(e.tool, 'transaction_add');
    expect(e.ok, isFalse);
    expect(e.reason, 'versionConflict');
    expect(e.entityId, isNull);
    expect(e.idempotencyKey, 'key-1');
    // 缺省 createdAt = 构造时刻(毫秒不漂出窗口)。
    expect(e.createdAt.millisecondsSinceEpoch,
        greaterThanOrEqualTo(before.millisecondsSinceEpoch - 1));
    expect(e.createdAt.millisecondsSinceEpoch,
        lessThanOrEqualTo(after.millisecondsSinceEpoch + 1));
  });

  test('toString 全 ASCII:自由文本 CJK 剔除,毫秒戳可读', () {
    final e = AgentAuditEvent(
      tool: 'transaction_add',
      summary: 'TransactionAdd(description=午饭, amountCents=3500)',
      ok: true,
      entityId: 'txn-中文id',
      idempotencyKey: 'key-2',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1770000000123,
          isUtc: true),
    );

    final text = e.toString();
    expect(text, contains('tool=transaction_add'));
    expect(text, contains('ok=true'));
    expect(text, contains('createdAtMillis=1770000000123'));
    // ASCII 门(项目门禁:日志串无 CJK;镜像 audit_log 断言口径)。
    expect(text, matches(RegExp(r'^[\x20-\x7E]*$')),
        reason: 'toString must be printable ASCII: $text');
    expect(text.contains('午饭'), isFalse, reason: 'CJK 摘要剔除');
    expect(text.contains('中文'), isFalse, reason: 'CJK 实体 id 剔除');
  });
}
