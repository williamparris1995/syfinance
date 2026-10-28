/// F71 T2「AI 助手 · 操作记录」只读审计对话框(spec FR-3,design ADR-3/ADR-4;
/// 视觉事实源 = prototype v22 ui/audit-ux-enhanced.html:F71 基础面 +
/// F72 三增强 —— 标题 + 副行双态(全量确认后缀 ↔ 过滤匹配计数+清除链接)/
/// 标题下搜索框(图标+清除钮,300ms 防抖)/ 列表按日历日分组段头
/// (今天/昨天/前天/yyyy年M月d日 + 段内计数)/ 行右键「复制摘要」/
/// 「加载更多」+ 已显示计数 / 空态两行(全量空 + 搜索无匹配两态)。
///
/// 数据面 = T1 [AgentAuditDao](watchPage/count,20/页;F72 起 keyword?):
/// 首页 offset 0,「加载更多」逐页递增 offset 追加订阅 —— 每页独立
/// watch,表变更各自重发。**分页语义如实记(评审修复 T2-M2)**:各页是
/// 按查询时刻取数的 offset 滑窗,两页取数间隙表变更时,窗口边界行理论
/// 上可瞬时重复(或漏一拍后由 watch 重发收敛);对话框为低频只读
/// modal —— 用户开着对话框的同时确认写操作的场景本身罕见,瞬时重复
/// 自愈且无害,不为此引入跨页去重/合并复杂度(v21 原型同款取舍)。
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
/// 「前天」,更早补完整日期兜底。
///
/// F72(design ADR-1/2/5):
/// - **分组=纯渲染**:已加载行(含过滤态)按日历日聚合段头,段头仅由
///   相邻行的 [groupLabel] 变化驱动 —— 跨「加载更多」续组天然成立
///   (同日跨页同 label 不另起段头);DAO 排序(时间倒序)不碰。
/// - **搜索=DAO 层**:输入防抖([searchDebounce] 缝,缺省 300ms)后以
///   keyword 重查(watchPage/count 同参,offset 重置回首页)—— 命中
///   不限于已加载页;清空(清除钮/清除链接)恢复全量。副行/foot 双态
///   计数:全量「共 N 条·全部操作均经你确认 / 已显示 x / N」↔ 过滤
///   「n 条匹配「kw」 · 清除搜索 / n / N 条匹配」。
/// - **复制=右键先例**:行包 design_kit `ContextMenuRegion`(R16 桌面
///   文本票先例,translucent 不进主键竞技场)单项「复制摘要」→
///   `Clipboard.setData`(行 summary 原样)+ `AppToast`「已复制」。
///
/// 只读:无编辑无删除,零写路径。
library;

import 'dart:async';

import 'package:design_kit/design_kit.dart' show ContextMenuRegion, MenuItemData;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/agent_audit_dao.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';

/// 审计查看对话框(v22 主形态:头部标题+副行双态 / 搜索框 / 分组列表 /
/// foot 加载更多+双态计数;空态同壳居中两行(全量空/搜索无匹配),不出现 foot)。
class AgentAuditDialog extends StatefulWidget {
  const AgentAuditDialog({
    super.key,
    required this.dao,
    this.pageSize = 20,
    this.now,
    this.searchDebounce = const Duration(milliseconds: 300),
  });

  /// 审计 DAO 读面(watchPage/count;T1 已备,本票零写路径)。
  final AgentAuditDao dao;

  /// 页大小(design ADR-3 钉 20;测试可注入小页钉分页行为)。
  final int pageSize;

  /// 相对时间判定的「现在」(测试注入钉定;缺省当前时刻)。
  final DateTime? now;

  /// 搜索输入防抖(缺省 300ms;测试可注入 Duration.zero 钉直通)。
  final Duration searchDebounce;

