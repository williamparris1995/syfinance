import 'package:yucai_client/core/recurrence/next_after.dart';
import 'package:yucai_client/core/recurrence/recurrence_rule.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/template_dao.dart';
import 'package:yucai_client/core/localdb/sync_state.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

/// Guest-mode data source for the template module (R6, C-paradigm).
///
/// `record` mirrors the server's RecordTransaction (template service
/// autoRecord): one drift transaction that (1) creates the double-entry
/// transaction at nextDate with the direction-paired entries, (2) advances
/// nextDate via the same AdvanceNextDate rules, (3) bumps the version and
/// records lastTransactionId. The server's UNIQUE idempotency log targets
/// scheduler retries; the guest is a single writer, so it is intentionally
/// omitted (design ADR-4, accepted simplification).
@LazySingleton()
class TemplateLocalDataSource {
  TemplateLocalDataSource(this._database, this._txnLocal,
      {Uuid? uuid, AccountLocalDataSource? accounts})
      : _uuid = uuid ?? const Uuid(),
        _accounts = accounts ?? AccountLocalDataSource(_database);

  final db.AppDatabase _database;
  final TransactionLocalDataSource _txnLocal;
  final Uuid _uuid;
  final AccountLocalDataSource _accounts;

  TemplateDao get _dao => _database.templateDao;

  Future<List<Template>> list({bool? paused}) async =>
      (await _dao.watchAllTemplates().first)
          .map(_toEntity)
          .where((t) => paused == null || t.paused == paused)
          .toList();

  Future<Template> create({
    required String name,
    String description = '',
    required int amountCents,
    TemplateDirection direction = TemplateDirection.unspecified,
    String? sourceAccountId,
    String? destinationAccountId,
    TemplateCycle cycle = TemplateCycle.unspecified,
    int cycleDays = 0,
    int billingDay = 0,
    int interval = 0,
    int weekdayMask = 0,
    int monthlyMode = 0,
    int nth = 0,
    String? startDate,
    String? endDate,
    bool autoRecord = false,
    String? category,
    bool markPending = false,
  }) async {
    if (name.trim().isEmpty) throw const ValidationFailure('模板名不能为空');
    if (amountCents <= 0) throw const ValidationFailure('金额必须大于零');
    if (direction == TemplateDirection.unspecified) {
      throw const ValidationFailure('模板方向未指定');
    }
    if (cycle == TemplateCycle.unspecified) {
      throw const ValidationFailure('模板周期未指定');
    }
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    // nextDate mirrors the server's CalculateNextDate(startDate, cycle,
    // billingDay, 1): first occurrence one period after the start date
    // (custom = daily default server-side).
    final start = _parseDate(startDate);
    // 共享内核推进(FR-5 统一):首个发生日 = 严格晚于起始日的第一个命中。
    final rule = RecurrenceRule.fromInts(
        cycle: cycle.index,
        cycleDays: cycleDays,
        billingDay: billingDay,
        interval: interval,
        weekdayMask: weekdayMask,
        monthlyMode: monthlyMode,
        nth: nth);
    final next = nextAfter(start, rule);
    await _dao.insertTemplate(db.TransactionTemplatesCompanion.insert(
      id: id,
      name: name,
      description: description,
      amountCents: amountCents,
      direction: direction.index,
      sourceAccountId: sourceAccountId ?? '',
      destinationAccountId: Value(destinationAccountId),
      cycle: cycle.index,
      cycleDays: cycleDays,
      billingDay: billingDay,
      interval: Value(interval),
      weekdayMask: Value(weekdayMask),
      monthlyMode: Value(monthlyMode),
      nth: Value(nth),
      nextDate: next,
      startDate: start,
      // F14 疑点 #2:null/空 endDate = 永续(语义 null 落库),不再兜底今天
      // —— 否则实体 endDate 非 null,调度 _catchUpOne 按「≤ endDate 才记」
      // 把永续订阅截断到创建日,次日起停记。
      endDate: Value(_parseEndDate(endDate)),
      autoRecord: autoRecord,
      paused: false,
      category: category ?? '',
      version: 1,
      createdAt: now,
      updatedAt: now,
      syncState: syncStateValue(markPending),
    ));
    return _toEntity((await _dao.getTemplateById(id))!);
  }

