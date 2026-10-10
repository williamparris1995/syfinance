// F50 sync keep-existing 回归:counts_toward_card_limit 是**本地私有列**
// (不在 proto / envelope 契约),债从远端重建/覆盖本地行时必须保留本地现值;
// 本地不存在的服务端新行取列默认 true(计入)。
//
// 覆盖两条下行路径(design ADR-2 分工):
// - BoundMirror._refreshDebts:proto 全字段重建实体 → 镜像 delete-all-synced
//   + insert;映射处(mirrorDebtToRow)显式透传本地值,否则重建行会把
//   proto 重建实体的缺省 true 覆写掉本地 false;
// - PullApplier:envelope 行 → insertOnConflictUpdate;companion 不携带该列
//   (Value.absent)→ DO UPDATE SET 不触碰该列 = 天然 keep-existing,新行走
//   列 DEFAULT 1。此组为行为钉(防将来 envelope/proto 化前误清)。
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:dartz/dartz.dart' as dz;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/binding/data/pull_applier.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/envelope_codec.dart';
import 'package:yucai_client/core/localdb/sync_state.dart' show SyncModule;
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

final getIt = GetIt.instance;

class _MockDebtRepo extends Mock implements DebtRepository {}

/// 服务端(proto 重建)形态的 Debt 实体:proto 无开关字段 → 实体缺省 true。
Debt _serverDebt(String id) => Debt(
      id: id,
      accountId: 'acc-$id',
      counterparty: '银行$id',
      interestRate: 0.05,
      amortization: AmortizationMethod.equalPrincipalInterest,
      startDate: DateTime.utc(2026, 9, 1),
      dueDate: DateTime.utc(2027, 9, 1),
      totalPrincipalCents: 1000000,
      remainingPrincipalCents: 1000000,
      version: 2,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
      subtype: DebtSubtypes.cardLoan,
      collectionAccountId: 'card-1',
      // 故意不传 countsTowardCardLimit:模拟 proto 全字段构造(无该字段)。
    );

/// 本地 debts 行 fixture(经 DAO 直插,绕过业务层)。
Future<void> _seedDebt(db.AppDatabase database, String id,
        {required bool countsTowardCardLimit}) =>
    database.debtDao.insertDebt(db.DebtsCompanion.insert(
      id: id,
      accountId: 'acc-$id',
      counterparty: '银行$id',
      interestRate: 0.05,
      amortizationMethod: 1,
      startDate: DateTime.utc(2026, 9, 1),
      dueDate: DateTime.utc(2027, 9, 1),
      totalPrincipalCents: 1000000,
      debtType: 1,
      subtype: DebtSubtypes.cardLoan,
      contact: '',
      contractRef: '',
      collectionAccountId: const Value('card-1'),
      countsTowardCardLimit: Value(countsTowardCardLimit),
      version: 1,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    ));

void main() {
  late db.AppDatabase database;

  setUp(() => database = db.AppDatabase(NativeDatabase.memory()));
  tearDown(() {
    database.close();
    getIt.reset();
  });

  group('BoundMirror(debt 全量重建)keep-existing', () {
    test('重建行保留本地开关值;服务端新行取默认 true', () async {
      // 本地已有行:开关关(备用金类)。
      await _seedDebt(database, 'd-local', countsTowardCardLimit: false);
      // 服务端列表:同 id 行(proto 重建 → 缺省 true)+ 一支本地没有的新行。
      final serverIds = ['d-local', 'd-server-new'];
      final repo = _MockDebtRepo();
      when(() => repo.list()).thenAnswer(
          (_) async => dz.Right([for (final id in serverIds) _serverDebt(id)]));
      when(() => repo.get(any())).thenAnswer((inv) async =>
          dz.Right(DebtDetail(
              debt: _serverDebt(inv.positionalArguments[0] as String),
              schedule: const [])));
      getIt.registerSingleton<DebtRepository>(repo);

      await BoundMirror(database).refreshModule(MirrorModule.debt);

      // 本地现值保留:开关关不被 proto 缺省 true 覆写。
      final kept = await database.debtDao.getDebtById('d-local');
      expect(kept!.countsTowardCardLimit, isFalse,
          reason: '镜像重建不得覆写本地私有开关列(keep-existing)');
      // 服务端新拉取行(本地不存在)→ 列默认 true。
      final fresh = await database.debtDao.getDebtById('d-server-new');
      expect(fresh!.countsTowardCardLimit, isTrue);
    });
  });

  group('PullApplier(增量 upsert)keep-existing', () {
    late PullApplier applier;

    setUp(() => applier = PullApplier(database));

    /// 他设备债务行(envelope 生产与 push 同源)—— 不含本地私有键。
    Map<String, dynamic> envelopeOf(String id, {int version = 2}) =>
        debtRowToEnvelope(
          db.Debt(
            id: id,
            accountId: 'acc-$id',
            counterparty: '银行$id',
            interestRate: 0.05,
            amortizationMethod: 1,
            cycle: 2,
            interval: 1,
            weekdayMask: 0,
            monthlyMode: 0,
            nth: 0,
            billingDay: 0,
            flatFeeCents: 0,
            countsTowardCardLimit: true, // 服务端行无此列概念;envelope 不透出
            interestWaivedCents: 0,
            startDate: DateTime.utc(2026, 9, 1),
            dueDate: DateTime.utc(2027, 9, 1),
            totalPrincipalCents: 1000000,
            debtType: 1,
            subtype: DebtSubtypes.cardLoan,
            contact: '',
            contractRef: '',
            guarantorName: '',
            guarantorContact: '',
            collectionAccountId: 'card-1',
            version: version,
            createdAt: DateTime.utc(2026, 9, 1),
            updatedAt: DateTime.utc(2026, 10, 1),
            syncState: 'synced',
          ),
          const [],
        );

    test('同 id 下行覆盖:本地开关值保留;新行默认 true', () async {
      // 本地行 v1 开关关;下行 v2(他设备改名,无开关键)。
      await _seedDebt(database, 'd-pull', countsTowardCardLimit: false);
      final env = envelopeOf('d-pull', version: 2);
      expect(env.containsKey('CountsTowardCardLimit'), isFalse,
          reason: '本地私有列不得进入 envelope 契约');
      final result = await applier.apply([
        PulledChange(
          module: SyncModule.debt,
          entityId: 'd-pull',
          isDelete: false,
          payload: utf8.encode(jsonEncode(env)),
          logVersion: 1,
          deviceId: 'device-B',
        ),
      ]);

      expect(result.applied, 1);
      final kept = await database.debtDao.getDebtById('d-pull');
      expect(kept!.version, 2); // 覆盖确实生效
      expect(kept.countsTowardCardLimit, isFalse,
          reason: 'absent 列不在 DO UPDATE SET 内 = keep-existing');

      // 新行(本地不存在):insert 走列 DEFAULT 1 = true。
      await applier.apply([
        PulledChange(
          module: SyncModule.debt,
          entityId: 'd-new',
          isDelete: false,
          payload: utf8.encode(jsonEncode(envelopeOf('d-new'))),
          logVersion: 2,
          deviceId: 'device-B',
        ),
      ]);
      final fresh = await database.debtDao.getDebtById('d-new');
      expect(fresh!.countsTowardCardLimit, isTrue);
    });
  });
}
