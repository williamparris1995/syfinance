// F70-T1 TDD RED → GREEN:WriteAction 写域契约(ADR-1)。
// sealed 三态 + TransactionPatch 至少一字段守卫 + toString 全 ASCII
// (日志串无 CJK 项目门禁,镜像 AssistantAuditLog._asciiOnly 口径)。
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/assistant/domain/write_action.dart';

void main() {
  group('WriteDirection', () {
    test('wire 取值 in/out(与 transactions_search direction 同口径)', () {
      expect(WriteDirection.inflow.wire, 'in');
      expect(WriteDirection.outflow.wire, 'out');
    });

    test('fromWire 大小写不敏感归一,未知值 → null(工具层自纠裁决)', () {
      expect(WriteDirection.fromWire('in'), WriteDirection.inflow);
      expect(WriteDirection.fromWire('OUT'), WriteDirection.outflow);
      expect(WriteDirection.fromWire('In'), WriteDirection.inflow);
      expect(WriteDirection.fromWire('sideways'), isNull);
      expect(WriteDirection.fromWire(''), isNull);
    });
  });

  group('TransactionAdd', () {
    final add = TransactionAdd(
      direction: WriteDirection.outflow,
      amountCents: 3500,
      description: '午饭',
      accountId: 'acc-1',
      categoryId: 'acc-food',
      date: DateTime(2026, 10, 27),
    );

    test('字段面:direction/amountCents/description/accountId/categoryId/date',
        () {
      expect(add.direction, WriteDirection.outflow);
      expect(add.amountCents, 3500);
      expect(add.description, '午饭');
      expect(add.accountId, 'acc-1');
      expect(add.categoryId, 'acc-food');
      expect(add.date, DateTime(2026, 10, 27));
    });

    test('toString 全 ASCII:CJK 描述被剔除,骨架保留', () {
      final s = add.toString();
      expect(s, matches(RegExp(r'^[\x20-\x7E]*$')),
          reason: 'toString 必须纯可打印 ASCII: $s');
      expect(s, contains('TransactionAdd'));
      expect(s, contains('direction=out'));
      expect(s, contains('amountCents=3500'));
      expect(s, contains('accountId=acc-1'));
      expect(s, contains('categoryId=acc-food'));
      expect(s, contains('date=2026-10-27'));
      expect(s, isNot(contains('午饭')));
    });

    test('amountCents <= 0 → ArgumentError(金额恒正)', () {
      expect(
        () => TransactionAdd(
          direction: WriteDirection.inflow,
          amountCents: 0,
          description: 'x',
          accountId: 'a',
          categoryId: 'c',
          date: DateTime(2026, 1, 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => TransactionAdd(
          direction: WriteDirection.inflow,
          amountCents: -1,
          description: 'x',
          accountId: 'a',
          categoryId: 'c',
          date: DateTime(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    });

    test('值相等(equality by value)', () {
      final again = TransactionAdd(
        direction: WriteDirection.outflow,
        amountCents: 3500,
        description: '午饭',
        accountId: 'acc-1',
        categoryId: 'acc-food',
        date: DateTime(2026, 10, 27),
      );
      expect(again, add);
      expect(again.hashCode, add.hashCode);
    });
  });

  group('TransactionPatch', () {
    test('全 null → ArgumentError(至少一字段)', () {
      expect(() => TransactionPatch(), throwsArgumentError);
    });

    test('单字段构造合法 + 空字段保持 null', () {
      final patch = TransactionPatch(amountCents: 4000);
      expect(patch.amountCents, 4000);
      expect(patch.description, isNull);
      expect(patch.categoryId, isNull);
      expect(patch.accountId, isNull);
      expect(patch.date, isNull);
    });

    test('toString 全 ASCII 且只含已设字段', () {
      final patch = TransactionPatch(
        amountCents: 4000,
        description: '晚饭',
      );
      final s = patch.toString();
      expect(s, matches(RegExp(r'^[\x20-\x7E]*$')));
      expect(s, contains('amountCents=4000'));
      expect(s, contains('description='));
      expect(s, isNot(contains('晚饭')));
      expect(s, isNot(contains('categoryId')));
    });
  });

  group('TransactionUpdate / TransactionDelete', () {
    test('update 携 transactionId + patch;toString ASCII', () {
      final update = TransactionUpdate(
        transactionId: 'txn-9',
        patch: TransactionPatch(amountCents: 4000),
      );
      expect(update.transactionId, 'txn-9');
      final s = update.toString();
      expect(s, matches(RegExp(r'^[\x20-\x7E]*$')));
      expect(s, contains('TransactionUpdate'));
      expect(s, contains('transactionId=txn-9'));
      expect(s, contains('amountCents=4000'));
    });

    test('delete 携 transactionId;toString ASCII', () {
      const del = TransactionDelete(transactionId: 'txn-9');
      expect(del.transactionId, 'txn-9');
      final s = del.toString();
      expect(s, matches(RegExp(r'^[\x20-\x7E]*$')));
      expect(s, 'TransactionDelete(transactionId=txn-9)');
    });

    test('sealed 层级穷尽:三态 switch 可编译', () {
      String describe(WriteAction action) => switch (action) {
            TransactionAdd() => 'add',
            TransactionUpdate() => 'update',
            TransactionDelete() => 'delete',
          };
      expect(
        describe(const TransactionDelete(transactionId: 't')),
        'delete',
      );
    });
  });
}
