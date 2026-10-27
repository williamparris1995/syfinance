/// F70-T3 写操作确认卡 + 引导卡(浮层内嵌,v20 六形态)。
///
/// 视觉事实源 = prototype v20 ui/write-approval-cards.html 全页(用户拍板
/// 2026-10-27):
/// - V1 新增预览:卡头「待确认操作+记一笔 chip」/ 参数逐行(方向/金额
///   千分位两位/账户/分类+推导注记/日期=今天)|ISO)/「取消+确认记账」;
///   confirmed 形态收窄为 金额/账户/分类 + `.ap-done` 落库条。
/// - V2 前后对比:目标交易行 + 变更字段 diff(旧值删除线 muted → 新值
///   高亮 accent w800),未变更字段只读列出(改动一眼可辨)。
/// - V3 destructive:`.ap-strip` 红警示条「删除后不可恢复」+ 按钮主位
///   反转(确认删除 negative 在前,取消升主视觉 —— 误删需刻意越过一级)。
/// - V4 查无引导([GuidanceCard]):「需要补充信息+待补充 chip」+ 澄清
///   文本 + 参数行(金额/账户「未找到该账户」,评审 T3-M2)+ 「新建账户」
///   (跳 [GuidanceMsg.route],无独立新建路由 → 账户页)+ 「换个账户试试」
///   (仅关闭卡)。
/// - V5 替换/作废:灰化留档(opacity .55)+ 状态 chip(已被新操作替换/
///   已作废/已取消),按钮区收起(pending 才有按钮区)。
/// - V6 失败:头转 negative「记账失败」+ 执行失败 chip + 原因直说
///   ([failureReasonText] 中文化:契约英文 token 不裸出,评审 T3-M1)+
///   重试钮(幂等键复用)+ 幂等小字「重试不会产生重复记录…」。
///
/// 零裸色:全部走 `context.yucai` 令牌(destructive 走 negative 令牌,
/// ErrorMsg 同族先例);按钮为标准 Material 按钮 —— 浮层内键盘可聚焦。
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/assistant/domain/write_action.dart';
import 'package:yucai_client/assistant/presentation/assistant_panel/assistant_panel_bloc.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// 卡宽占比(v20 `.ap` width:88%)。
const _kCardWidthFactor = 0.88;

/// 灰化留档透明度(v20 `.ap.void` opacity:.55)。
const _kVoidOpacity = 0.55;

/// F70 写确认卡(PanelMessage [WriteApprovalMsg] 的浮层渲染面)。
///
/// 按钮回调 = 真调 bloc 事件([ConfirmWriteRequested]/
/// [CancelWriteRequested]/[RetryWriteRequested],携卡幂等键);bloc 侧
/// 状态守卫保证唯一写通道。pending 才有按钮区,终态(confirmed/
/// cancelled/superseded/voided)收起;failed 由失败盒重试。
class WriteApprovalCard extends StatelessWidget {
  const WriteApprovalCard({super.key, required this.card});

