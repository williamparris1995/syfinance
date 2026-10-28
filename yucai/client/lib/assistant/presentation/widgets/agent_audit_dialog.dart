/// F71 T2「AI 助手 · 操作记录」只读审计对话框(spec FR-3,design ADR-3/ADR-4;
/// 视觉事实源 = prototype v21 ui/agent-audit-dialog.html 第二/三段:标题 +
/// 副行总数·确认后缀 / 列表行(相对时间 · 工具 chip · 摘要 · 徽标)/
/// 「加载更多」+ 已显示计数 / 空态两行)。
///
/// 数据面 = T1 [AgentAuditDao](watchPage/count,20/页):首页 offset 0,
/// 「加载更多」逐页递增 offset 追加订阅 —— 每页独立 watch,表变更各自重发。
/// **分页语义如实记(评审修复 T2-M2)**:各页是按查询时刻取数的 offset
/// 滑窗,两页取数间隙表变更时,窗口边界行理论上可瞬时重复(或漏一拍后由
/// watch 重发收敛);对话框为低频只读 modal —— 用户开着对话框的同时确认
/// 写操作的场景本身罕见,瞬时重复自愈且无害,不为此引入跨页去重/合并
/// 复杂度(v21 原型同款取舍)。
/// 摘要 = T1 入库 summary(**评审修复后 = executor 人话 note 单源**,
/// appendToolOutcome 同串「已记:支出 ¥35.00 午饭」/「已改:」「已删:」族)
/// **渲染原样**,金额千分位含在串内,零二次格式化;现读素材缺失的失败行
/// (notFound/异常兜底)为 ASCII 机器串,亦如实原样。
///
/// 同键注记(评审修复 T2-M1,v21 aud-note 语义):仅 failed 行与**同键**
/// ok 行(重试对)行尾显示「键 ****XXXX」muted 小注(幂等键尾 4 位)——
/// 重试对可辨识;普通 ok 行零注记零噪音。
///
/// 相对时间(v21「今天 14:32 / 昨天 09:15 / 前天 18:26」):**纯日期比较**
/// —— 时刻折本地 DateTime 后只取年月日,再经 `DateTime.utc` 日历日差天数
/// (镜像 debts_list_tool 的当日 0 点对齐口径),零时区/夏令时抖动;演示只到
/// 「前天」,更早补完整日期兜底。只读:无编辑无删除,零写路径。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/agent_audit_dao.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// 审计查看对话框(v21 主形态:头部标题+关闭 / 列表 / foot 加载更多+计数;
/// 空态同壳居中两行,不出现 foot)。
class AgentAuditDialog extends StatefulWidget {
  const AgentAuditDialog({
    super.key,
    required this.dao,
    this.pageSize = 20,
    this.now,
  });

  /// 审计 DAO 读面(watchPage/count;T1 已备,本票零写路径)。
  final AgentAuditDao dao;

  /// 页大小(design ADR-3 钉 20;测试可注入小页钉分页行为)。
  final int pageSize;

  /// 相对时间判定的「现在」(测试注入钉定;缺省当前时刻)。
  final DateTime? now;

  /// createdMillis → 「今天 14:32」式相对时间:今天/昨天/前天三档
  /// (v21 演示范围),更早 `yyyy-MM-dd HH:mm` 完整日期兜底。纯日期比较
  /// = 两边各折 `DateTime.utc` 日历日再差天数(0/1/2),时刻不参与档位
  /// 判定 —— 无时区运算、无夏令时抖动。
  static String formatRelativeTime(int createdMillis, DateTime now) {
    final local = DateTime.fromMillisecondsSinceEpoch(createdMillis);
    final days = DateTime.utc(now.year, now.month, now.day)
        .difference(DateTime.utc(local.year, local.month, local.day))
        .inDays;
    final hm = '${_two(local.hour)}:${_two(local.minute)}';
    return switch (days) {
      0 => '今天 $hm',
      1 => '昨天 $hm',
      2 => '前天 $hm',
      _ =>
        '${local.year}-${_two(local.month)}-${_two(local.day)} $hm',
    };
  }

