// F17-T2(spec FR-3,design ADR-2):PullApplier —— 增量下行应用。
// - upsert 应用(8 模块抽 3 深 + 其余轻):payload(envelope 行)→ drift
//   insertOnConflictUpdate(单行 upsert,与 importer 的 purge+全量不同);
// - DELETE → 本地硬删、**不写墓碑**(pulled delete 源头即 server log,再
//   上行是回声;多设备回声乒乓 + 镜像数据源论证,详见 PullApplier 类 doc);
// - **F18-T2(FR-4/ADR-4)版本感知 pending 规则**(替换一刀切跳过):本地
//   pending 行 local.version >= pulled.version → 跳过保 pending;<
//   → 应用(server 已裁决/他设备胜出,本地内容已在冲突记录或已过时);
//   非 pending 照常 upsert;pulled.version 从 payload JSON probe(非
//   logVersion —— 两值语义不同,F18-T1 裁决警示);
// - **F18-T2 per-change 隔离**(毒丸吸收):坏条目(未知模块/坏 payload)
//   debugPrint + 跳过,不回滚整批、不再钉死游标;
// - holding_ledger 台账行应用(ADR-4 台账查证裁决=实施)。
// payload 生产直接复用 envelope_codec(与真实 push 路径同一份行序列化,
// 单一事实源)—— 测试即钉「上行编码的行,下行能原样应用」的往返契约。
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/binding/data/pull_applier.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/envelope_codec.dart';
import 'package:yucai_client/core/localdb/sync_state.dart';

