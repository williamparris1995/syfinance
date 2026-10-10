// AccountLocalDataSource unit tests — mapping round-trips (enum index+1,
// parentId ''<->NULL, creditLimit 0<->NULL) and guest write semantics
// (create defaults, patch update, balance-guarded delete) on a memory db.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' hide Account;

void main() {
  late AppDatabase db;
  late AccountLocalDataSource ds;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    ds = AccountLocalDataSource(db);
  });

  tearDown(() async => db.close());

  CreateAccountParams params({
    String name = '现金',
    AccountCategory category = AccountCategory.savings,
    int initialBalanceCents = 1000,
    String parentId = '',
    int creditLimitCents = 0,
    bool isSystem = false,
  }) =>
      CreateAccountParams(
        name: name,
        accountType: AccountType.liability,
        category: category,
        currencyCode: 'CNY',
        initialBalanceCents: initialBalanceCents,
        ownership: Ownership.joint,
        parentId: parentId,
        creditLimitCents: creditLimitCents,
        interestRate: 2.5,
        isSystem: isSystem,
      );

  test('create defaults + full mapping round-trip', () async {
    final a = await ds.create(params());
    expect(a.id, isNotEmpty);
    expect(a.version, 1);
    expect(a.currentBalanceCents, 1000);
    expect(a.status, AccountStatus.active);
    // Enum mapping survives the index+1 encoding both ways.
    expect(a.accountType, AccountType.liability);
    expect(a.category, AccountCategory.savings);
    expect(a.ownership, Ownership.joint);
    expect(a.interestRate, 2.5);
    expect(a.parentId, isEmpty); // '' stored as NULL, read back as ''

    final reRead = await ds.getById(a.id);
    expect(reRead, a); // Equatable round-trip
  });

  test('every category maps back (index+1 pinned, ADR-3)', () async {
    for (final c in AccountCategory.values) {
      final a = await ds.create(params(category: c));
      expect(a.category, c, reason: c.name);
    }
    expect((await ds.list()), hasLength(AccountCategory.values.length));
  });

  test('parentId and creditLimit special cases round-trip', () async {
    final a = await ds.create(params(parentId: 'p1', creditLimitCents: 900));
    expect(a.parentId, 'p1');
    expect(a.creditLimitCents, 900);

    final b = await ds.create(params(creditLimitCents: 0));
    expect(b.creditLimitCents, 0); // stored NULL, read back 0
  });

  // F49:并入模式载体户建户置位 —— create 透传 isSystem 落库,drift 行
  // → 实体 → 重读往返保 true;缺省路径(真实账户/独立账单模式)不置位。
  test('create passes isSystem through and it survives the drift round-trip',
      () async {
    final carrier = await ds.create(params(name: '平安 · 卡贷', isSystem: true));
    expect(carrier.isSystem, isTrue); // 实体携带
    final row = await db.accountDao.getAccountById(carrier.id); // drift 行落库
    expect(row!.isSystem, isTrue);
    expect((await ds.getById(carrier.id)).isSystem, isTrue); // 重读回 true

    final normal = await ds.create(params());
    expect(normal.isSystem, isFalse);
    expect((await db.accountDao.getAccountById(normal.id))!.isSystem, isFalse);
  });

  test('update is a patch: absent fields untouched, version bumps', () async {
    final a = await ds.create(params(name: '原名'));
    final updated = await ds.update(UpdateAccountParams(
      id: a.id,
      version: a.version,
      name: '新名',
    ));
    expect(updated.name, '新名');
    expect(updated.interestRate, 2.5); // untouched
    expect(updated.currentBalanceCents, 1000); // untouched
    expect(updated.version, a.version + 1);
  });

  // 信用卡「当前欠款」编辑：currentBalanceCents 非 null 覆盖落库，null 不动
  // （回归：此前 update 链路无余额字段，编辑金额被静默丢弃）。
  test('update with currentBalanceCents overrides the stored debt', () async {
    final card = await ds.create(
        params(name: '招行信用卡', category: AccountCategory.creditCard, initialBalanceCents: 500000));
    final updated = await ds.update(UpdateAccountParams(
      id: card.id,
      version: card.version,
      name: card.name,
      currentBalanceCents: 398000,
    ));
    expect(updated.currentBalanceCents, 398000);
    expect(updated.initialBalanceCents, 500000); // 初始余额不动
    expect(updated.version, card.version + 1);

    // nil 路径：不带余额的普通编辑不再改欠款。
    final again = await ds.update(UpdateAccountParams(
      id: card.id,
      version: updated.version,
      name: '招行信用卡(改名)',
    ));
    expect(again.currentBalanceCents, 398000);
  });

  test('update with a stale version is rejected (remote-409 mirror)',
      () async {
    final a = await ds.create(params(name: '原名'));
    expect(
      () => ds.update(UpdateAccountParams(
        id: a.id,
        version: a.version + 5, // stale
        name: '新名',
      )),
      throwsA(isA<ServerFailure>()),
    );
    final unchanged = await ds.getById(a.id);
    expect(unchanged.name, '原名');
  });

  test('delete: zero balance succeeds, non-zero keeps the row', () async {
    final zero = await ds.create(params(initialBalanceCents: 0));
    await ds.delete(zero.id);
    expect(() => ds.getById(zero.id), throwsA(isA<ServerFailure>()));

    final nonZero = await ds.create(params(initialBalanceCents: 42));
    expect(
      () => ds.delete(nonZero.id),
      throwsA(isA<ServerFailure>()),
    );
    expect((await ds.list()).map((a) => a.id), contains(nonZero.id));
  });

  // F49 T10(评审补)—— update 通道扩展:isSystem 三态 + 账单日/还款日
  // 清空旗标,均按既有 patch 语义(缺省 = absent 不动)。消费方 = debt_form
  // 编辑切换同步(FR-1 评审补);bound 远端无对应 proto 字段 → no-op(NFR-1)。
  group('F49 update 扩展通道(isSystem 三态 + 账单日清空)', () {
    test('isSystem:缺省 null 不动,true/false 显式写入,version 推进', () async {
      final a = await ds.create(params(name: '真实账户'));
      // 缺省(不带 isSystem)= absent 不动。
      final untouched = await ds.update(UpdateAccountParams(
          id: a.id, version: a.version, name: '改名'));
      expect(untouched.isSystem, isFalse, reason: '缺省 null = 不动(置位路径只有切换同步)');

      // 并入→独立切换:显式复位为真实账户。
      final on = await ds.update(UpdateAccountParams(
          id: untouched.id, version: untouched.version, isSystem: true));
      expect(on.isSystem, isTrue);
      expect(on.version, untouched.version + 1);

      // 独立→并入切换:显式置位为载体。
      final off = await ds.update(UpdateAccountParams(
          id: on.id, version: on.version, isSystem: false));
      expect(off.isSystem, isFalse);
    });

    test('clearCreditScheduleDays:清 NULL 生效;不带旗标不动(patch 语义)', () async {
      final a = await ds.create(
          params(name: 'e招贷账户', category: AccountCategory.loan));
      final withDays = await ds.update(UpdateAccountParams(
          id: a.id,
          version: a.version,
          creditBillingDay: 5,
          creditRepaymentDay: 23));
      expect(withDays.creditBillingDay, 5);
      expect(withDays.creditRepaymentDay, 23);

      // 不带旗标的普通编辑 → 两列不动(既有 orAbsent 语义)。
      final touched = await ds.update(UpdateAccountParams(
          id: withDays.id, version: withDays.version, name: '改名'));
      expect(touched.creditBillingDay, 5);
      expect(touched.creditRepaymentDay, 23);

      // 独立→并入切换:清空旗标 → 两列写 NULL(转载体,账单语义随挂接卡走)。
      final cleared = await ds.update(UpdateAccountParams(
          id: touched.id, version: touched.version, clearCreditScheduleDays: true));
      expect(cleared.creditBillingDay, isNull);
      expect(cleared.creditRepaymentDay, isNull);
    });
  });

  // F49 T7 评审补 —— [AccountCloser] 守卫分支:同户两债,删其一 → 名下仍有
  // debt_type=1 借入债 → 不关(FR-5 三重门第③门,防误关在用载体)。直插
  // debts 行 + 直删一行,模拟 debt DS delete 出表后再调 closer 的时序。
  test('AccountCloser 守卫:同户两债,删其一 → 不关', () async {
    final carrier = await ds.create(
        params(name: '平安 · 卡贷', isSystem: true, initialBalanceCents: 0));

    Future<void> seedDebt(String id) => db.into(db.debts).insert(
          DebtsCompanion.insert(
            id: id,
            accountId: carrier.id,
            counterparty: '平安银行',
            interestRate: 0,
            amortizationMethod: 0,
            startDate: DateTime.utc(2026, 1, 10),
            dueDate: DateTime.utc(2026, 6, 10),
            totalPrincipalCents: 100000,
            debtType: 1, // DebtType.borrowedIn(closer 只认借入方向)
            subtype: 'card_loan',
            contact: '',
            contractRef: '',
            version: 1,
            createdAt: DateTime.utc(2026, 1, 10),
            updatedAt: DateTime.utc(2026, 1, 10),
          ),
        );
    await seedDebt('d1');
    await seedDebt('d2');

    // 删其一:同户仍剩一笔借入债。
    await (db.delete(db.debts)..where((d) => d.id.equals('d1'))).go();
    await AccountCloserImpl(db).closeIfEmptyCarrier(carrier.id);

    final row = await db.accountDao.getAccountById(carrier.id);
    expect(row!.status, 1, reason: '同户还有一笔借入债 → 不得自动关闭(守卫分支)');
    expect(row.isSystem, isTrue, reason: '标记不受关户判断影响');
  });

  // dev 反馈⑧b 数据源:watchList = DAO watchAllAccounts 的实体映射流,
  // 表单/页面订阅后本地库任何账户变更(分类页新建分类等)实时再发射。
  test('watchList:首发射当前行,insert 后自动再发射(实体映射)', () async {
    await ds.create(params(name: 'A'));
    final emissions = <List<Account>>[];
    final sub = ds.watchList().listen(emissions.add);
    await pumpEventQueue();

    await ds.create(params(name: 'B')); // 模拟分类页新建分类
    await pumpEventQueue();
    await sub.cancel();

    expect(emissions.length, greaterThanOrEqualTo(2));
    expect(emissions.first, hasLength(1));
    expect(emissions.first.first.name, 'A'); // 行 → 域实体映射
    expect(emissions.last, hasLength(2));
    expect(emissions.last.map((a) => a.name), contains('B'));
  });
}