  /// createdMillis → 「今天 14:32」式相对时间:今天/昨天/前天三档
  /// (v21 演示范围),更早 `yyyy-MM-dd HH:mm` 完整日期兜底。纯日期比较
  /// = 两边各折 `DateTime.utc` 日历日再差天数(0/1/2),时刻不参与档位
  /// 判定 —— 无时区运算、无夏令时抖动。
  static String formatRelativeTime(int createdMillis, DateTime now) {
    final local = DateTime.fromMillisecondsSinceEpoch(createdMillis);
    final days = _calendarDaysBefore(local, now);
    final hm = '${_two(local.hour)}:${_two(local.minute)}';
    return switch (days) {
      0 => '今天 $hm',
      1 => '昨天 $hm',
      2 => '前天 $hm',
      _ =>
        '${local.year}-${_two(local.month)}-${_two(local.day)} $hm',
    };
  }

  /// F72 分组段头文案:今天/昨天/前天三档,更早 `yyyy年M月d日` 完整日期
  /// (v22 aud-group 形态;月/日**不补零** —— 原型「2026年10月24日」)。
  /// 与 [formatRelativeTime] 同一纯日期比较口径(相对时间纯函数族扩展)。
  static String groupLabel(int createdMillis, DateTime now) {
    final local = DateTime.fromMillisecondsSinceEpoch(createdMillis);
    final days = _calendarDaysBefore(local, now);
    return switch (days) {
      0 => '今天',
      1 => '昨天',
      2 => '前天',
      _ => '${local.year}年${local.month}月${local.day}日',
    };
  }

  /// 日历日差(local 相对 now 早几天):两边各折 `DateTime.utc` 年月日
  /// 再差天数 —— 时刻不参与,零时区/夏令时抖动。
  static int _calendarDaysBefore(DateTime local, DateTime now) =>
      DateTime.utc(now.year, now.month, now.day)
          .difference(DateTime.utc(local.year, local.month, local.day))
          .inDays;

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

/// 列表条目(分组段头 / 行;分组=纯渲染,构建期聚合)。
class _ListEntry {
  const _ListEntry.header(this.label, this.count)
      : row = null;
  const _ListEntry.row(this.row)
      : label = null,
        count = null;

  /// 段头文案;行条目为 null。
  final String? label;

  /// 段内行数(段头条目);行条目为 null。
  final int? count;

  /// 行数据;段头条目为 null。
  final db.AgentAudit? row;
}

class _AgentAuditDialogState extends State<AgentAuditDialog> {
  /// 已订阅页的行缓存(page 0 = 最新一页;按序 concat 即展示序列)。
  final List<List<db.AgentAudit>> _pages = [];

  final List<StreamSubscription<List<db.AgentAudit>>> _subs = [];

  /// 首页首达(空态判定用:首页未达前不闪空态)。
  bool _firstPageLoaded = false;

  /// 全量总条数(每次页重发后经 count() 刷新 —— 过滤态 foot 分母)。
  int _grand = 0;

  /// 过滤态匹配数(count(keyword));null = 未过滤(全量态)。
  int? _matched;

  /// 已生效(防抖后)搜索词;空串 = 全量。输入框实时文本不等于生效词。
  String _keyword = '';

  /// 输入框是否含文本(清除钮显隐;防抖前即时跟手)。
  bool _hasQuery = false;

  /// 「加载更多」在途守卫:新页首达前按钮禁用,防连点重复订阅。
  bool _pageInflight = false;

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _subscribePage(0);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchCtrl.dispose();
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  /// 当前生效 keyword(DAO 入参形态:空 = null 全量)。
  String? get _keywordArg => _keyword.isEmpty ? null : _keyword;