  final WriteApprovalMsg card;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    final status = card.status;
    final rows = _rows(context);
    // 末行分隔线:后随无边框段(failed 失败盒)时保留(v20 V6),否则收
    //(后随自带上边框的按钮/done 条,避免双线;行即卡尾亦收)。
    final lastRowHasBorder =
        rows.isNotEmpty && status == WriteApprovalStatus.failed;
    final body = <Widget>[
      for (var i = 0; i < rows.length; i++)
        i == rows.length - 1 && !lastRowHasBorder
            ? rows[i]
            : _withRowDivider(context, rows[i]),
      if (status == WriteApprovalStatus.failed) ...[
        _FailureBox(card: card),
        const _RetryNoteLine(),
      ],
      if (status == WriteApprovalStatus.confirmed) _DoneStrip(card: card),
      if (status == WriteApprovalStatus.pending) _ApprovalButtons(card: card),
    ];
    final isVoid = status == WriteApprovalStatus.cancelled ||
        status == WriteApprovalStatus.superseded ||
        status == WriteApprovalStatus.voided;
    Widget result = Container(
      key: const ValueKey('writeApprovalCard'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(13), // v20 .ap radius:13
        border: Border.all(color: t.border),
        boxShadow: [
          BoxShadow(
            color: t.fg.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // V3 红警示条(destructive 提案恒显,含终态留档)。
          if (card.preview['destructive'] == true)
            _DestructiveStrip(card: card),
          _ApprovalHead(card: card),
          ...body,
        ],
      ),
    );
    if (isVoid) {
      result = Opacity(opacity: _kVoidOpacity, child: result);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: _kCardWidthFactor,
        child: result,
      ),
    );
  }

  /// 行参数面(三形态逐行;[WriteAction] 分型穷尽)。
  List<Widget> _rows(BuildContext context) => switch (card.action) {
        TransactionAdd() => _addRows(context),
        TransactionUpdate() => _updateRows(context),
        TransactionDelete() => _deleteRows(context),
      };

  // —— V1 新增预览行 ——

  List<Widget> _addRows(BuildContext context) {
    final action = card.action as TransactionAdd;
    final preview = card.preview;
    final confirmed = card.status == WriteApprovalStatus.confirmed;
    if (confirmed) {
      // v20 V1 确认后小样:收窄为 金额/账户/分类(方向/日期退场,无注记)。
      return [
        _approvalRow(context, '金额', _value(context, '¥${preview['amountYuan']}')),
        _approvalRow(context, '账户', _value(context, '${preview['account']}')),
        _approvalRow(context, '分类', _value(context, '${preview['category']}')),
      ];
    }
    return [
      _approvalRow(context, '方向',
          _value(context, action.direction == WriteDirection.outflow ? '支出' : '收入')),
      _approvalRow(context, '金额', _value(context, '¥${preview['amountYuan']}')),
      _approvalRow(context, '账户', _value(context, '${preview['account']}')),
      // 推导注记:数据面无 derived 标记(工具由 LLM 按描述推导分类),
      // 恒显「由描述推导」(v20 V1 形态;差异见 T3 汇报差异表)。
      _approvalRow(
        context,
        '分类',
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            _value(context, '${preview['category']}'),
            Text('由描述推导',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: context.yucai.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      _approvalRow(context, '日期', _value(context, _dayLabel(_iso(action.date)))),
    ];
  }

  // —— V2 前后对比行 ——

  List<Widget> _updateRows(BuildContext context) {
    final action = card.action as TransactionUpdate;
    final before = _section('before');
    final after = _section('after');
    final patch = action.patch;
    final rows = <Widget>[
      _approvalRow(context, '目标交易',
          _value(context, '${before['description']} · ${_dayLabel('${before['date']}')}')),
      if (patch.description != null)
        _approvalRow(
            context,
            '描述',
            _diffValue(context, '${before['description']}',
                '${after['description']}')),
      _approvalRow(
        context,
        '金额',
        patch.amountCents != null
            ? _diffValue(
                context, '¥${before['amountYuan']}', '¥${after['amountYuan']}')
            : _value(context, '¥${after['amountYuan']}'),
      ),
      _approvalRow(
        context,
        '账户',
        patch.accountId != null
            ? _diffValue(context, '${before['account']}', '${after['account']}')
            : _value(context, '${after['account']}'),
      ),
      _approvalRow(
        context,
        '分类',
        patch.categoryId != null
            ? _diffValue(
                context, '${before['category']}', '${after['category']}')
            : _value(context, '${after['category']}'),
      ),
      // 未变更日期不出行(v20 V2:仅列 金额/账户/分类 上下文)。
      if (patch.date != null)
        _approvalRow(context, '日期',
            _diffValue(context, _dayLabel('${before['date']}'), _dayLabel('${after['date']}'))),
    ];
    return rows;
  }

  // —— V3 删除摘要行 ——

  List<Widget> _deleteRows(BuildContext context) {
    final target = _section('target');
    return [
      _approvalRow(context, '交易',
          _value(context, '${target['description']} · ${_dayLabel('${target['date']}')}')),
      _approvalRow(context, '分类', _value(context, '${target['category']}')),
      _approvalRow(context, '账户', _value(context, '${target['account']}')),
      _approvalRow(context, '金额', _value(context, '¥${target['amountYuan']}')),
    ];
  }

  Map<String, Object> _section(String key) {
    final value = card.preview[key];
    return value is Map ? Map<String, Object>.from(value) : const {};
  }
}

// —— 行与值(v20 .ap-row / .ap-old / .ap-new)——

/// 参数行:label muted 左,value 右(基线感用 start 对齐 + 右靠)。
Widget _approvalRow(BuildContext context, String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: context.yucai.muted, fontSize: 12.5)),
          const Spacer(),
          Flexible(child: value),
        ],
      ),
    );

