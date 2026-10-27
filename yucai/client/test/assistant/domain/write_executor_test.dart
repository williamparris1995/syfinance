// F70-T1 TDD RED → GREEN:WriteExecutor port + WriteOutcome 三态(ADR-1)。
// 执行器本体是 T2 票;本测钉死契约形状(port 可实现 + outcome 值语义)。
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/assistant/domain/write_action.dart';
import 'package:yucai_client/assistant/domain/write_executor.dart';

void main() {
  test('port 可实现(fake 编译即契约成立),execute 携幂等键', () async {
    final executor = _FakeExecutor(const WriteExecuted('txn-1'));
    final outcome = await executor.execute(
      const TransactionDelete(transactionId: 'txn-1'),
      'key-uuid-1',
    );
    expect(executor.seenKeys, ['key-uuid-1']);
    expect(outcome, isA<WriteExecuted>());
  });

  test('WriteExecuted 携 entityId', () {
    const outcome = WriteExecuted('txn-42');
    expect(outcome.entityId, 'txn-42');
  });

  test('AlreadyExecuted 携 entityId(幂等键重复触发)', () {
    const outcome = AlreadyExecuted('txn-42');
    expect(outcome.entityId, 'txn-42');
    expect(outcome, isA<WriteOutcome>());
  });

  test('WriteFailed 携 reason(ASCII 单行由调用方保证)', () {
    const outcome = WriteFailed('account not found: acc-x');
    expect(outcome.reason, 'account not found: acc-x');
  });

  test('sealed 层级穷尽:三态 switch 可编译', () {
    String describe(WriteOutcome outcome) => switch (outcome) {
          WriteExecuted() => 'done',
          AlreadyExecuted() => 'dup',
          WriteFailed() => 'fail',
        };
    expect(describe(const AlreadyExecuted('e')), 'dup');
  });
}

class _FakeExecutor implements WriteExecutor {
  _FakeExecutor(this._result);

  final WriteOutcome _result;
  final List<String> seenKeys = [];

  @override
  Future<WriteOutcome> execute(WriteAction action, String idempotencyKey) async {
    seenKeys.add(idempotencyKey);
    return _result;
  }
}