  /// 各写方法 [markPending] 三态语义(F10 FR-3):guest 缺省 false → 行
  /// synced;boundOfflineLocal / boundRemote 降级传 true → 行 pending。
  Future<Template> update({
    required String id,
    required int version,
    String? name,
    String? description,
    int? amountCents,
    TemplateCycle? cycle,
    int? cycleDays,
    int? billingDay,
    int? interval,
    int? weekdayMask,
    int? monthlyMode,
    int? nth,
    String? endDate,
    bool? autoRecord,
    bool markPending = false,
  }) async {
    final row = await _dao.getTemplateById(id);
    if (row == null) throw const ServerFailure('模板不存在');
    if (row.version != version) {
      throw const ServerFailure('数据已过期，请刷新后重试');
    }
    final newCycle = cycle == null ? row.cycle : cycle.index;
    final newCycleDays = cycleDays ?? row.cycleDays;
    final newBillingDay = billingDay ?? row.billingDay;
    final newInterval = interval ?? row.interval;
    final newWeekdayMask = weekdayMask ?? row.weekdayMask;
    final newMonthlyMode = monthlyMode ?? row.monthlyMode;
    final newNth = nth ?? row.nth;
    final newRule = RecurrenceRule.fromInts(
        cycle: newCycle,
        cycleDays: newCycleDays,
        billingDay: newBillingDay,
        interval: newInterval,
        weekdayMask: newWeekdayMask,
        monthlyMode: newMonthlyMode,
        nth: newNth);
    // 规则变化 → nextDate = 新规则下 ≥ max(起始日, 今天) 的首个发生日
    // (镜像 server UpdateTemplate;guest 单写者无并发重复)。
    Value<DateTime> nextDate = const Value.absent();
    if (newRule !=
        RecurrenceRule.fromInts(
            cycle: row.cycle,
            cycleDays: row.cycleDays,
            billingDay: row.billingDay,
            interval: row.interval,
            weekdayMask: row.weekdayMask,
            monthlyMode: row.monthlyMode,
            nth: row.nth)) {
      var base = _nowDate();
      final start =
          DateTime.utc(row.startDate.year, row.startDate.month, row.startDate.day);
      if (start.isAfter(base)) base = start;
      nextDate = Value(nextAfter(
          DateTime.utc(base.year, base.month, base.day - 1), newRule));
    }
    await _dao.updateTemplate(db.TransactionTemplatesCompanion(
      id: Value(id),
      name: Value(name ?? row.name),
      description: Value(description ?? row.description),
      amountCents: Value(amountCents ?? row.amountCents),
      cycle: Value(newCycle),
      cycleDays: Value(newCycleDays),
      billingDay: Value(newBillingDay),
      interval: Value(newInterval),
      weekdayMask: Value(newWeekdayMask),
      monthlyMode: Value(newMonthlyMode),
      nth: Value(newNth),
      nextDate: nextDate,
      // F14 疑点 #2:update 的 endDate 统一走永续语义解析:null/空串 → 清空
      // (Value(null) = 落库 NULL)。对齐 server:update 空串 → handler 跳过
      // 解析 → service 置 nil → repo ClearEndDate;本地旧实现「null = 保留
      // 旧值」与远端分歧(guest 编辑表单清空 endDate 静默失效)。真实调用链
      // (bloc ← 表单)只在用户清空时传 null,故清空语义即用户意图。
      endDate: Value(_parseEndDate(endDate)),
      autoRecord: Value(autoRecord ?? row.autoRecord),
      version: Value(row.version + 1),
      updatedAt: Value(DateTime.now().toUtc()),
      syncState: markPending
          ? const Value(SyncState.pending)
          : const Value.absent(),
    ));
    return _toEntity((await _dao.getTemplateById(id))!);
  }

  /// [writeTombstone]:bound 路由删除硬删行后补墓碑(FR-4);guest 不写
  /// (绑定走全量首传)。
  Future<void> delete(String id, {bool writeTombstone = false}) async {
    if (await _dao.getTemplateById(id) == null) throw const ServerFailure('模板不存在');
    await _database.transaction(() async {
      await _dao.deleteTemplateById(id);
      if (writeTombstone) {
        await _database.syncTombstoneDao.upsertTombstone(
            db.SyncTombstonesCompanion.insert(
                module: SyncModule.template,
                entityId: id,
                deletedAt: DateTime.now().toUtc()));
      }
    });
  }

