import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'daos/account_dao.dart';
import 'daos/budget_dao.dart';
import 'daos/debt_dao.dart';
import 'daos/derived_dao.dart';
import 'daos/goal_dao.dart';
import 'daos/holding_dao.dart';
import 'daos/reference_dao.dart';
import 'daos/sync_cursor_dao.dart';
import 'daos/sync_tombstone_dao.dart';
import 'daos/tag_dao.dart';
import 'daos/template_dao.dart';
import 'daos/transaction_dao.dart';
import 'sync_state.dart' show SyncState;
import 'tables/account_tables.dart';
import 'tables/budget_tables.dart';
import 'tables/debt_tables.dart';
import 'repairs.dart' show runRepaymentHistoryRepairOnce;
import 'tables/app_meta.dart';
import 'tables/reminder_tables.dart';
import 'tables/derived_tables.dart';
import 'tables/goal_tables.dart';
import 'tables/holding_tables.dart';
import 'tables/reference_tables.dart';
import 'tables/sync_tables.dart';
import 'tables/tag_tables.dart';
import 'tables/template_tables.dart';
import 'tables/transaction_tables.dart';

part 'app_database.g.dart';

/// Local-first store (R6): drift is the primary storage while unbound and the
/// mirror after binding. Contract tables follow the server backup payload
/// (design.md ADR-3); timestamps persist as text (build.yaml) to keep the
/// RFC3339-compatible wire form.
@DriftDatabase(
  tables: [
    Accounts,
    ChartOfAccounts,
    Transactions,
    TransactionEntries,
    Debts,
    PaymentScheduleEntries,
    ContractAttachments,
    ReminderLogs,
    ReminderDismissals,
    Budgets,
    BudgetItems,
    Goals,
    GoalAccountLinks,
    GoalDebtLinks,
    Tags,
    TransactionTags,
    TransactionTemplates,
    AppMeta,
    Holdings,
    HoldingTransactions,
    Currencies,
    RateHistories,
    Securities,
    SecurityPriceHistories,
    DebtProgressSnapshots,
    GoalProgressSnapshots,
    HoldingSnapshots,
    HoldingLots,
    SyncTombstones,
    SyncCursors,
  ],
  daos: [
    AccountDao,
    TransactionDao,
    DebtDao,
    BudgetDao,
    GoalDao,
    TagDao,
    TemplateDao,
    HoldingDao,
    ReferenceDao,
    DerivedDao,
    SyncTombstoneDao,
    SyncCursorDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// 库文件名(E2E 隔离用 dart-define):--dart-define=YUCAI_DB_FILE=
  /// yucai_test.db → 集成测试在独立库上跑,用户真实库(yucai.db)永不被
  /// 测试触碰。F21-T1 抽为公共常量:清空重置(DataResetController)删库
  /// 文件时复用同一解析,保证删的就是当前打开的那个库(单一事实源)。
  static const dbFileName =
      String.fromEnvironment('YUCAI_DB_FILE', defaultValue: 'yucai.db');

  /// The file path resolves lazily on first query so DI registration stays
  /// synchronous (path_provider needs a live platform binding).
  static QueryExecutor _openConnection() => LazyDatabase(() async {
        final dir = await getApplicationSupportDirectory();
        final file = File('${dir.path}/$dbFileName');
        return NativeDatabase.createInBackground(file);
      });

  /// Lightweight startup self-check (R6 F): SQLite integrity plus dangling
  /// reference counts on the cross-module FK-by-convention columns.
  /// Returns (ok, detail); display-only — never repairs.
  Future<(bool, String)> integrityCheck() async {
    final integrity = await customSelect('PRAGMA integrity_check').get();
    final integrityOk =
        integrity.isNotEmpty && integrity.first.data.values.first == 'ok';
    if (!integrityOk) {
      return (false, '数据库完整性校验失败');
    }
    final dangling = <String, int>{};
    Future<void> count(String label, String sql) async {
      final rows = await customSelect(sql).get();
      final n = (rows.isNotEmpty ? rows.first.data.values.first : 0) as int;
      if (n > 0) dangling[label] = n;
    }
    await count('交易分录账户', '''
      SELECT COUNT(*) AS n FROM transaction_entries e
      WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.id = e.account_id)
    ''');
    await count('预算项账户', '''
      SELECT COUNT(*) AS n FROM budget_items i
      WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.id = i.account_id)
    ''');
    await count('目标关联账户', '''
      SELECT COUNT(*) AS n FROM goal_account_links l
      WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.id = l.linked_id)
    ''');
    if (dangling.isNotEmpty) {
      final parts = dangling.entries.map((e) => '${e.key}×${e.value}').join('、');
      return (false, '悬挂引用($parts)');
    }
    return (true, '');
  }

  @override
  int get schemaVersion => 10;

  /// 幂等加列:先查 PRAGMA table_info,列已存在则跳过。
  /// 背景:库文件可能被不同版本的 App 触碰(安装版/调试版/手工恢复备份),
  /// user_version 与真实列结构可能脱节,盲 ALTER 会撞 duplicate column。
  Future<void> _addColumnIfAbsent(TableInfo table, GeneratedColumn column) async {
    final cols =
        await customSelect('PRAGMA table_info(' + table.actualTableName + ')').get();
    final exists = cols.any((r) => r.data['name'] == column.name);
    if (!exists) {
      await createMigrator().addColumn(table, column);
    }
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // Mechanism only (spec FR-5): add per-version steps when the schema
        // evolves beyond v1.
        onUpgrade: (m, from, to) async {
          // v1→v2(B1 通知):新增 ReminderLogs(当日去重记录)。
          if (from < 2) {
            await m.createTable(reminderLogs);
          }
          // v2→v3(F10 FR-3/FR-4,design ADR-2/ADR-4):8 头表加 sync_state
          // 列(NOT NULL DEFAULT 'synced',ALTER TABLE 回填既有行 = synced)
          // + 增 SyncTombstones 墓碑表。仅加列/建表,既有数据无损。
          if (from < 3) {
            await _addColumnIfAbsent(accounts, accounts.syncState);
            await _addColumnIfAbsent(transactions, transactions.syncState);
            await _addColumnIfAbsent(debts, debts.syncState);
            await _addColumnIfAbsent(budgets, budgets.syncState);
            await _addColumnIfAbsent(goals, goals.syncState);
            await _addColumnIfAbsent(holdings, holdings.syncState);
            await _addColumnIfAbsent(tags, tags.syncState);
            await _addColumnIfAbsent(transactionTemplates, transactionTemplates.syncState);
            await m.createTable(syncTombstones);
          }
          // v3→v4(F17-T2 FR-3,design ADR-3):增 SyncCursors 拉取游标表
          // (单行;缺省 0 = since 从头拉,幂等无害)。仅建表,无损。
          if (from < 4) {
            await m.createTable(syncCursors);
          }
          // v4→v5(2026-09 担保人字段 + 合同附件):Debts 加 guarantor_name /
          // guarantor_contact 两列(text NOT NULL DEFAULT '',存量行回填空串,
          // 语义 = 无担保人)+ 增 ContractAttachments 附件表(本地 v1)。
          // 仅加列/建表,既有数据无损。
          if (from < 5) {
            await _addColumnIfAbsent(debts, debts.guarantorName);
            await _addColumnIfAbsent(debts, debts.guarantorContact);
            await m.createTable(contractAttachments);
          }
          // v5→v6(周期规则统一):TransactionTemplates 加 interval/weekday_mask/
          // monthly_mode/nth 四列,Debts 加 cycle/interval/weekday_mask/
          // monthly_mode/nth 五列(全部 NOT NULL 带默认 = 旧「按月/单间隔」
          // 行为,存量行零迁移)。仅加列,无损。
          if (from < 6) {
            await _addColumnIfAbsent(
                transactionTemplates, transactionTemplates.interval);
            await _addColumnIfAbsent(
                transactionTemplates, transactionTemplates.weekdayMask);
            await _addColumnIfAbsent(
                transactionTemplates, transactionTemplates.monthlyMode);
            await _addColumnIfAbsent(transactionTemplates, transactionTemplates.nth);
            await _addColumnIfAbsent(debts, debts.cycle);
            await _addColumnIfAbsent(debts, debts.interval);
            await _addColumnIfAbsent(debts, debts.weekdayMask);
            await _addColumnIfAbsent(debts, debts.monthlyMode);
            await _addColumnIfAbsent(debts, debts.nth);
          }
          // v6→v7(2026-09-17「上传卡住」修复):重建 contract_attachments 去掉
          // debt_id 对本地 debts 的外键 —— 在线创建的债务头行由镜像异步回填,
          // 先到的附件行命中 FK(constraint failed)打断表单 pop。SQLite 不能
          // ALTER 删 FK,走 rename→create→copy→drop 整表重建;本地 overlay 表
          // 必须容忍指向服务端 id,数据无损。
          if (from < 7) {
            // renameTable(table, oldName) 的参数序是「新表信息, 旧名」,不便
            // 表达「改名让位」,故重命名走原生 SQL:
            await customStatement(
                'ALTER TABLE contract_attachments RENAME TO contract_attachments_v6');
            await m.createTable(contractAttachments);
            await customStatement(
                'INSERT OR IGNORE INTO contract_attachments '
                '(id, debt_id, original_name, stored_name, size_bytes, attached_at) '
                'SELECT id, debt_id, original_name, stored_name, size_bytes, attached_at '
                'FROM contract_attachments_v6');
            await m.deleteTable('contract_attachments_v6');
          }
          // v7→v8(利息一次性减免):Debts 加 interest_waived_cents
          // (NOT NULL DEFAULT 0,存量行 = 无减免)。仅加列,无损。
          if (from < 8) {
            await _addColumnIfAbsent(debts, debts.interestWaivedCents);
          }
          // v8→v9:AppMeta 键值元数据表(一次性修复标记等)。
          if (from < 9) {
            await m.createTable(appMeta);
          }
          // v9→v10(2026-09 信用卡还款催办):增 ReminderDismissals
          // 「不再提醒」挂失表。仅建表,无损。
          if (from < 10) {
            await m.createTable(reminderDismissals);
          }
        },
        // SQLite ships with foreign keys off; cascade deletes (design LLD)
        // need the pragma enabled per connection.
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');

          // 历史还款记录一次性修复(只跑一次,AppMeta 标记门控;失败静默,
          // 下次打开重试)。详见 repairs.dart 头注释。
          try {
            await runRepaymentHistoryRepairOnce(this);
          } catch (_) {}
          // 一次性数据修复(2026-09-17):还款交易描述曾把函数对象插进字符串
          // ("还款 Closure: ... (row)"),真实对手方名从未写入。经
          // 期次表反查关联债务取回 counterparty;只命中含 Closure 残渣的行,
          // 幂等且查不到关联债务的行保持原样。
          await customStatement("""
            UPDATE transactions SET description =
              '还款 ' || (SELECT d.counterparty FROM debts d
                          JOIN payment_schedule_entries p
                            ON p.debt_id = d.id
                          WHERE p.transaction_id = transactions.id)
            WHERE description LIKE '%Closure:%'
              AND description LIKE '还款 %'
              AND EXISTS (SELECT 1 FROM debts d
                          JOIN payment_schedule_entries p
                            ON p.debt_id = d.id
                          WHERE p.transaction_id = transactions.id)
          """);
        },
      );
}