  /// 工具名 → v21 chip 三档(记一笔/改一笔/删一笔);未知工具名原样兜底
  /// (前瞻列不误标)。
  static String toolLabel(String tool) => switch (tool) {
        'transaction_add' => '记一笔',
        'transaction_update' => '改一笔',
        'transaction_delete' => '删一笔',
        _ => tool,
      };

  /// 同键注记文案(评审修复 T2-M1):「键 ****」+ 幂等键尾 4 位 —— v21
  /// aud-note 语义的掩码形态(生产键 = 确认卡 uuid,尾 4 位已足够重试对
  /// 肉眼配对,全键过长不进 UI)。键不足 4 位 → 全掩码(键本身短,尾段
  /// 无辨识意义)。纯函数,widget 测直测。
  static String keyNote(String idempotencyKey) => '键 ****'
      '${idempotencyKey.length <= 4 ? '' : idempotencyKey.substring(idempotencyKey.length - 4)}';

  static String _two(int value) => value.toString().padLeft(2, '0');

  @override
  State<AgentAuditDialog> createState() => _AgentAuditDialogState();
}

class _AgentAuditDialogState extends State<AgentAuditDialog> {
  /// 已订阅页的行缓存(page 0 = 最新一页;按序 concat 即展示序列)。
  final List<List<db.AgentAudit>> _pages = [];

  final List<StreamSubscription<List<db.AgentAudit>>> _subs = [];

  /// 首页首达(空态判定用:首页未达前不闪空态)。
  bool _firstPageLoaded = false;

  /// 总条数(每次页重发后经 count() 刷新 —— 对话框开着时新留痕跟涨)。
  int _total = 0;

  /// 「加载更多」在途守卫:新页首达前按钮禁用,防连点重复订阅。
  bool _pageInflight = false;