  Future<Template> pause(String id, {bool markPending = false}) =>
      _flipPaused(id, true, markPending: markPending);
  Future<Template> resume(String id, {bool markPending = false}) =>
      _flipPaused(id, false, markPending: markPending);

  Future<Template> _flipPaused(String id, bool paused,
      {bool markPending = false}) async {
    final row = await _dao.getTemplateById(id);
    if (row == null) throw const ServerFailure('模板不存在');
    await _dao.updateTemplate(db.TransactionTemplatesCompanion(
      id: Value(id),
      paused: Value(paused),
      version: Value(row.version + 1),
      updatedAt: Value(DateTime.now().toUtc()),
      syncState: markPending
          ? const Value(SyncState.pending)
          : const Value.absent(),
    ));
    return _toEntity((await _dao.getTemplateById(id))!);
  }

  Future<Template> get(String id) async =>
      _toEntityOrNull(await _dao.getTemplateById(id)) ??
      (throw const ServerFailure('模板不存在'));

  /// [markPending]:复合写(FR-3)—— 同一事务内模板头行(推进 nextDate/
  /// lastTransactionId)、新记交易头行、分类账户兜底补建行统一置 pending,
  /// 待回网整包上行。
  Future<RecordResult> record(String templateId,
      {bool markPending = false}) async {
    final row = await _dao.getTemplateById(templateId);
    if (row == null) throw const ServerFailure('模板不存在');
    if (row.paused) throw const ServerFailure('模板已暂停');

    final next = row.nextDate;
    String? txnId;
    await _database.transaction(() async {
      txnId = await _createTxnForRow(row, next, markPending: markPending);
      await _dao.updateTemplate(db.TransactionTemplatesCompanion(
        id: Value(templateId),
        nextDate: Value(nextAfter(
            next,
            RecurrenceRule.fromInts(
                cycle: row.cycle,
                cycleDays: row.cycleDays,
                billingDay: row.billingDay,
                interval: row.interval,
                weekdayMask: row.weekdayMask,
                monthlyMode: row.monthlyMode,
                nth: row.nth))),
        lastTransactionId: Value(txnId),
        version: Value(row.version + 1),
        updatedAt: Value(DateTime.now().toUtc()),
        syncState: markPending
            ? const Value(SyncState.pending)
            : const Value.absent(),
      ));
    });
    final updated = await _dao.getTemplateById(templateId);
    return RecordResult(
      transactionId: txnId!,
      nextDate: updated?.nextDate,
    );
  }

  /// 分类账户兜底(user-acceptance 修复):表单「分类(可选)」可空,而复式
  /// 分录的借/贷方必须有账户 —— 为空(或指向已删账户)时按模板名自动补建
  /// 对应方向的系统分类账户(expense/income),杜绝 accountId='' →
  /// 「账户不存在」。
  Future<String> _ensureCategoryAccount(db.TransactionTemplate row,
      {bool markPending = false}) async {
    final isExpense = row.direction == 1;
    final wantType = isExpense ? 5 : 4; // contract: 4 income / 5 expense
    final id = row.category;
    if (id.isNotEmpty) {
      final acc = await _database.accountDao.getAccountById(id);
      if (acc != null) return id;
    }
    // 按模板名建系统分类账户(幂等:同名+同类型复用)。
    final name = '订阅·${row.name}';
    final existing = await _database.select(_database.accounts).get();
    final match = existing
        .where((a) => a.name == name && a.accountType == wantType)
        .firstOrNull;
    if (match != null) return match.id;
    final created = await _accounts.create(
      CreateAccountParams(
        name: name,
        accountType: isExpense ? AccountType.expense : AccountType.income,
        category: AccountCategory.otherAsset,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        ownership: Ownership.personal,
      ),
      // 兜底补建的账户与整笔离线记录同包上行(FR-3 复合写语义)。
      markPending: markPending,
    );
    return created.id;
  }

