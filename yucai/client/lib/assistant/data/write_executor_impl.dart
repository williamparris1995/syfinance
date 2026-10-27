// F70-T2 —— WriteExecutor 生产实现(ADR-1/ADR-3/ADR-6,FR-1..3/NFR-1/NFR-3)。
//
// 确认门执行器:实际落库**唯一入口**,仅由 bloc 的用户确认回调触发
// (FR-5 代码门;绕过负测钉死 bloc→executor 为唯一通道)。三路执行全部走
// TransactionRepository 表单同管道(NFR-1:余额联动/离线缓冲/同步上行
// 同源获得):
//  - Add → recordExpense/recordIncome(方向分流;direction→expense/income
//    AccountId=categoryId,assetAccountId=accountId —— T1 钉定口径);
//  - Update → getById 现读(version + 未改字段现状)→ patch 合并 →
//    **全分录重建**(表单编辑路径 `transaction_form._buildEntries` 的
//    _type switch 镜像:expense=[科目 debit, 资产 credit] / income=
//    [资产 debit, 科目 credit];update 是全分录替换,entry note 逐侧保留
//    —— 否则编辑保存会把原 note 冲掉);
//  - Delete → getById 现读(存在性 + note 素材)→ delete。
//
// 幂等集(ADR-3):key→entityId,成功才记录;**失败不耗键**(重试同 key
// 再执行);重复触发 = AlreadyExecuted,零 repo 调用/零审计/零重复注入。
// 审计(NFR-3):每路成/败各一行 logWrite(English/ASCII;payload 摘要 =
// WriteAction.toString —— T1 已保证全 ASCII);F71 落表时按契约消费。
// 会话注入(ADR-2):成功经 appendToolOutcome 追加**中文紧凑单行** note
// (进会话上下文与 UI,不进日志串 —— 日志串无 CJK 项目门禁)。
//
// 构造注入:TransactionRepository + AgentLoopService(appendToolOutcome;
// loop 不依赖 executor —— 无构造环)+ AssistantAuditLog。无 clock 缝:
// 三路均无「现在」语义(Add 日期由提案钉定,update/delete 现读现状,
// transactionTime 缺省空串 = 服务端盖戳),预留空缝只会引入 unused 告警。
//
// DI:注解仅文档(1m 手工注册家法 —— 构造参数含领域 port,与
// AgentLoopServiceImpl 同款;生成图不可 regen,实际绑定在 injection 1m)。
library;

import 'package:injectable/injectable.dart';

import 'package:yucai_client/assistant/data/audit_log.dart';
import 'package:yucai_client/assistant/data/tools/tool_args.dart' show yuan;
import 'package:yucai_client/assistant/domain/agent_loop.dart';
import 'package:yucai_client/assistant/domain/write_action.dart';
import 'package:yucai_client/assistant/domain/write_executor.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

@LazySingleton(as: WriteExecutor)
class WriteExecutorImpl implements WriteExecutor {
  WriteExecutorImpl(this._txns, this._loop, this._audit);

  final TransactionRepository _txns;
  final AgentLoopService _loop;
  final AssistantAuditLog _audit;

  /// 幂等集(ADR-3;会话内单例态):确认实例 uuid → 落库实体 id。
  /// 仅成功路径记录 —— 失败不耗键,重试(同 key)从零再执行。
  final Map<String, String> _executedKeys = {};

  @override
  Future<WriteOutcome> execute(WriteAction action, String idempotencyKey) async {
    // 幂等短路:已执行键直接回放首次结果,不再写/不再审计/不再注入。
    final executed = _executedKeys[idempotencyKey];
    if (executed != null) return AlreadyExecuted(executed);
    final tool = _toolNameOf(action);
    try {
      final (outcome, note) = await _run(action);
      if (outcome is WriteFailed) {
        _audit.logWrite(
          tool: tool,
          payloadSummary: action.toString(),
          entityId: '',
          ok: false,
        );
        return outcome;
      }
      final entityId = (outcome as WriteExecuted).entityId;
      _executedKeys[idempotencyKey] = entityId;
      _audit.logWrite(
        tool: tool,
        payloadSummary: action.toString(),
        entityId: entityId,
        ok: true,
      );
      _loop.appendToolOutcome(note!);
      return outcome;
    } catch (e) {
      // 防御兜底:repo 抛异常(非 Either Left 路径)→ 只携类名零 payload。
      _audit.logWrite(
        tool: tool,
        payloadSummary: action.toString(),
        entityId: '',
        ok: false,
      );
      return WriteFailed(e.runtimeType.toString());
    }
  }

  /// 三路分发。成功 = (WriteExecuted, 中文 note);失败 = (WriteFailed, null)。
  Future<(WriteOutcome, String?)> _run(WriteAction action) async =>
      switch (action) {
        TransactionAdd a => _add(a),
        TransactionUpdate a => _update(a),
        TransactionDelete a => _delete(a),
      };

  // —— Add:表单记账同管道(recordExpense/recordIncome 方向分流)——

  Future<(WriteOutcome, String?)> _add(TransactionAdd a) async {
    final kind = a.direction == WriteDirection.outflow ? '支出' : '收入';
    final note =
        _flat('已记:$kind ¥${_yuan(a.amountCents)} ${a.description}');
    final result = a.direction == WriteDirection.outflow
        ? await _txns.recordExpense(RecordExpenseParams(
            transactionDate: a.date,
            expenseAccountId: a.categoryId,
            assetAccountId: a.accountId,
            amountCents: a.amountCents,
            description: a.description,
          ))
        : await _txns.recordIncome(RecordIncomeParams(
            transactionDate: a.date,
            assetAccountId: a.accountId,
            incomeAccountId: a.categoryId,
            amountCents: a.amountCents,
            description: a.description,
          ));
    return result.fold(
      (failure) => (WriteFailed(failure.runtimeType.toString()), null),
      (txn) => (WriteExecuted(txn.id), note),
    );
  }

