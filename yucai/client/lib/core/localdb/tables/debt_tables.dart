import 'package:drift/drift.dart';

import '../sync_state.dart' show SyncState;

/// Contract tables for the debt module (backup payload []DebtDetails with
/// nested Schedule flattened into a child table).
class Debts extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get counterparty => text()();
  RealColumn get interestRate => real()();
  IntColumn get amortizationMethod => integer()();
  // 周期规则(0 值 = 旧「按月」;cycle 存 proto 序号 1-4,默认 2=monthly)。
  IntColumn get cycle => integer().withDefault(const Constant(2))();
  IntColumn get interval => integer().withDefault(const Constant(1))();
  IntColumn get weekdayMask => integer().withDefault(const Constant(0))();
  IntColumn get monthlyMode => integer().withDefault(const Constant(0))();
  IntColumn get nth => integer().withDefault(const Constant(0))();
  // 一次性利息减免(分,银行优惠):生成计划时从最早几期利息依次扣减。
  IntColumn get interestWaivedCents => integer().withDefault(const Constant(0))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get totalPrincipalCents => integer()();
  IntColumn get debtType => integer()();
  TextColumn get subtype => text()();
  TextColumn get contact => text()();
  TextColumn get contractRef => text()();
  // 担保人字段(2026-09 用户需求):可选自由文本,'' = 无/未填。
  TextColumn get guarantorName => text().withDefault(const Constant(''))();
  TextColumn get guarantorContact => text().withDefault(const Constant(''))();
  TextColumn get collectionAccountId => text().nullable()();
  IntColumn get version => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// F10 FR-3/ADR-2:同步状态(值域/语义见 sync_state.dart)。
  TextColumn get syncState =>
      text().withDefault(const Constant(SyncState.synced))();

  @override
  Set<Column> get primaryKey => {id};
}

class PaymentScheduleEntries extends Table {
  TextColumn get id => text()();
  TextColumn get debtId =>
      text().references(Debts, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get paymentDate => dateTime()();
  IntColumn get principalCents => integer()();
  IntColumn get interestCents => integer()();
  IntColumn get totalCents => integer()();
  IntColumn get paidCents => integer()();
  BoolColumn get paid => boolean()();
  TextColumn get transactionId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 合同文件附件(2026-09 用户需求,v1 本地存储):
/// 一笔债务/债权至多一份合同文件(表单再选 = 替换)。文件本体存
/// `<appSupport>/contract_files/debts/<debtId>/<storedName>`,本表只存元数据。
/// v1 不上行服务器(guest/bound 均为设备本地),换设备不跟随 —— 后续票再议
/// blob 上行。
///
/// **debtId 无外键(v6→v7 重建,2026-09-17「上传卡住」修复)**:绑定在线创建
/// 的债务时,其头行由镜像异步回填,先到的附件行会命中 FK(foreign key
/// constraint failed)→ 异常打断表单 pop。本表是设备本地 overlay,必须容忍
/// 指向暂不在本地 debts 表的服务端 id;孤儿行由 store 显式 remove 清理,
/// 不依赖级联。
class ContractAttachments extends Table {
  TextColumn get id => text()();
  TextColumn get debtId => text()();
  TextColumn get originalName => text()(); // 用户可见名(含扩展名)
  TextColumn get storedName => text()(); // 落盘文件名(uuid + 扩展名)
  IntColumn get sizeBytes => integer()();
  DateTimeColumn get attachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
