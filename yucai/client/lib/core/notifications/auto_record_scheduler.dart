/// autoRecord 调度编排(spec FR-1/FR-4;R7-C)。
/// 模板实体(Template)的 nextDate/endDate 是 proto 契约的 date-only String,
/// 调度边界换算为本值类型(适配器解析),日期算术全 DateTime。
library;

import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
import 'package:yucai_client/template/domain/repositories/template_repository.dart';

/// 到期模板的调度视图(适配器从 repo Template 映射)。
class AutoRecordTemplate {
  const AutoRecordTemplate({
    required this.id,
    required this.name,
    required this.amountCents,
    required this.nextDate,
    this.endDate,
  });
  final String id;
  final String name;
  final int amountCents;
  final DateTime nextDate;
  final DateTime? endDate;
}

/// 模板源抽象(适配 template repo:list + record)。
abstract class AutoRecordTemplates {
  Future<List<AutoRecordTemplate>> listAutoRecordDue();
  /// 记一笔并返回推进后的 nextDate(null=失败/未推进,调用方停)。
  Future<DateTime?> record(String templateId);
}

class AutoRecordRunResult {
  const AutoRecordRunResult({
    required this.templates,
    required this.recorded,
    required this.failed,
  });
  final int templates; // autoRecord 开且未暂停的模板数(未到期者循环零笔)
  final int recorded; // 实际生成笔数
  final int failed; // 失败模板数
}

class AutoRecordScheduler {
  AutoRecordScheduler({required this.templates, required this.notifier});

  final AutoRecordTemplates templates;
  final ReminderNotifier notifier;

  /// 防御性上限:custom=1d 模板搁置多年时一次补齐上万笔会卡库;
  /// 个人模板现实频率远达不到,超限即停(游标已推进,次日续)。
  static const int maxCatchupPerTemplate = 1000;

  Future<AutoRecordRunResult> run(DateTime today) async {
    final due = await templates.listAutoRecordDue();
    var recorded = 0;
    var failed = 0;
    for (final t in due) {
      try {
        recorded += await _catchUpOne(t, today);
      } catch (_) {
        failed++; // 单模板失败继续其余(镜像 server 容错,FR-3)
      }
    }
    return AutoRecordRunResult(
        templates: due.length, recorded: recorded, failed: failed);
  }

  /// 一次性补齐:发生日(nextDate)≤ today 且 ≤ endDate 才记,逐周期推进。
  Future<int> _catchUpOne(AutoRecordTemplate t, DateTime today) async {
    final day = DateTime(today.year, today.month, today.day);
    var count = 0;
    var cur = DateTime(t.nextDate.year, t.nextDate.month, t.nextDate.day);
    while (!cur.isAfter(day) &&
        (t.endDate == null || !cur.isAfter(t.endDate!)) &&
        count < maxCatchupPerTemplate) {
      final next = await templates.record(t.id);
      if (next == null ||
          DateTime(next.year, next.month, next.day)
              .isAtSameMomentAs(cur)) {
        break; // 未推进(异常语义)→ 防死循环
      }
      cur = DateTime(next.year, next.month, next.day);
      count++;
    }
    if (count > 0) {
      final copy = count == 1
          ? DueNotificationCopy('御财·${t.name}',
              '已自动记账,应记 ¥${DueReminderPolicy.formatYuan(t.amountCents)}')
          : DueNotificationCopy('御财·${t.name}', '已自动补记 $count 笔');
      await notifier.show(copy);
    }
    return count;
  }
}


/// AutoRecordTemplates 适配器:template 双源 repo(list/record)。
/// Template 实体的 nextDate/endDate 是 date-only String,在此解析为 DateTime。
/// Left 一律抛错(调度器按失败计数——review R1:静默吞 Left 使 failed 恒 0)。
class TemplateRepoAutoRecord implements AutoRecordTemplates {
  TemplateRepoAutoRecord(this._repo);
  final TemplateRepository _repo;

  static DateTime? _parse(String? s) =>
      s == null || s.isEmpty ? null : DateTime.tryParse(s);

  @override
  Future<List<AutoRecordTemplate>> listAutoRecordDue() async {
    final res = await _repo.list();
    return res.fold(
      (l) => throw StateError('auto-record list failed'),
      (all) => [
        for (final t in all)
          if (t.autoRecord && !t.paused)
            AutoRecordTemplate(
              id: t.id,
              name: t.name,
              amountCents: t.amountCents,
              nextDate: _parse(t.nextDate) ?? DateTime.now(),
              endDate: _parse(t.endDate),
            ),
      ],
    );
  }

  @override
  Future<DateTime?> record(String templateId) async {
    final res = await _repo.record(templateId);
    return res.fold(
      (l) => throw StateError('auto-record record failed'),
      (r) => r.nextDate,
    );
  }
}
