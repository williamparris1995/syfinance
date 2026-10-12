// F58 T2(ADR-3)— FormLeaveGate port 单元测。
//
// FR-7 离开问询语义:mayLeave 逐个问询已注册 veto,任一 false 即整体 false
// (短路:后续不再问询);无注册/全 true → true;unregister 后不再问询。
// 面包屑 page 级 onTap 的统一问询入口(F59 存量表单页接线也走这里)。
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/form_leave_gate.dart';

void main() {
  test('无注册:mayLeave 直接 true(干净态零摩擦)', () async {
    final gate = FormLeaveGate();

    expect(await gate.mayLeave(), isTrue);
  });

  test('单 veto 返回 false → mayLeave false(且被问询)', () async {
    final gate = FormLeaveGate();
    var asked = 0;
    gate.register(() async {
      asked++;
      return false;
    });

    expect(await gate.mayLeave(), isFalse);
    expect(asked, 1);
  });

  test('多 veto 短路:首个 false 后不再问询后续', () async {
    final gate = FormLeaveGate();
    var secondAsked = 0;
    gate.register(() async => false);
    gate.register(() async {
      secondAsked++;
      return true;
    });

    expect(await gate.mayLeave(), isFalse);
    expect(secondAsked, 0, reason: '短路:任一 false 即整体 false,后续 veto 不问');
  });

  test('多 veto 全 true → true(逐个都被问询)', () async {
    final gate = FormLeaveGate();
    var asked = 0;
    gate.register(() async {
      asked++;
      return true;
    });
    gate.register(() async {
      asked++;
      return true;
    });

    expect(await gate.mayLeave(), isTrue);
    expect(asked, 2);
  });

  test('unregister 后不再问询该 veto', () async {
    final gate = FormLeaveGate();
    var asked = 0;
    Future<bool> veto() async {
      asked++;
      return false;
    }
    gate.register(veto);
    gate.unregister(veto);

    expect(await gate.mayLeave(), isTrue);
    expect(asked, 0, reason: '已注销的 veto 不应再被问询');
  });
}
