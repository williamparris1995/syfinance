/// F65-T3 聊天浮层宿主与渲染(V1 形态;spec FR-1/FR-4,design ADR-1/ADR-2,
/// 视觉事实源 = prototype v19 ui/assistant-entry-variants.html V1 段 +
/// assistant-chat-states.html 全页)。
///
/// 结构(ADR-1:V1 独立助手 FAB + 400px 右下聊天浮层,无新路由无侧栏项):
/// - [AssistantOverlayHost] 挂 app shell 全局位(与页面级 FloatingActionDock
///   同屏错位,见 [_dockInset] 注);内部持常驻 FAB + 可开合浮层,浮层开合
///   不销毁 bloc(会话跨开合保留,「新对话」才清)。
/// - **打开浮层即预热**:[EngineManager.ensureReady] 幂等(ADR-1/F66 拍板,
///   懒启动边车 3-8s 冷启前置)。
/// - 消息渲染 = [PanelMessage] sealed 分型(UserMsg 右气泡/AssistantMsg 左
///   气泡+流式光标/ToolStatusMsg 状态条/ErrorMsg 错误条+重试/GuideMsg 引导
///   三型);流式合帧已由 bloc 30ms 承担,此处直接 rebuild。
///
/// 装配:四依赖构造注入(测试 fake);缺省经 guarded getIt 解析(core/di 1m
/// 段全注册,照 OfflineBadge/settings 卡先例 —— 测试 stripped harness 未注册
/// 时整体 shrink 不炸 build)。零裸色:全部走 `context.yucai` 令牌。
library;

import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/assistant/data/assistant_settings_store.dart';
import 'package:yucai_client/assistant/domain/agent_loop.dart';
import 'package:yucai_client/assistant/domain/engine_port.dart';
import 'package:yucai_client/assistant/domain/model_manager_port.dart';
import 'package:yucai_client/assistant/domain/model_state.dart';
import 'package:yucai_client/assistant/presentation/assistant_panel/assistant_panel_bloc.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// 工具名 → 状态条中文标签(ToolCallStart 携带注册表 id;兜底原样)。
const _toolLabels = <String, String>{
  'networth_snapshot': '净资产',
  'accounts_list': '账户列表',
  'debts_list': '债务',
  'holdings_list': '持仓',
  'transactions_search': '交易记录',
  'budgets_status': '预算执行',
  'goals_list': '目标进度',
  'performance_range': '区间收益',
};

String _toolLabel(String name) => _toolLabels[name] ?? name;

String _gb(int bytes) => '${(bytes / 1e9).toStringAsFixed(1)}GB';

/// R19 FloatingActionDock 挂载几何(design_kit 各 detail 页
/// Positioned(right: 28, bottom: 28);主 FAB 52px,次级 44px+间距 10)。
/// 助手 FAB 取 v19 并列几何:主 FAB 左侧 16px、与 dock 底线对齐 ——
/// 竖向「主 FAB 正上方」会与六 detail 页 dock 底锚上摞的 44px 次级钮
/// (编辑/转账/减仓等,dock 总高至 214)重叠,并列错位对任意 dock 高零碰撞。
const _kDockInset = 28.0;
const _kDockPrimary = 52.0;
const _kFabGap = 16.0;

/// 浮层底部锚位:清空 dock 标配高(52 主 + 10 间距 + 44 次)再留 8 净空
/// (v19 .float-chat bottom:136 同构:22 + 106 + 8)。
const _kPanelBottom = _kDockInset + _kDockPrimary + 10 + 44 + 8; // 142

/// 助手 FAB 边长(v19 .fab-assist 44px 圆,surface 底 + acc 描边,与
/// dock 52px 金渐变主 FAB 区分)。
const _kFabSize = 44.0;

/// 全局助手宿主:右下助手 FAB + 400px 聊天浮层(同屏错位见 build 注)。
class AssistantOverlayHost extends StatefulWidget {
  const AssistantOverlayHost({
    super.key,
    this.loop,
    this.settings,
    this.modelManager,
    this.engineManager,
    this.frameInterval,
  });