void main() {
  late db.AppDatabase database;
  late PullApplier applier;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    applier = PullApplier(database);
  });
  tearDown(() => database.close());

  /// 下行变更构造:drift 行 → envelope 行(与 push 编码同源)→ payload bytes。
  PulledChange upsert(String module, String entityId, Map<String, dynamic> fields,
          {String deviceId = 'device-A', int logVersion = 1}) =>
      PulledChange(
        module: module,
        entityId: entityId,
        isDelete: false,
        payload: utf8.encode(jsonEncode(fields)),
        logVersion: logVersion,
        deviceId: deviceId,
      );

  PulledChange deletion(String module, String entityId,
          {String deviceId = 'device-A', int logVersion = 1}) =>
      PulledChange(
        module: module,
        entityId: entityId,
        isDelete: true,
        payload: utf8.encode(''),
        logVersion: logVersion,
        deviceId: deviceId,
      );

  /// 账户行 fixture:drift 数据类(envelope 生产 + 落库共用同一行对象,
  /// 落库经 toCompanion)。
  db.Account accountData(String id,
      {String name = '他设备账户', String syncState = SyncState.synced}) {
    return db.Account(
      id: id,
      name: name,
      accountType: 1,
      category: 2,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: 1,
      icon: '',
      color: '',
      chartCode: '',
      isSystem: false,
      sortOrder: 0,
      institution: '',
      cardNumberTail: '',
      notes: '',
      goldProductType: '',
      status: 1,
      version: 1,
      createdAt: DateTime.utc(2026, 9, 5),
      updatedAt: DateTime.utc(2026, 9, 5),
      syncState: syncState,
    );
  }

  Future<void> seedAccount(db.Account a) =>
      database.into(database.accounts).insert(a.toCompanion(true));

  group('upsert 应用(envelope 行 → drift insertOnConflictUpdate)', () {
    test('深×account:新行落库,syncState 默认 synced(server 行即已同步态)',
        () async {
      final row = accountData('acc-A');
      final result = await applier
          .apply([upsert(SyncModule.account, 'acc-A', accountRowToEnvelope(row))]);

      expect(result.applied, 1);
      expect(result.skipped, 0);
      final got = await database.accountDao.getAccountById('acc-A');
      expect(got, isNotNull);
      expect(got!.name, '他设备账户');
      expect(got.syncState, SyncState.synced);
    });

    test('深×account:同 id 重复下行覆盖(update 语义,单行 upsert)', () async {
      await seedAccount(accountData('acc-A'));
      final v2 = accountData('acc-A', name: '他设备改名');
      await applier.apply(
          [upsert(SyncModule.account, 'acc-A', accountRowToEnvelope(v2))]);

      expect((await database.accountDao.getAccountById('acc-A'))!.name, '他设备改名');
    });

    test('深×transaction:头行 + 分录子表随行落库;重下行分录整体替换',
        () async {
      await seedAccount(accountData('acc-A'));
      db.Transaction headOf({String desc = '他设备转账', int version = 1}) =>
          db.Transaction(
            id: 'txn-1',
            transactionDate: DateTime.utc(2026, 9, 5),
            transactionTime: null,
            description: desc,
            version: version,
            createdAt: DateTime.utc(2026, 9, 5),
            updatedAt: DateTime.utc(2026, 9, 6),
            syncState: SyncState.synced,
          );
      db.TransactionEntry entryOf(String id, int debitCents) =>
          db.TransactionEntry(
              id: id,
              transactionId: 'txn-1',
              accountId: 'acc-A',
              chartOfAccountCode: '1001',
              debitCents: debitCents,
              creditCents: 0,
              note: '');

      final fields = transactionRowToEnvelope(
          headOf(), [entryOf('e-1', 500)]);

      await applier.apply([upsert(SyncModule.transaction, 'txn-1', fields)]);

      final headRow = await database.transactionDao.getTransactionById('txn-1');
      expect(headRow!.description, '他设备转账');
      final entries = (await database.transactionDao.getAllEntries())
          .where((e) => e.transactionId == 'txn-1')
          .toList();
      expect(entries, hasLength(1));
      expect(entries.single.id, 'e-1');

      // 重下行(分录集合变化):整体替换而非追加。
      final fieldsV2 = transactionRowToEnvelope(
          headOf(desc: '他设备转账v2', version: 2), [entryOf('e-2', 600)]);
      await applier.apply([upsert(SyncModule.transaction, 'txn-1', fieldsV2)]);
      final entriesV2 = (await database.transactionDao.getAllEntries())
          .where((e) => e.transactionId == 'txn-1')
          .toList();
      expect(entriesV2, hasLength(1));
      expect(entriesV2.single.id, 'e-2');
      expect(
          (await database.transactionDao.getTransactionById('txn-1'))!
              .description,
          '他设备转账v2');
    });

    test('深×holding_ledger:台账行落库(ADR-4 裁决=实施;无 syncState,恒应用)',
        () async {
      final fields = holdingTxnRowToEnvelope(db.HoldingTransaction(
        id: 'tr-1',
        accountId: 'acc-inv',
        securityId: 'sec-1',
        tradeType: 3,
        quantity: 100,
        priceCents: 12,
        amountCents: 1200,
        feeCents: 0,
        realizedPnlCents: 0,
        tradeDate: DateTime.utc(2026, 9, 1),
        transactionId: null,
        notes: '他设备分红',
        createdAt: DateTime.utc(2026, 9, 1),
      ));
      await applier
          .apply([upsert(SyncModule.holdingLedger, 'tr-1', fields)]);

      final got = await database.holdingDao.getHoldingTransactionById('tr-1');
      expect(got, isNotNull);
      expect(got!.notes, '他设备分红');
      expect(got.tradeType, 3);

      // 重下行幂等覆盖。
      final fieldsV2 = {...fields, 'Notes': '他设备分红v2'};
      await applier
          .apply([upsert(SyncModule.holdingLedger, 'tr-1', fieldsV2)]);
      expect(
          (await database.holdingDao.getHoldingTransactionById('tr-1'))!.notes,
          '他设备分红v2');
    });

    test('轻×tag/debt/budget/goal/template/holding:头行落库', () async {
      await seedAccount(accountData('acc-A'));
      final changes = <PulledChange>[
        upsert(SyncModule.tag, 'tag-1', {
          'ID': 'tag-1', 'Name': '他设备标签', 'Color': '#000000',
          'Version': 1, 'DeletedAt': null,
          'CreatedAt': '2026-09-05T00:00:00.000Z',
          'UpdatedAt': '2026-09-05T00:00:00.000Z',
        }),
        upsert(SyncModule.holding, 'h-1', {
          'ID': 'h-1', 'AccountID': 'acc-A', 'SecurityID': 'sec-1',
          'Quantity': 10.0, 'AvgCostCents': 100, 'Version': 1,
          'CreatedAt': '2026-09-05T00:00:00.000Z',
          'UpdatedAt': '2026-09-05T00:00:00.000Z',
        }),
        upsert(SyncModule.debt, 'd-1', {
          'ID': 'd-1', 'AccountID': 'acc-A', 'Counterparty': '他设备债主',
          'InterestRate': 0.05, 'AmortizationMethod': 1,
          'StartDate': '2026-09-05T00:00:00.000Z',
          'DueDate': '2027-09-05T00:00:00.000Z',
          'TotalPrincipalCents': 1000, 'DebtType': 1, 'Subtype': '',
          'Contact': '', 'ContractRef': '', 'CollectionAccountID': null,
          'Schedule': [
            {'ID': 's-1', 'DebtID': 'd-1',
             'PaymentDate': '2026-10-05T00:00:00.000Z',
             'PrincipalCents': 500, 'InterestCents': 10, 'TotalCents': 510,
             'PaidCents': 0, 'Paid': false, 'TransactionID': null},
          ],
          'Version': 1, 'CreatedAt': '2026-09-05T00:00:00.000Z',
          'UpdatedAt': '2026-09-05T00:00:00.000Z',
        }),
        upsert(SyncModule.budget, 'b-1', {
          'ID': 'b-1', 'Name': '他设备预算', 'Month': '2026-09',
          'TotalAmountCents': 5000, 'CurrencyCode': 'CNY', 'IsActive': true,
          'Items': [], 'Version': 1, 'DeletedAt': null,
          'CreatedAt': '2026-09-05T00:00:00.000Z',
          'UpdatedAt': '2026-09-05T00:00:00.000Z',
        }),
        upsert(SyncModule.goal, 'g-1', {
          'ID': 'g-1', 'Name': '他设备目标', 'GoalType': 1,
          'TargetAmountCents': 10000, 'CurrentAmountCents': 0,
          'CurrencyCode': 'CNY', 'Deadline': null,
          'LinkedAccountIDs': ['acc-A'], 'LinkedDebtIDs': [],
          'Notes': '', 'IsCompleted': false, 'CompletedAt': null,
          'Version': 1, 'CreatedAt': '2026-09-05T00:00:00.000Z',
          'UpdatedAt': '2026-09-05T00:00:00.000Z',
        }),
        upsert(SyncModule.template, 't-1', {
          'ID': 't-1', 'Name': '他设备模板', 'Description': '',
          'AmountCents': 100, 'Direction': 0, 'SourceAccountID': 'acc-A',
          'DestinationAccountID': null, 'Cycle': 0, 'CycleDays': 0,
          'BillingDay': 0, 'NextDate': '2026-09-05T00:00:00.000Z',
          'StartDate': '2026-09-05T00:00:00.000Z', 'EndDate': null,
          'AutoRecord': false, 'Paused': false, 'LastTransactionID': null,
          'Category': '', 'Version': 1,
          'CreatedAt': '2026-09-05T00:00:00.000Z',
          'UpdatedAt': '2026-09-05T00:00:00.000Z',
        }),
      ];

      final result = await applier.apply(changes);
      expect(result.applied, 6);
      expect(result.skipped, 0);

      expect((await database.tagDao.getTagById('tag-1'))!.name, '他设备标签');
      expect((await database.holdingDao.getHoldingById('h-1'))!.quantity, 10.0);
      final debt = await database.debtDao.getDebtById('d-1');
      expect(debt!.counterparty, '他设备债主');
      expect((await database.debtDao.getScheduleByDebt('d-1')), hasLength(1));
      expect((await database.budgetDao.getBudgetById('b-1'))!.name, '他设备预算');
      expect((await database.goalDao.getGoalById('g-1'))!.name, '他设备目标');
      final (goalAccounts, goalDebts) = await database.goalDao.linksFor('g-1');
      expect(goalAccounts, ['acc-A']);
      expect(goalDebts, isEmpty);
      expect(
          (await database.templateDao.getTemplateById('t-1'))!.name, '他设备模板');
    });
  });

  group('F18-T2 版本感知 pending 规则(FR-4/ADR-4:替换一刀切跳过)', () {
    /// 版本感知矩阵四象限(单测内一次钉死):
    /// pending 同版本 skip / pending 低版本应用(server 裁决)/
    /// 非 pending 照常 upsert / DELETE 不问版本(既有测试已钉)。
    test('pending 同版本(1>=1)→ 跳过保 pending,本地内容不被覆盖', () async {
      await seedAccount(accountData('acc-A', syncState: SyncState.pending));

      final result = await applier.apply([
        upsert(SyncModule.account, 'acc-A',
            accountRowToEnvelope(accountData('acc-A', name: 'server覆盖'))),
      ]);

      // 同版本 = 本地未上行编辑仍是更新事实(单设备不变式:server 不可能有
      // 本地 pending 行的同版本更新)→ 跳过(F17 一刀切语义的唯一保留面)。
      expect(result.applied, 0);
      expect(result.skipped, 1);
      expect((await database.accountDao.getAccountById('acc-A'))!.name,
          '他设备账户'); // 构造默认名,未被覆盖
      expect((await database.accountDao.getAccountById('acc-A'))!.syncState,
          SyncState.pending);
    });

    test('pending 低版本(1<9)→ 应用(server 已裁决/他设备胜出)', () async {
      await database.tagDao.insertTag(db.TagsCompanion.insert(
        id: 'tag-1',
        name: '本地离线标签',
        color: '#111111',
        version: 1,
        createdAt: DateTime.utc(2026, 9, 5),
        updatedAt: DateTime.utc(2026, 9, 5),
        syncState: const Value(SyncState.pending),
      ));

      final result = await applier.apply([
        upsert(SyncModule.tag, 'tag-1', {
          'ID': 'tag-1', 'Name': 'server 裁决版本', 'Color': '#222222',
          'Version': 9, 'DeletedAt': null,
          'CreatedAt': '2026-09-05T00:00:00.000Z',
          'UpdatedAt': '2026-09-05T00:00:00.000Z',
        }),
      ]);

      // server 更高版本 = 冲突已裁决(或他设备更新胜出):本地 pending 内容
      // 已在 server 冲突记录(client_payload),应用下行收敛(F17 一刀切
      // 在此场景会把 B 设备永久钉死在旧态 —— F18 核心修复点)。
      expect(result.applied, 1);
      expect(result.skipped, 0);
      final tag = await database.tagDao.getTagById('tag-1');
      expect(tag!.name, 'server 裁决版本');
      expect(tag.version, 9);
      expect(tag.syncState, SyncState.synced);
    });

    test('非 pending(synced)照常 upsert —— 不设版本防线(F17 语义保持)',
        () async {
      // 本地 synced v5;pulled v1(旧版本回放/重放)→ 照常应用:server 日志
      // 即权威终态,本地 synced 行无「未上行编辑」事实需保护。
      await seedAccount(accountData('acc-A', syncState: SyncState.synced));
      await database.accountDao.updateAccount(const db.AccountsCompanion(
        id: Value('acc-A'),
        version: Value(5),
      ));
      final pulled = accountData('acc-A', name: '重放版本');
      // envelope 用 drift 行的 version 字段(pulled v1)。
      final row = accountRowToEnvelope(pulled);

      final result =
          await applier.apply([upsert(SyncModule.account, 'acc-A', row)]);

      expect(result.applied, 1);
      expect((await database.accountDao.getAccountById('acc-A'))!.name,
          '重放版本');
    });

    test('版本 probe 用 payload 内实体 Version(非 logVersion)',
        () async {
      // F18-T1 裁决警示:PulledChange.logVersion 是 tenant pull 游标
      //(本例 99),与实体乐观锁版本(本例 1)两值。本地 pending v2 ≥
      // payload 内 v1 → 跳过;若误用 logVersion(2<99)会错误应用。
      await database.tagDao.insertTag(db.TagsCompanion.insert(
        id: 'tag-p',
        name: '本地未上行编辑',
        color: '#111111',
        version: 2,
        createdAt: DateTime.utc(2026, 9, 5),
        updatedAt: DateTime.utc(2026, 9, 5),
        syncState: const Value(SyncState.pending),
      ));

      final result = await applier.apply([
        upsert(SyncModule.tag, 'tag-p', {
          'ID': 'tag-p', 'Name': '低实体版本高log版本', 'Color': '#222222',
          'Version': 1, 'DeletedAt': null,
          'CreatedAt': '2026-09-05T00:00:00.000Z',
          'UpdatedAt': '2026-09-05T00:00:00.000Z',
        }, logVersion: 99),
      ]);

      expect(result.applied, 0);
      expect(result.skipped, 1);
      expect(
          (await database.tagDao.getTagById('tag-p'))!.name, '本地未上行编辑');
    });

    test('DELETE 不问版本:pending 行照删(server 删除是存在性终局,'
        'F18-T2 保持 —— 版本感知仅限 CREATE/UPDATE)', () async {
      await database.tagDao.insertTag(db.TagsCompanion.insert(
        id: 'tag-p',
        name: 'pending 标签',
        color: '#111111',
        version: 9, // 即便本地版本更高:删除不设防线
        createdAt: DateTime.utc(2026, 9, 5),
        updatedAt: DateTime.utc(2026, 9, 5),
        syncState: const Value(SyncState.pending),
      ));

      final result = await applier.apply([deletion(SyncModule.tag, 'tag-p')]);

      expect(result.applied, 1);
      expect(await database.tagDao.getTagById('tag-p'), isNull);
    });
  });

  group('F18-T2 per-change 隔离(FR-4/ADR-4:毒丸吸收,游标不再钉死)', () {
    test('坏条目(坏 payload)跳过 + 后续条目照常应用(不回滚整批)', () async {
      final good1 = upsert(SyncModule.tag, 'tag-good', {
        'ID': 'tag-good', 'Name': '好行1', 'Color': '#000000',
        'Version': 1, 'DeletedAt': null,
        'CreatedAt': '2026-09-05T00:00:00.000Z',
        'UpdatedAt': '2026-09-05T00:00:00.000Z',
      });
      // 坏行:ID 缺失 → 行映射 cast 失败(TypeError)→ 条目级跳过。
      final bad = upsert(SyncModule.account, 'acc-bad', {'Name': '没有 ID'});
      final good2 = upsert(SyncModule.tag, 'tag-good2', {
        'ID': 'tag-good2', 'Name': '好行2', 'Color': '#000000',
        'Version': 1, 'DeletedAt': null,
        'CreatedAt': '2026-09-05T00:00:00.000Z',
        'UpdatedAt': '2026-09-05T00:00:00.000Z',
      });

      // F17 整批事务在此 throwsA;F18-T2 起吞掉毒丸,好行全部落地 ——
      // 下行是幂等重放,单条失败不再钉死全局(apply 正常返回 = 协调器
      // 游标照常前进)。
      final result = await applier.apply([good1, bad, good2]);

      expect(result.applied, 2);
      expect(await database.tagDao.getTagById('tag-good'), isNotNull);
      expect(await database.tagDao.getTagById('tag-good2'), isNotNull);
      expect(await database.accountDao.getAccountById('acc-bad'), isNull);
    });

    test('未知模块:条目级跳过(不再整批 fail-closed 抛出),不阻批',
        () async {
      final good = upsert(SyncModule.tag, 'tag-x', {
        'ID': 'tag-x', 'Name': '好行', 'Color': '#000000',
        'Version': 1, 'DeletedAt': null,
        'CreatedAt': '2026-09-05T00:00:00.000Z',
        'UpdatedAt': '2026-09-05T00:00:00.000Z',
      });

      final result =
          await applier.apply([upsert('future_module', 'x', {'ID': 'x'}), good]);

      // 未知模块条目毒丸吸收(与 server 未知 entityType 的 fail-closed 哲学
      // 在 client 侧的落地形态 = 单条跳过 + log,防前向兼容期一条新模块
      // 条目钉死整个拉取游标)。
      expect(result.applied, 1);
      expect(await database.tagDao.getTagById('tag-x'), isNotNull);
    });
  });

  group('DELETE → 本地硬删、**不写墓碑**(源头上游,回声乒乓论证见类 doc)', () {
    test('synced 行删除;子表级联清;幂等重删无害;墓碑面恒空', () async {
      await seedAccount(accountData('acc-A'));
      await database.transactionDao.insertTransaction(
          db.TransactionsCompanion.insert(
        id: 'txn-1',
        transactionDate: DateTime.utc(2026, 9, 5),
        description: '待删交易',
        version: 1,
        createdAt: DateTime.utc(2026, 9, 5),
        updatedAt: DateTime.utc(2026, 9, 5),
      ));
      await database.transactionDao.insertEntry(
          db.TransactionEntriesCompanion.insert(
        id: 'e-1',
        transactionId: 'txn-1',
        accountId: 'acc-A',
        chartOfAccountCode: '1001',
        debitCents: 500,
        creditCents: 0,
        note: '',
      ));

      await applier
          .apply([deletion(SyncModule.transaction, 'txn-1', logVersion: 3)]);

      expect(await database.transactionDao.getTransactionById('txn-1'), isNull);
      expect(
          (await database.transactionDao.getAllEntries())
              .where((e) => e.transactionId == 'txn-1'),
          isEmpty); // FK 级联清分录
      // 不写墓碑:pulled delete 源头即 server log,再上行是回声(多设备
      // 乒乓:每设备每次触发一条垃圾 log + 墓碑常驻 pendingCount)。
      expect(await database.syncTombstoneDao.getAllTombstones(), isEmpty);

      // 幂等重投递:行已不在,删除 no-op,不抛。
      final result =
          await applier.apply([deletion(SyncModule.transaction, 'txn-1')]);
      expect(result.applied, 1);
      expect(await database.syncTombstoneDao.getAllTombstones(), isEmpty);
    });

    test('holding_ledger 删除:台账硬删(wire 完备面;client 不产此墓碑)',
        () async {
      await database.holdingDao.insertHoldingTransaction(
          db.HoldingTransactionsCompanion.insert(
        id: 'tr-1',
        accountId: 'acc-inv',
        securityId: 'sec-1',
        tradeType: 3,
        quantity: 1,
        priceCents: 1,
        amountCents: 1,
        feeCents: 0,
        realizedPnlCents: 0,
        tradeDate: DateTime.utc(2026, 9, 1),
        notes: '',
        createdAt: DateTime.utc(2026, 9, 1),
      ));

      await applier.apply([deletion(SyncModule.holdingLedger, 'tr-1')]);

      expect(await database.holdingDao.getHoldingTransactionById('tr-1'), isNull);
      expect(await database.syncTombstoneDao.getAllTombstones(), isEmpty);
    });
  });

  // F18-T2:F17 的「整批单事务原子性 / 未知模块 fail-closed 抛出」两测已由
  // 上方 per-change 隔离组改写(毒丸吸收语义:坏条目跳过不阻批 —— 事务粒度
  // 从整批降为 per-change,论证见 PullApplier 类 doc)。
}