/// 行分隔线容器(v20 `.ap-row` border-bottom)。
Widget _withRowDivider(BuildContext context, Widget row) => Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.yucai.border)),
      ),
      child: row,
    );

/// 只读单值(v20 `.ap-v`:fg w600 右对齐)。
Widget _value(BuildContext context, String text) => Text(
      text,
      textAlign: TextAlign.right,
      style: TextStyle(color: context.yucai.fg, fontSize: 12.5, fontWeight: FontWeight.w600),
    );

/// 前后对比值(v20 `.ap-old` 删除线 muted → `.ap-arrow` → `.ap-new` 高亮)。
Widget _diffValue(BuildContext context, String oldText, String newText) {
  final t = context.yucai;
  return Align(
    alignment: Alignment.centerRight,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            oldText,
            textAlign: TextAlign.right,
            style: TextStyle(
                color: t.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.lineThrough),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('→',
              style: TextStyle(color: t.muted, fontSize: 12.5, fontWeight: FontWeight.w400)),
        ),
        Flexible(
          child: Text(
            newText,
            textAlign: TextAlign.right,
            style: TextStyle(
                color: t.accent, fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

// —— 卡头(v20 .ap-head:状态徽标所在)——

class _ApprovalHead extends StatelessWidget {
  const _ApprovalHead({required this.card});

  final WriteApprovalMsg card;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    final status = card.status;
    final isDelete = card.action is TransactionDelete;
    final (icon, label, color) = switch (status) {
      WriteApprovalStatus.pending => (
          isDelete ? LucideIcons.x : LucideIcons.pencilLine,
          '待确认操作',
          t.muted,
        ),
      WriteApprovalStatus.confirmed => (
          LucideIcons.circleCheck,
          switch (card.action) {
            TransactionAdd() => '已记账',
            TransactionUpdate() => '已修改',
            TransactionDelete() => '已删除',
          },
          t.positive, // v20 .ap-head.ok
        ),
      WriteApprovalStatus.cancelled ||
      WriteApprovalStatus.superseded ||
      WriteApprovalStatus.voided =>
        (LucideIcons.pencilLine, '待确认操作', t.muted),
      WriteApprovalStatus.failed => (
          LucideIcons.triangleAlert,
          switch (card.action) {
            TransactionAdd() => '记账失败',
            TransactionUpdate() => '修改失败',
            TransactionDelete() => '删除失败',
          },
          t.negative, // v20 .ap-head.fail
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.surfaceAlt, // v20 .ap-head ic-bg
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const Spacer(),
          _HeadChip(card: card),
        ],
      ),
    );
  }
}

/// 卡头状态徽标 chip(pending=工具语境;终态=状态词;v20 各形态)。
class _HeadChip extends StatelessWidget {
  const _HeadChip({required this.card});

  final WriteApprovalMsg card;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    final (text, fg) = switch (card.status) {
      WriteApprovalStatus.pending => (
          switch (card.action) {
            TransactionAdd() => '记一笔',
            TransactionUpdate() => '改一笔',
            TransactionDelete() => '删一笔',
          },
          t.muted,
        ),
      WriteApprovalStatus.confirmed => ('已完成', t.positive),
      WriteApprovalStatus.cancelled => ('已取消', t.muted),
      WriteApprovalStatus.superseded => ('已被新操作替换', t.muted),
      WriteApprovalStatus.voided => ('已作废', t.muted),
      WriteApprovalStatus.failed => ('执行失败', t.negative),
    };
    return Container(
      key: const ValueKey('writeApprovalChip'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(
              color: fg, fontSize: 10.5, fontWeight: FontWeight.w600)),
    );
  }
}

// —— V3 红警示条 ——

class _DestructiveStrip extends StatelessWidget {
  const _DestructiveStrip({required this.card});

  final WriteApprovalMsg card;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return Container(
      key: const ValueKey('writeApprovalDestructiveStrip'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.negative.withValues(alpha: 0.12), // v20 --neg-soft 同族
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.triangleAlert, size: 13, color: t.negative),
          const SizedBox(width: 8),
          Text('删除后不可恢复',
              style: TextStyle(
                  color: t.negative,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// —— 按钮区(v20 .ap-btns;pending 专属)——

class _ApprovalButtons extends StatelessWidget {
  const _ApprovalButtons({required this.card});

  final WriteApprovalMsg card;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    final isDelete = card.action is TransactionDelete;
    final confirmLabel = switch (card.action) {
      TransactionAdd() => '确认记账',
      TransactionUpdate() => '确认修改',
      TransactionDelete() => '确认删除',
    };
    Widget confirm = isDelete
        ? FilledButton(
            key: const ValueKey('writeApprovalConfirm'),
            onPressed: () => _confirm(context),
            style: FilledButton.styleFrom(
              backgroundColor: t.negative.withValues(alpha: 0.12),
              foregroundColor: t.negative,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('确认删除'),
          )
        : FilledButton(
            key: const ValueKey('writeApprovalConfirm'),
            onPressed: () => _confirm(context),
            style: FilledButton.styleFrom(
              backgroundColor: t.accent,
              foregroundColor: t.onAccent,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(confirmLabel),
          );
    Widget cancel = isDelete
        // V3 主位反转:取消升主视觉(btn-primary)。
        ? FilledButton(
            key: const ValueKey('writeApprovalCancel'),
            onPressed: () => _cancel(context),
            style: FilledButton.styleFrom(
              backgroundColor: t.accent,
              foregroundColor: t.onAccent,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('取消'),
          )
        : OutlinedButton(
            key: const ValueKey('writeApprovalCancel'),
            onPressed: () => _cancel(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: t.fg,
              side: BorderSide(color: t.border),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('取消'),
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.surfaceAlt, // v20 .ap-btns chip-bg
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          // V3:确认删除在前(危险);V1/V2:取消在前(默认安全)。
          if (isDelete) ...[confirm, const SizedBox(width: 8), cancel]
          else ...[cancel, const SizedBox(width: 8), confirm],
        ],
      ),
    );
  }

  void _confirm(BuildContext context) =>
      context.read<AssistantPanelBloc>().add(
            ConfirmWriteRequested(card.idempotencyKey),
          );

  void _cancel(BuildContext context) =>
      context.read<AssistantPanelBloc>().add(
            CancelWriteRequested(card.idempotencyKey),
          );
}

// —— V6 失败盒 + 幂等小字 ——

/// V6 失败原因中文化(executor 契约 [WriteApprovalMsg.failureReason] 为
/// 英文单行 token,评审 T3-M1:UI 不裸出英文)。映射:已知 token → 定制
/// 中文文案;其余(runtimeType 类名/任意未知 token)→ 通用重试文案。
/// executor/审计/LLM 注入侧英文契约不动 —— 本层仅渲染面转译。
String failureReasonText(String? reason) => switch (reason) {
      'versionConflict' => '内容已被其他修改更新,请重试',
      'transactionNotFound' => '这笔交易已不存在',
      _ => '执行失败,请重试',
    };

class _FailureBox extends StatelessWidget {
  const _FailureBox({required this.card});

  final WriteApprovalMsg card;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return Container(
      key: const ValueKey('writeApprovalFailure'),
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: t.negative.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9), // v20 .ap .cp-error radius:9
      ),
      child: Row(
        children: [
          Icon(LucideIcons.triangleAlert, size: 15, color: t.negative),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              failureReasonText(card.failureReason),
              style: TextStyle(
                  color: t.negative,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          TextButton.icon(
            key: const ValueKey('writeApprovalRetry'),
            onPressed: () => context.read<AssistantPanelBloc>().add(
                  RetryWriteRequested(card.idempotencyKey),
                ),
            icon: Icon(LucideIcons.rotateCcw, size: 13, color: t.negative),
            label: Text('重试',
                style: TextStyle(
                    color: t.negative,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class _RetryNoteLine extends StatelessWidget {
  const _RetryNoteLine();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('writeApprovalRetryNote'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Text(
        '重试不会产生重复记录;也可以改用其他账户重新记账。',
        style: TextStyle(color: context.yucai.muted, fontSize: 11),
      ),
    );
  }
}

// —— V1 确认后落库条(v20 .ap-done)——

class _DoneStrip extends StatelessWidget {
  const _DoneStrip({required this.card});

  final WriteApprovalMsg card;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    Map<String, Object> section(String key) {
      final value = card.preview[key];
      return value is Map ? Map<String, Object>.from(value) : const {};
    }

    // 与 bloc 本地确认消息(_confirmLine)同词汇同序:已记入/已改/已删。
    final after = section('after');
    final target = section('target');
    final line = switch (card.action) {
      TransactionAdd() => '已记入${card.preview['account']}',
      TransactionUpdate() => '已改:${after['description']} ¥${after['amountYuan']}',
      TransactionDelete() => '已删:${target['description']} ¥${target['amountYuan']}',
    };
    return Container(
      key: const ValueKey('writeApprovalDoneStrip'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: t.positive.withValues(alpha: 0.12), // v20 --pos-soft 同族
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.circleCheck, size: 13, color: t.positive),
          const SizedBox(width: 8),
          Expanded(
            child: Text(line,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: t.positive,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// —— V4 引导卡(v20 查无实体引导态)——

/// 查无实体引导卡([GuidanceMsg] 的浮层渲染面):澄清文本 + 参数行
/// (金额 [amountYuan] / 账户 [accountName]「未找到该账户」neg 注记,
/// v20 V4 两行照排,评审 T3-M2 —— 请求金额先挂起不丢失)+「新建账户」
/// (跳 [GuidanceMsg.route] —— ADR-5 既有路由,无独立新建路由 → 账户页)
/// + 「换个账户试试」(仅关闭卡 = [DismissGuidanceClicked])。LLM 文本
/// 澄清(ToolError 回填自纠)照常并存 —— 两通道独立。
class GuidanceCard extends StatelessWidget {
  const GuidanceCard({
    super.key,
    required this.text,
    required this.route,
    this.amountYuan,
    this.accountName,
  });

  /// 澄清文案(如「没有找到『滴滴』这个账户,要新建吗?」)。
  final String text;

  /// 主钮跳转目标(如 `/accounts`)。
  final String route;

  /// 请求金额元串(V4「金额 ¥12.00」行;null/空不出行)。
  final String? amountYuan;

  /// 零命中实体名(V4「账户 滴滴(未找到)」行;null/空不出行)。
  final String? accountName;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    // V4 参数行(v20 .ap-row:金额 + 账户;末行随按钮区上边框收分隔线,
    // 避免双线 —— 主卡 lastRowHasBorder 同口径)。
    final rows = <Widget>[
      if (amountYuan != null && amountYuan!.trim().isNotEmpty)
        _approvalRow(context, '金额', _value(context, '¥$amountYuan')),
      if (accountName != null && accountName!.trim().isNotEmpty)
        _approvalRow(
          context,
          '账户',
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _value(context, accountName!),
              Text('未找到该账户',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: t.negative,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
    ];
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: _kCardWidthFactor,
        child: Container(
          key: const ValueKey('guidanceCard'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: t.border),
            boxShadow: [
              BoxShadow(
                color: t.fg.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: t.surfaceAlt,
                  border: Border(bottom: BorderSide(color: t.border)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.messageSquare,
                        size: 13, color: t.muted),
                    const SizedBox(width: 7),
                    Text('需要补充信息',
                        style: TextStyle(
                            color: t.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: t.warn.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('待补充',
                          style: TextStyle(
                              color: t.warn,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Text(text,
                    style: TextStyle(
                        color: t.fg,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ),
              for (var i = 0; i < rows.length; i++)
                i == rows.length - 1
                    ? rows[i]
                    : _withRowDivider(context, rows[i]),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: t.surfaceAlt,
                  border: Border(top: BorderSide(color: t.border)),
                ),
                child: Row(
                  children: [
                    OutlinedButton(
                      key: const ValueKey('guidanceDismissButton'),
                      onPressed: () => context
                          .read<AssistantPanelBloc>()
                          .add(const DismissGuidanceClicked()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.fg,
                        side: BorderSide(color: t.border),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('换个账户试试'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      key: const ValueKey('guidanceNewAccountButton'),
                      onPressed: () =>
                          GoRouter.maybeOf(context)?.go(route),
                      icon: const Icon(LucideIcons.chevronRight, size: 13),
                      label: const Text('新建账户'),
                      style: FilledButton.styleFrom(
                        backgroundColor: t.accent,
                        foregroundColor: t.onAccent,
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Text(
                  '也可以直接说用哪个现有账户,如「用支付宝记」。',
                  style: TextStyle(color: t.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// —— 日期口径 ——

/// 本地时区 yyyy-MM-dd(与工具/表单 ISO 参数同格式)。
String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 今天 → 「今天」,其余 ISO 原文(v20 V1 日期行口径)。
String _dayLabel(String iso) {
  final day = DateTime.tryParse(iso);
  if (day == null) return iso;
  final now = DateTime.now();
  final isToday = day.year == now.year &&
      day.month == now.month &&
      day.day == now.day;
  return isToday ? '今天' : iso;
}