  /// loop 事件流缝(缺省 guarded getIt;测试注入 fake)。
  final AgentLoopService? loop;

  /// 助手配置仓储(启用守卫 + listenable 驱动)。
  final AssistantSettings? settings;

  /// 模型管理 port(引导态下载进度绑定)。
  final ModelManagerPort? modelManager;

  /// 引擎管理 port(打开浮层即 ensureReady 预热 + 冷启守卫状态)。
  final EngineManager? engineManager;

  /// TextDelta 合帧窗口(bloc 缺省 30ms;测试注入 Duration.zero)。
  final Duration? frameInterval;

  @override
  State<AssistantOverlayHost> createState() => _AssistantOverlayHostState();
}

class _AssistantOverlayHostState extends State<AssistantOverlayHost> {
  AssistantPanelBloc? _bloc;
  ModelManagerPort? _modelManager;
  EngineManager? _engineManager;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    final loop = widget.loop ??
        (getIt.isRegistered<AgentLoopService>()
            ? getIt<AgentLoopService>()
            : null);
    final settings = widget.settings ??
        (getIt.isRegistered<AssistantSettings>()
            ? getIt<AssistantSettings>()
            : null);
    _modelManager = widget.modelManager ??
        (getIt.isRegistered<ModelManagerPort>()
            ? getIt<ModelManagerPort>()
            : null);
    _engineManager = widget.engineManager ??
        (getIt.isRegistered<EngineManager>()
            ? getIt<EngineManager>()
            : null);
    if (loop != null &&
        settings != null &&
        _modelManager != null &&
        _engineManager != null) {
      _bloc = AssistantPanelBloc(
        loop: loop,
        config: settings.listenable,
        modelState: _modelManager!.state,
        engineState: _engineManager!.state,
        frameInterval:
            widget.frameInterval ?? const Duration(milliseconds: 30),
      );
    }
  }

  @override
  void dispose() {
    _bloc?.close();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      // 打开浮层即预热(ADR-1/F66):ensureReady 幂等 —— Ready 即返、
      // Stopped/Error 走拉起、Starting 等待既有 Future;fire-and-forget。
      unawaited(_engineManager!.ensureReady());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = _bloc;
    if (bloc == null) return const SizedBox.shrink();
    return SizedBox.expand(
      // 全幅透明命中层:Stack 自身不拦截指针,仅 FAB/浮层可点。
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: _kDockInset + _kDockPrimary + _kFabGap,
            bottom: _kDockInset,
            child: _AssistantFab(onTap: _toggle),
          ),
          if (_open)
            Positioned(
              right: _kDockInset,
              bottom: _kPanelBottom,
              child: _AssistantChatPanel(
                key: const ValueKey('assistantPanel'),
                bloc: bloc,
                modelManager: _modelManager!,
                onClose: () => setState(() => _open = false),
              ),
            ),
        ],
      ),
    );
  }
}