  /// Direction-paired entries, mirroring the server's recorder adapter:
  /// expense = debit category(expense) / credit source(asset);
  /// income = debit source(asset) / credit category(income);
  /// transfer = debit destination / credit source.
  Future<String> _createTxnForRow(db.TransactionTemplate row, DateTime date,
      {bool markPending = false}) async {
    final entries = <TransactionEntry>[];
    // 分类账户:空/失效时兜底补建(见 _ensureCategoryAccount)。
    final categoryAcc =
        await _ensureCategoryAccount(row, markPending: markPending);
    switch (row.direction) {
      case 1: // expense: debit category / credit source
        entries
          ..add(TransactionEntry(
              accountId: categoryAcc,
              debitCents: row.amountCents,
              creditCents: 0))
          ..add(TransactionEntry(
              accountId: row.sourceAccountId,
              debitCents: 0,
              creditCents: row.amountCents));
      case 2: // income: debit source / credit category
        entries
          ..add(TransactionEntry(
              accountId: row.sourceAccountId,
              debitCents: row.amountCents,
              creditCents: 0))
          ..add(TransactionEntry(
              accountId: categoryAcc,
              debitCents: 0,
              creditCents: row.amountCents));
      case 3: // transfer: debit destination / credit source
        if ((row.destinationAccountId ?? '').isEmpty) {
          throw const ValidationFailure('转账方向模板缺少目标账户');
        }
        entries
          ..add(TransactionEntry(
              accountId: row.destinationAccountId!,
              debitCents: row.amountCents,
              creditCents: 0))
          ..add(TransactionEntry(
              accountId: row.sourceAccountId,
              debitCents: 0,
              creditCents: row.amountCents));
      default:
        throw const ValidationFailure('模板方向未指定');
    }
    final txn = await _txnLocal.recordTransaction(
        RecordTransactionParams(
      transactionDate: date,
      description: row.name,
      entries: entries,
    ), markPending: markPending);
    return txn.id;
  }

  Template? _toEntityOrNull(db.TransactionTemplate? row) =>
      row == null ? null : _toEntity(row);

  Template _toEntity(db.TransactionTemplate r) => Template(
        id: r.id,
        name: r.name,
        description: r.description,
        amountCents: r.amountCents,
        direction: TemplateDirection.values[r.direction],
        sourceAccountId: r.sourceAccountId.isEmpty ? null : r.sourceAccountId,
        destinationAccountId: r.destinationAccountId,
        cycle: TemplateCycle.values[r.cycle],
        cycleDays: r.cycleDays,
        billingDay: r.billingDay,
        interval: r.interval,
        weekdayMask: r.weekdayMask,
        monthlyMode: r.monthlyMode == 1
            ? TemplateMonthlyMode.byNthWeekday
            : TemplateMonthlyMode.byDate,
        nth: r.nth,
        nextDate: _formatDate(r.nextDate),
        startDate: _formatDate(r.startDate),
        endDate: _formatDate(r.endDate),
        autoRecord: r.autoRecord,
        paused: r.paused,
        lastTransactionId: r.lastTransactionId,
        category: r.category.isEmpty ? null : r.category,
        version: r.version,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  DateTime _nowDate() {
    final n = DateTime.now().toUtc();
    return DateTime.utc(n.year, n.month, n.day);
  }

  DateTime _parseDate(String? s) {
    if (s == null || s.isEmpty) return _nowDate();
    final d = DateTime.tryParse(s);
    return d == null ? _nowDate() : DateTime.utc(d.year, d.month, d.day);
  }

  /// endDate 专用解析(F14 疑点 #2 语义裁决):
  /// - **null/空串 → 语义 null(永续)**:与 server 契约逐位对齐 —— proto 契约
  ///   空串即「未设置」,server handler `req.EndDate != ""` 门控,空串落库
  ///   NULL;调度器(AutoRecordScheduler._catchUpOne)对 null endDate 不截断,
  ///   永续订阅按期补账。
  /// - **不可解析串 → fail-closed 兜底今天(不永续)**:脏数据被当成「无期限
  ///   订阅」会无限生成交易,资金侧风险远大于漏记;与 server 对不可解析串的
  ///   处理(`d, _ := parseDate(...)` 忽略错误 → 零值 = 公元 1 年,等效「已
  ///   到期」)同向 fail-closed,仅把停记点从公元 1 年收敛到今天(避免本地
  ///   库出现奇异的 0001 日期)。
  /// - **存量数据不迁移**:旧实现已把 null 兜底存成「创建当天」的行保持原样
  ///   (数据不动);用户在编辑表单清空 endDate 即触发上面的清空语义恢复永续。
  DateTime? _parseEndDate(String? s) {
    if (s == null || s.isEmpty) return null;
    final d = DateTime.tryParse(s);
    return d == null ? _nowDate() : DateTime.utc(d.year, d.month, d.day);
  }

  String? _formatDate(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
}