  /// 订阅一页(offset = pageIndex × pageSize;watch 表变更自动重发;
  /// F72 起带生效 keyword —— 过滤态各页同口径)。
  void _subscribePage(int pageIndex) {
    while (_pages.length <= pageIndex) {
      _pages.add(const []);
    }
    _subs.add(widget.dao
        .watchPage(
            limit: widget.pageSize,
            offset: pageIndex * widget.pageSize,
            keyword: _keywordArg)
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
    final grand = await widget.dao.count();
    final matched =
        _keyword.isEmpty ? null : await widget.dao.count(keyword: _keyword);
    if (!mounted) return;
    setState(() {
      _grand = grand;
      _matched = matched;
    });
  }

  void _loadMore() {
    if (_pageInflight) return;
    setState(() {
      _pageInflight = true;
      _subscribePage(_pages.length);
    });
  }

  /// 搜索输入(防抖):到期后以 trim 词重查;词未变零重查。
  void _onSearchChanged(String text) {
    setState(() => _hasQuery = text.isNotEmpty);
    _searchTimer?.cancel();
    _searchTimer = Timer(widget.searchDebounce, () {
      final kw = text.trim();
      if (kw == _keyword) return;
      _applyKeyword(kw);
    });
  }

  /// 清除搜索(清除钮 / 副行清除链接同效):立即恢复全量(不经防抖)。
  void _clearSearch() {
    _searchTimer?.cancel();
    _searchCtrl.clear();
    setState(() => _hasQuery = false);
    if (_keyword.isNotEmpty) _applyKeyword('');
  }

  /// 生效 keyword 切换:重置分页(offset 归零,只订首页)+ 双计数刷新。
  void _applyKeyword(String keyword) {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    setState(() {
      _keyword = keyword;
      _pages.clear();
      _firstPageLoaded = false;
      _pageInflight = false;
    });
    _subscribePage(0);
    _refreshCount();
  }

  List<db.AgentAudit> get _rows => [for (final page in _pages) ...page];

  /// 分组聚合(纯渲染):行序即 DAO 时间倒序;段头由相邻行 label 变化
  /// 驱动 —— 跨页续组天然成立,段计数 = 该日历日已加载(过滤态=已加载
  /// 匹配)行数。label 单调(日历日只减不增)→ 相邻同 label 聚一段。
  List<_ListEntry> _buildEntries(List<db.AgentAudit> rows, DateTime now) {
    final labels = [
      for (final r in rows) AgentAuditDialog.groupLabel(r.createdMillis, now)
    ];
    final entries = <_ListEntry>[];
    var i = 0;
    while (i < rows.length) {
      final label = labels[i];
      var j = i;
      while (j < rows.length && labels[j] == label) {
        j++;
      }
      entries.add(_ListEntry.header(label, j - i));
      for (var k = i; k < j; k++) {
        entries.add(_ListEntry.row(rows[k]));
      }
      i = j;
    }
    return entries;
  }

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
    final filtering = _keyword.isNotEmpty;
    final empty = _firstPageLoaded && rows.isEmpty;
    final now = widget.now ?? DateTime.now();
    final modeTotal = filtering ? (_matched ?? 0) : _grand;
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
                // 副行双态(v22):全量「共 N 条 · 全部操作均经你确认」(空态
                // 只余总数)↔ 过滤「n 条匹配「kw」 · 清除搜索」(链接色)。
                if (filtering)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text('${_matched ?? 0} 条匹配「$_keyword」',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: t.muted, fontSize: 12)),
                      ),
                      Text(' · ',
                          style: TextStyle(color: t.muted, fontSize: 12)),
                      GestureDetector(
                        key: const ValueKey('agentAuditClearSearchLink'),
                        onTap: _clearSearch,
                        child: Text('清除搜索',
                            style: TextStyle(
                                color: t.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  )
                else
                  Text(
                      empty || _grand == 0
                          ? '共 $_grand 条'
                          : '共 $_grand 条 · 全部操作均经你确认',
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // F72 搜索框(v22 dlg-search:图标 + 输入 + 清除钮;全态恒在
            // —— 空态/无匹配态仍可继续编辑查询)。
            _searchBox(context),
            if (empty)
              (filtering ? _noMatchBody(context) : _emptyBody(context))
            else ...[
              // Flexible:对话框总高封顶(视口 - 头部 - foot)时列表
              // 内部滚动,foot 恒可见;行少时贴内容自然高。
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  itemCount: _entries.length,
                  itemBuilder: (context, i) {
                    final e = _entries[i];
                    if (e.label != null) {
                      return _groupHeader(context, e.label!, e.count!);
                    }
                    final row = e.row!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row(context, row, now, failedKeys),
                        // 行底分隔线(v22 aud-row border-bottom;末条
                        // 不出 —— 紧邻 foot 顶线免双线)。
                        if (i != _entries.length - 1)
                          Divider(height: 1, color: t.border),
                      ],
                    );
                  },
                ),
              ),
              // foot(v22 dlg-foot):加载更多(未全量时)+ 双态计数。
              Divider(height: 1, color: t.border),
              const SizedBox(height: AppSpacing.xs),
              if (rows.length < modeTotal) ...[
                TextButton(
                  key: const ValueKey('agentAuditLoadMoreButton'),
                  onPressed: _pageInflight ? null : _loadMore,
                  child: const Text('加载更多'),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              Text(
                  filtering
                      ? '${_matched ?? 0} / $_grand 条匹配'
                      : '已显示 ${rows.length} / $_grand 条',
                  style: TextStyle(
                      color: t.muted,
                      fontSize: 11,
                      fontFeatures: AppTypography.tabularFigures)),
            ],
          ],
        ),
      ),
    );
  }

  List<_ListEntry> get _entries => _buildEntries(_rows, widget.now ?? DateTime.now());

  /// F72 搜索框(v22 dlg-search):搜索图标 + 输入 + 清除钮(有文本时现)。
  Widget _searchBox(BuildContext context) {
    final t = context.yucai;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: AppRadius.smBorder,
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 15, color: t.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const ValueKey('agentAuditSearchInput'),
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: TextStyle(color: t.fg, fontSize: 12.5),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '搜索摘要 / 金额 / 幂等键…',
                hintStyle: TextStyle(color: t.muted, fontSize: 12.5),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_hasQuery)
            IconButton(
              key: const ValueKey('agentAuditSearchClear'),
              tooltip: '清除搜索',
              visualDensity: VisualDensity.compact,
              onPressed: _clearSearch,
              icon: Icon(LucideIcons.x, size: 14, color: t.muted),
            ),
        ],
      ),
    );
  }

  /// F72 分组段头(v22 aud-group:小字 muted 粗体 + 延展分隔线 + 段内
  /// 计数;非 sticky —— 随列表滚动,头部/搜索框恒定可见已足扫读锚定)。
  Widget _groupHeader(BuildContext context, String label, int count) {
    final t = context.yucai;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: t.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(width: 10),
          Expanded(child: Divider(height: 1, color: t.border)),
          const SizedBox(width: 10),
          Text('$count 条',
              style: TextStyle(
                  color: t.muted,
                  fontSize: 10.5,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }

  /// 列表行(v21 aud-row 四要素:时间 / 工具 chip / 摘要 / 右列徽标;
  /// 行尾 muted 同键注记 = v21 aud-note 形态,摘要下方挂)。
  /// F72:整行包 ContextMenuRegion(R16 桌面右键先例)单项「复制摘要」。
  Widget _row(
      BuildContext context, db.AgentAudit row, DateTime now, Set<String> failedKeys) {
    final t = context.yucai;
    // 同键注记显隐(T2-M1):仅 failed 行 + 同键 ok 行(重试对)。
    final showKeyNote = !row.ok || failedKeys.contains(row.idempotencyKey);
    return ContextMenuRegion(
      items: [
        MenuItemData(
          label: '复制摘要',
          icon: LucideIcons.copy,
          onTap: () => _copySummary(context, row.summary),
        ),
      ],
      child: Padding(
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
      ),
    );
  }

  /// 复制摘要(spec FR-3,design ADR-5):行 summary 原样入剪贴板 +
  /// AppToast「已复制」(先例 transactions_page 复制备注同款链)。
  void _copySummary(BuildContext context, String summary) {
    Clipboard.setData(ClipboardData(text: summary));
    AppToast.show(context, '已复制', type: ToastType.success);
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

  /// F72 搜索无匹配态(spec FR-2「空结果显示无匹配态」;同壳居中两行,
  /// 副行清除链接仍可达)。
  Widget _noMatchBody(BuildContext context) {
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
            child: Icon(LucideIcons.search, size: 20, color: t.muted),
          ),
          const SizedBox(height: 10),
          Text('无匹配「$_keyword」的记录',
              style: TextStyle(
                  color: t.fg, fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('换个关键词,或清除搜索查看全部',
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