/// 助手 FAB(v19 .fab-assist):44px 圆,surface 底 + accent 描边 + accent
/// sparkle 图标,hover accentSoft —— 与 dock 主 FAB 的 52px 金渐变区分。
class _AssistantFab extends StatefulWidget {
  const _AssistantFab({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AssistantFab> createState() => _AssistantFabState();
}

class _AssistantFabState extends State<_AssistantFab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tooltip(
        message: '御财助手',
        child: Material(
          color: Colors.transparent,
          child: Ink(
            key: const ValueKey('assistantFab'),
            width: _kFabSize,
            height: _kFabSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hover ? t.accentSoft : t.surface,
              border: Border.all(color: t.accent),
              boxShadow: [
                BoxShadow(
                  color: t.accent.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              onTap: widget.onTap,
              customBorder: const CircleBorder(),
              child: SizedBox.expand(
                child: Center(
                  child: Icon(LucideIcons.sparkle,
                      size: 20, color: t.accent),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 聊天浮层(v19 .chat-panel):头部(徽标 + 标题 + 本机运行 chip + 新对话 +
/// 收起)/ 消息流区 / 输入行。宽 400(v19 .float-chat),高有界随视口收敛。
class _AssistantChatPanel extends StatefulWidget {
  const _AssistantChatPanel({
    super.key,
    required this.bloc,
    required this.modelManager,
    required this.onClose,
  });

  final AssistantPanelBloc bloc;
  final ModelManagerPort modelManager;
  final VoidCallback onClose;

  @override
  State<_AssistantChatPanel> createState() => _AssistantChatPanelState();
}

class _AssistantChatPanelState extends State<_AssistantChatPanel> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    widget.bloc.add(SendRequested(text));
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    final mq = MediaQuery.of(context);
    // 宽 400(v19);窄屏降级 = 收视口边距(design Risk)。
    final width = math.min(400.0, mq.size.width - 2 * 28);
    final height = math.min(480.0, mq.size.height - _kPanelBottom - 100);
    return BlocProvider<AssistantPanelBloc>.value(
      value: widget.bloc,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: AppRadius.lgBorder,
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(
              color: t.accent.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            _PanelHeader(onClose: widget.onClose),
            Expanded(
              child: BlocBuilder<AssistantPanelBloc, AssistantPanelState>(
                builder: (context, state) => DecoratedBox(
                  decoration: BoxDecoration(color: t.bg),
                  child: state.messages.isEmpty
                      ? _PanelEmpty(onAsk: (q) =>
                          widget.bloc.add(SendRequested(q)))
                      : _MessageList(
                          messages: state.messages,
                          busy: state.isBusy,
                          modelManager: widget.modelManager,
                        ),
                ),
              ),
            ),
            _InputBar(controller: _input, onSend: _send),
          ],
        ),
      ),
    );
  }
}

/// 头部(v19 .cp-head + FR-4「新对话」):徽标/标题/本机运行 chip/新对话/收起。
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: t.accentSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Icon(LucideIcons.sparkle, size: 16, color: t.accent),
            ),
          ),
          const SizedBox(width: 10),
          Text('御财助手',
              style: TextStyle(
                  color: t.fg, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: t.positive.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('本机运行',
                style: TextStyle(
                    color: t.positive,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          TextButton.icon(
            key: const ValueKey('assistantNewChatButton'),
            onPressed: () => context
                .read<AssistantPanelBloc>()
                .add(const NewConversationClicked()),
            icon: Icon(LucideIcons.rotateCcw, size: 13, color: t.muted),
            label: Text('新对话',
                style: TextStyle(
                    color: t.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            key: const ValueKey('assistantCloseButton'),
            tooltip: '收起',
            onPressed: onClose,
            icon: Icon(LucideIcons.x, size: 14, color: t.muted),
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(28, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

/// 空态(v19 state-1 .cp-empty):徽标 + 引导文案 + 三枚示例问题 chips。
class _PanelEmpty extends StatelessWidget {
  const _PanelEmpty({required this.onAsk});

  /// 点示例问题 = 直接发送。
  final ValueChanged<String> onAsk;

  static const _samples = ['这个月花了多少', '广发卡还差多少', '今年收益率'];

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: t.accentSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child:
                    Icon(LucideIcons.sparkle, size: 20, color: t.accent),
              ),
            ),
            const SizedBox(height: 10),
            Text('我是御财助手,数据都在本机',
                style: TextStyle(
                    color: t.fg,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('支出、预算、资产都可以问',
                style: TextStyle(color: t.muted, fontSize: 11.5)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              alignment: WrapAlignment.center,
              children: [
                for (final sample in _samples)
                  _QuestionChip(label: sample, onTap: () => onAsk(sample)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 示例问题 chip(v19 .q-chip)。
class _QuestionChip extends StatefulWidget {
  const _QuestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_QuestionChip> createState() => _QuestionChipState();
}

class _QuestionChipState extends State<_QuestionChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: _hover ? t.accent : t.border),
          ),
          child: Text(widget.label,
              style: TextStyle(
                  color: t.accent, // v19 .q-chip:link 色(NFR-1 无 link 令牌 → accent)
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

/// 消息流区:逐条分型渲染 + 新消息自动滚底。
class _MessageList extends StatefulWidget {
  const _MessageList({
    required this.messages,
    required this.busy,
    required this.modelManager,
  });

  final List<PanelMessage> messages;
  final bool busy;
  final ModelManagerPort modelManager;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(_MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      itemCount: widget.messages.length,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.only(
            top: index == 0 ? 0 : 9), // v19 .cp-body gap:9
        child: _messageTile(
          context,
          widget.messages[index],
          isLast: index == widget.messages.length - 1,
        ),
      ),
    );
  }

  Widget _messageTile(BuildContext context, PanelMessage message,
      {required bool isLast}) {
    return switch (message) {
      UserMsg(:final text) => Align(
          alignment: Alignment.centerRight,
          child: Container(
            key: const ValueKey('assistantUserBubble'),
            padding: const EdgeInsets.symmetric(
                horizontal: 11, vertical: 8),
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: context.yucai.accent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13),
                topRight: Radius.circular(13),
                bottomLeft: Radius.circular(13),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(text,
                style: TextStyle(
                    color: context.yucai.onAccent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500)),
          ),
        ),
      AssistantMsg(:final text) => Align(
          alignment: Alignment.centerLeft,
          child: Container(
            key: const ValueKey('assistantBotBubble'),
            padding: const EdgeInsets.symmetric(
                horizontal: 11, vertical: 8),
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: context.yucai.surfaceAlt,
              border: Border.all(color: context.yucai.border),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(13),
                bottomLeft: Radius.circular(13),
                bottomRight: Radius.circular(13),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(text,
                      style: TextStyle(
                          color: context.yucai.fg, fontSize: 12.5)),
                ),
                // 流式光标:尾段且往返进行中(v19 .cursor 7x13 blink)。
                if (isLast && widget.busy) ...[
                  const SizedBox(width: 2),
                  const _StreamCursor(),
                ],
              ],
            ),
          ),
        ),
      ToolStatusMsg(:final name, :final ok) => Align(
          alignment: Alignment.centerLeft,
          child: Container(
            key: const ValueKey('assistantToolPill'),
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: context.yucai.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ok == null)
                  const SizedBox(
                    width: 11,
                    height: 11,
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (ok)
                  Icon(LucideIcons.circleCheck,
                      size: 13, color: context.yucai.positive)
                else
                  Icon(LucideIcons.circleX,
                      size: 13, color: context.yucai.muted),
                const SizedBox(width: 7),
                Text(
                  ok == null
                      ? '正在查询${_toolLabel(name)}…'
                      : ok
                          ? '已查询${_toolLabel(name)}'
                          : '查询${_toolLabel(name)}失败',
                  style: TextStyle(
                      color: context.yucai.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ErrorMsg(:final text) => Container(
          key: const ValueKey('assistantErrorMsg'),
          padding: const EdgeInsets.symmetric(
              horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: context.yucai.negative.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.triangleAlert,
                  size: 14, color: context.yucai.negative),
              const SizedBox(width: 9),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        color: context.yucai.negative,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              TextButton.icon(
                key: const ValueKey('assistantRetryButton'),
                onPressed: () => context
                    .read<AssistantPanelBloc>()
                    .add(const RetryRequested()),
                icon: Icon(LucideIcons.rotateCcw,
                    size: 13, color: context.yucai.negative),
                label: Text('重试',
                    style: TextStyle(
                        color: context.yucai.negative,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 6),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      GuideMsg(:final kind) => _GuideCard(kind: kind,
          modelManager: widget.modelManager),
    };
  }
}

/// 流式光标(v19 .cursor:7x13 accent 块 1.1s 阶跃闪烁)。
class _StreamCursor extends StatefulWidget {
  const _StreamCursor();

  @override
  State<_StreamCursor> createState() => _StreamCursorState();
}

class _StreamCursorState extends State<_StreamCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        key: const ValueKey('assistantStreamCursor'),
        width: 7,
        height: 13,
        decoration: BoxDecoration(
          color: context.yucai.accent,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// 引导卡三型(FR-1 场景二:零 LLM 调用,守卫已在 bloc 拦截)。
class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.kind, required this.modelManager});

  final GuideKind kind;
  final ModelManagerPort modelManager;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      child: switch (kind) {
        // 未启用:去设置开「AI 助手」开关。
        GuideKind.notEnabled => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('AI 助手未启用',
                  style: TextStyle(
                      color: context.yucai.fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('在设置中开启「AI 助手」后即可使用',
                  style: TextStyle(
                      color: context.yucai.muted, fontSize: 11.5)),
              const SizedBox(height: 8),
              const _GoSettingsButton(),
            ],
          ),
        // 模型未就绪:绑 ModelState 流 —— 下载中出进度(v19 state-6 .dl-block),
        // 其余态(未下载/暂停/失败)给通用引导 + 去设置。
        GuideKind.modelNotReady =>
          ValueListenableBuilder<ModelState>(
            valueListenable: modelManager.state,
            builder: (context, model, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (model is ModelDownloading) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.yucai.warn.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(LucideIcons.download,
                          size: 18, color: context.yucai.warn),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text('正在下载模型',
                      style: TextStyle(
                          color: context.yucai.fg,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: AppRadius.smBorder,
                    child: LinearProgressIndicator(
                      key: const ValueKey('assistantGuideProgress'),
                      value: model.receivedBytes / model.totalBytes,
                      minHeight: 6,
                      backgroundColor: context.yucai.surfaceAlt,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          context.yucai.accent),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${_gb(model.receivedBytes)} / ${_gb(model.totalBytes)} · 可断点续传',
                    style: TextStyle(
                        color: context.yucai.muted, fontSize: 11.5),
                  ),
                  const SizedBox(height: 4),
                  Text('下载完成后即可离线使用',
                      style: TextStyle(
                          color: context.yucai.muted, fontSize: 11)),
                ] else ...[
                  Text('模型未就绪',
                      style: TextStyle(
                          color: context.yucai.fg,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('先在设置完成模型下载(支持断点续传)',
                      style: TextStyle(
                          color: context.yucai.muted, fontSize: 11.5)),
                  const SizedBox(height: 8),
                  const _GoSettingsButton(),
                ],
              ],
            ),
          ),
        // 引擎冷启动中(F66 拍板):旋转指示 + 「引擎启动中…」。
        GuideKind.engineStarting => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 9),
              Text('引擎启动中…',
                  style: TextStyle(
                      color: context.yucai.fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('本机引擎首次启动约需数秒,请稍候',
                  style: TextStyle(
                      color: context.yucai.muted, fontSize: 11.5)),
            ],
          ),
      },
    );
  }
}

/// 「去设置」按钮:跳设置页(AI 助手卡所在);maybeOf 让无 GoRouter 的
/// 测试 harness 不抛。
class _GoSettingsButton extends StatelessWidget {
  const _GoSettingsButton();

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return TextButton.icon(
      key: const ValueKey('assistantGoSettingsButton'),
      onPressed: () => GoRouter.maybeOf(context)?.go('/settings'),
      icon: Icon(LucideIcons.settings, size: 13, color: t.accent),
      label: Text('去设置',
          style: TextStyle(
              color: t.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(
        padding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// 输入行(v19 .cp-input):surfaceAlt 底 + 上边框;流式期间禁用
/// (bloc isBusy:streaming/awaitTool);Enter 发送。
class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return BlocBuilder<AssistantPanelBloc, AssistantPanelState>(
      builder: (context, state) {
        final busy = state.isBusy;
        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: t.surfaceAlt,
            border: Border(top: BorderSide(color: t.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !busy,
                  onSubmitted: (_) => onSend(),
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: '问点什么,如:广发卡还差多少',
                    isDense: true,
                    filled: true,
                    fillColor: t.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 8),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: t.border),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: t.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: t.accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey('assistantSendButton'),
                tooltip: '发送',
                onPressed: busy ? null : onSend,
                icon: const Icon(LucideIcons.send, size: 16),
                style: IconButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: t.onAccent,
                  disabledForegroundColor:
                      t.onAccent.withValues(alpha: 0.5),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(36, 36),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