  // —— Update:现读 version → patch 合并 → 全分录重建(表单编辑镜像)——

  Future<(WriteOutcome, String?)> _update(TransactionUpdate a) async {
    final got = await _txns.getById(a.transactionId);
    final Transaction? txn = got.fold((l) => null, (r) => r);
    if (txn == null) {
      // 提案与确认之间实体消失(手删/竞态)→ 失败卡 + 重试(不耗键)。
      return (const WriteFailed('transactionNotFound'), null);
    }

    // 结构守卫:v1 只重建支出/收入两条单边分录(复杂多分录不静默降权 ——
    // 重建会丢分录,fail-closed)。
    final debits =
        txn.entries.where((e) => e.debitCents > 0 && e.creditCents == 0);
    final credits =
        txn.entries.where((e) => e.creditCents > 0 && e.debitCents == 0);
    if (txn.entries.length != 2 ||
        debits.length != 1 ||
        credits.length != 1) {
      return (const WriteFailed('unsupportedEntryLayout'), null);
    }
    final debitEntry = debits.single;
    final creditEntry = credits.single;

    // 借贷侧 ⇄ 科目/资产侧(表单 _buildEntries 的 _type switch 同构):
    // expense=[科目 debit, 资产 credit];income=[资产 debit, 科目 credit]。
    final outflow = a.direction == WriteDirection.outflow;
    final currentCategoryId =
        (outflow ? debitEntry : creditEntry).accountId;
    final currentAccountId = (outflow ? creditEntry : debitEntry).accountId;

    // patch 合并(未改字段取现读 —— 非增量回放,「update 非增量」T1 钉定)。
    final amountCents = a.patch.amountCents ?? txn.totalDebitCents;
    final categoryId = a.patch.categoryId ?? currentCategoryId;
    final accountId = a.patch.accountId ?? currentAccountId;
    final description = a.patch.description ?? txn.description;
    final date = a.patch.date ?? txn.transactionDate;

    // 全分录重建(id 空 = 新 id,表单同款;note 逐侧保留 —— 全替换语义下
    // 不随包携带会把原 note 冲掉,transaction_form._buildEntries 注释钉定)。
    final (debitAccountId, creditAccountId) =
        outflow ? (categoryId, accountId) : (accountId, categoryId);
    final entries = [
      TransactionEntry(
        accountId: debitAccountId,
        debitCents: amountCents,
        creditCents: 0,
        note: debitEntry.note,
      ),
      TransactionEntry(
        accountId: creditAccountId,
        debitCents: 0,
        creditCents: amountCents,
        note: creditEntry.note,
      ),
    ];

    final result = await _txns.update(UpdateTransactionParams(
      id: a.transactionId,
      version: txn.version, // 现读 optimistic version(确认时最新)
      transactionDate: date,
      description: description, // 全替换语义:未改字段也须随包(表单同款)
      entries: entries,
    ));
    return result.fold(
      // ServerFailure = 远端 failedPrecondition(本地版本闸同款)→ 版本
      // 冲突单行 reason(brief 钉定);其余失败只携 runtimeType 零 payload。
      (failure) => (
        failure is ServerFailure
            ? const WriteFailed('versionConflict')
            : WriteFailed(failure.runtimeType.toString()),
        null,
      ),
      (updated) => (
        WriteExecuted(updated.id),
        _flat('已改:$description ¥${_yuan(amountCents)}'),
      ),
    );
  }

  // —— Delete:现读存在性 + note 素材 → 同管道删除 ——

  Future<(WriteOutcome, String?)> _delete(TransactionDelete a) async {
    final got = await _txns.getById(a.transactionId);
    final Transaction? txn = got.fold((l) => null, (r) => r);
    if (txn == null) {
      return (const WriteFailed('transactionNotFound'), null);
    }
    final result = await _txns.delete(a.transactionId);
    return result.fold(
      (failure) => (WriteFailed(failure.runtimeType.toString()), null),
      (_) => (
        WriteExecuted(a.transactionId),
        _flat('已删:${txn.description} ¥${_yuan(txn.totalDebitCents)}'),
      ),
    );
  }

  static String _toolNameOf(WriteAction action) => switch (action) {
        TransactionAdd() => 'transaction_add',
        TransactionUpdate() => 'transaction_update',
        TransactionDelete() => 'transaction_delete',
      };

  /// cents → 元字符串(两位小数 + 千分位,负数带 -)。复用工具侧同源
  /// `yuan()`(= core `DueReminderPolicy.formatYuan`;tool_args 先例)——
  /// note 与 bloc 确认消息(preview.amountYuan 同源)在 ≥¥1000 千分位
  /// 逐字一致(评审 T2-M1:消除 toStringAsFixed 无千分位分叉)。
  static String _yuan(int cents) => yuan(cents);

  /// 自由文本压平空白 + 首尾去空 —— appendToolOutcome 契约「单行紧凑」
  /// (上下文膨胀防线;口述描述可能含换行)。
  static String _flat(String line) =>
      line.replaceAll(RegExp(r'\s+'), ' ').trim();
}