  @override
  void initState() {
    super.initState();
    _subscribePage(0);
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  /// 订阅一页(offset = pageIndex × pageSize;watch 表变更自动重发)。
  void _subscribePage(int pageIndex) {
    while (_pages.length <= pageIndex) {
      _pages.add(const []);
    }
    _subs.add(widget.dao
        .watchPage(limit: widget.pageSize, offset: pageIndex * widget.pageSize)
        .listen((rows) {
      if (!mounted) return;
      setState(() {
        _pages[pageIndex] = rows;
        _firstPageLoaded = true;
        if (pageIndex == _pages.length - 1) _pageInflight = false;
      });
      _refreshCount();
    }));
  }

  Future<void> _refreshCount() async {
    final total = await widget.dao.count();
    if (!mounted) return;
    setState(() => _total = total);
  }

  void _loadMore() {
    if (_pageInflight) return;
    setState(() {
      _pageInflight = true;
      _subscribePage(_pages.length);
    });
  }

  List<db.AgentAudit> get _rows => [for (final page in _pages) ...page];

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    final rows = _rows;
    // 同键注记判定集(T2-M1):当前展示序列中的 failed 行键集合 —— ok 行
    // 仅当其键在集合内(= 同键重试对)才显示注记。注:判定基于已加载页,
    // 未加载页的失败键对同键 ok 行不可见 —— 重试对时间上紧邻(同键两行
    // 由同一次确认流产生),跨页拆开且后页未载的场景属极端分页边界,注记
    // 缺失不误导(仅少一条辅助信息)。
    final failedKeys =
        rows.where((r) => !r.ok).map((r) => r.idempotencyKey).toSet();
    final empty = _firstPageLoaded && rows.isEmpty;
    final now = widget.now ?? DateTime.now();
    return AlertDialog(
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI 助手 · 操作记录',
                    style: TextStyle(
                        color: t.fg,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                // 副行:v21 主态带「全部操作均经你确认」后缀,空态只余总数。
                Text(
                    empty || _total == 0
                        ? '共 $_total 条'
                        : '共 $_total 条 · 全部操作均经你确认',
                    style: TextStyle(color: t.muted, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('agentAuditCloseButton'),
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(LucideIcons.x, size: 18, color: t.muted),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: empty
            ? _emptyBody(context)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flexible:对话框总高封顶(视口 - 头部 - foot)时列表
                  // 内部滚动,foot 恒可见;行少时贴内容自然高。
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: t.border),
                      itemBuilder: (context, i) =>
                          _row(context, rows[i], now, failedKeys),
                    ),
                  ),
                  // foot(v21 dlg-foot):加载更多(未全量时)+ 已显示计数。
                  Divider(height: 1, color: t.border),
                  const SizedBox(height: AppSpacing.xs),
                  if (rows.length < _total)
                    TextButton(
                      key: const ValueKey('agentAuditLoadMoreButton'),
                      onPressed: _pageInflight ? null : _loadMore,
                      child: const Text('加载更多'),
                    ),
                  if (rows.length < _total) const SizedBox(height: AppSpacing.xs),
                  Text('已显示 ${rows.length} / $_total 条',
                      style: TextStyle(
                          color: t.muted,
                          fontSize: 11,
                          fontFeatures: AppTypography.tabularFigures)),
                ],
              ),
      ),
    );
  }

  /// 列表行(v21 aud-row 四要素:时间 / 工具 chip / 摘要 / 右列徽标;
  /// 行尾 muted 同键注记 = v21 aud-note 形态,摘要下方挂)。
  Widget _row(
      BuildContext context, db.AgentAudit row, DateTime now, Set<String> failedKeys) {
    final t = context.yucai;
    // 同键注记显隐(T2-M1):仅 failed 行 + 同键 ok 行(重试对)。
    final showKeyNote = !row.ok || failedKeys.contains(row.idempotencyKey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                AgentAuditDialog.formatRelativeTime(row.createdMillis, now),
                style: TextStyle(
                    color: t.muted,
                    fontSize: 11.5,
                    fontFeatures: AppTypography.tabularFigures),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _AuditChip(
              label: AgentAuditDialog.toolLabel(row.tool), color: t.muted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.summary,
                    style: TextStyle(
                        color: t.fg,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.5)),
                // 行尾 muted 小注(v21 aud-note):「键 ****XXXX」—— 失败行
                // 与同键 ok 行(重试对)可辨识配对;普通 ok 行零注记。
                if (showKeyNote) ...[
                  const SizedBox(height: 2),
                  Text(AgentAuditDialog.keyNote(row.idempotencyKey),
                      style: TextStyle(color: t.muted, fontSize: 11)),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // 右列:徽标 ok 绿✓ / failed 红⚠;失败原因小字随徽标下挂
          // (v21 aud-side 形态,如实展示不粉饰)。
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 132),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _AuditChip(
                  label: row.ok ? '✓ 成功' : '⚠ 失败',
                  color: row.ok ? t.positive : t.negative,
                ),
                if (!row.ok && (row.reason?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 4),
                  Text(row.reason!,
                      textAlign: TextAlign.right,
                      style:
                          TextStyle(color: t.negative, fontSize: 11, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 空态(v21 第三段:图标 + 两行文案居中,无 foot)。
  Widget _emptyBody(BuildContext context) {
    final t = context.yucai;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 180),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(LucideIcons.receipt, size: 20, color: t.muted),
          ),
          const SizedBox(height: 10),
          Text('还没有通过助手操作过记账',
              style: TextStyle(
                  color: t.fg, fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('每次助手记账 / 修改 / 删除都会在这里留痕',
              style: TextStyle(color: t.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

/// v21 .chip 形态的小标签:令牌色低透明底 + 同色描边/文字(镜像卡内
/// _StatusChip;本文件私有)。
class _AuditChip extends StatelessWidget {
  const _AuditChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.smBorder,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}
