/// F18-T3(spec FR-5,design ADR-5):同步冲突面板 —— bind-only 路由
/// `/settings/conflicts` 的页面(badge 冲突 chip 的落点)。
///
/// 数据面 = [ConflictListBloc](路由层 provide;页面 initState 自发 Load,
/// 照 BudgetListPage「路由/页面双保险外的最简单发」取舍 —— 此处路由只
/// 构造 bloc 不发事件,单一触发点便于测试与 e2e 复用)。
///
/// 结构:
/// - 标题「同步冲突」+ 总数(权威计数 = ListConflicts totalCount);
/// - 条目卡:模块徽章(中文模块名)+ createdAt 相对时间 + **双栏对照**
///   (「服务端版本」/「我的版本」各 [ConflictFieldFormatter] 摘要,双
///   payload 解码;坏 payload 容错为「(无法解析)」);
/// - 操作:「保留服务端」(resolution "server")/「保留我的」("client")
///   二选一,v1 无 merged 编辑器(spec Scope boundary);resolving 中该条
///   按钮禁用(单飞防抖在 bloc 守卫);
/// - 分页:「加载更多」钮续页(选简单,design ADR-5 授权);空态「无待
///   处理冲突」;error 态带「重试」。
///
/// R8:颜色一律 `context.yucai` 语义令牌(warn=冲突色/amber 系);中文文案。
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/binding/presentation/bloc/conflict_list_bloc.dart';
import 'package:yucai_client/binding/presentation/widgets/conflict_field_formatter.dart';
import 'package:yucai_client/core/theme/app_design.dart';

class ConflictPanelPage extends StatefulWidget {
  const ConflictPanelPage({super.key});

  @override
  State<ConflictPanelPage> createState() => _ConflictPanelPageState();
}

class _ConflictPanelPageState extends State<ConflictPanelPage> {
  @override
  void initState() {
    super.initState();
    // 进面板即拉首页( BlocProvider 挂载后 context.read 可用;badge onTap /
    // 直接路由进入统一走此触发)。
    context.read<ConflictListBloc>().add(const ConflictListLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('同步冲突'),
      ),
      body: BlocBuilder<ConflictListBloc, ConflictListState>(
        builder: (context, state) {
          if (state.status == ConflictListStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == ConflictListStatus.error) {
            return _ErrorView(message: state.errorMessage ?? '加载失败');
          }
          if (state.items.isEmpty) {
            return const _EmptyView();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 总数行(权威计数;解决后随重拉收敛)。
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
                        AppSpacing.lg, AppSpacing.sm),
                child: Text(
                  '待处理 ${state.totalCount} 条',
                  style: TextStyle(
                      fontSize: 13,
                      color: t.warn,
                      fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(
                      left: AppSpacing.lg,
                      right: AppSpacing.lg,
                      bottom: AppSpacing.lg),
                  itemCount:
                      state.items.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // 末位 = 加载更多(hasMore 时);条目卡在前。
                    if (index == state.items.length) {
                      return _LoadMoreButton(
                          token: state.nextPageToken!);
                    }
                    return _ConflictCard(item: state.items[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 空态:无待处理冲突(在线零冲突感知的落点文案)。
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.circleCheckBig, size: 36, color: t.positive),
          const SizedBox(height: AppSpacing.md),
          Text('无待处理冲突',
              style: TextStyle(fontSize: 15, color: t.muted)),
        ],
      ),
    );
  }
}

/// 错误态:文案 + 重试(回首页重拉)。
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.cloudOff, size: 36, color: t.negative),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: t.muted)),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => context
                  .read<ConflictListBloc>()
                  .add(const ConflictListLoadRequested()),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「加载更多」续页钮(分页选简单:按钮而非滚动到底触发,design 授权)。
class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.token});

  /// 续页游标(上一页 nextPageToken)。
  final String token;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: OutlinedButton(
        onPressed: () => context
            .read<ConflictListBloc>()
            .add(ConflictListLoadMoreRequested(token)),
        child: const Text('加载更多'),
      ),
    );
  }
}

/// 单条冲突卡:模块徽章 + 相对时间 + 双栏对照 + 二选一操作。
class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.item});

  final SyncConflictInfo item;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    final resolving = context.select<ConflictListBloc, bool>(
        (bloc) => bloc.state.resolvingConflictId == item.conflictId);
    final relTime = ConflictFieldFormatter.relativeTime(item.createdAt);
    return Container(
      key: ValueKey('conflict-card-${item.conflictId}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 头行:模块徽章(中文模块名)+ 相对时间。
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: t.warn.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ConflictFieldFormatter.moduleLabel(item.module),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: t.warn),
                ),
              ),
              const Spacer(),
              if (relTime.isNotEmpty)
                Text(relTime,
                    style: TextStyle(fontSize: 11, color: t.muted)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // 双栏对照:服务端版本 vs 我的版本(各 formatter 摘要)。
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PayloadColumn(
                  title: '服务端版本',
                  lines: ConflictFieldFormatter.summarize(
                      item.module, item.serverPayload),
                  emphasize: false,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _PayloadColumn(
                  title: '我的版本',
                  lines: ConflictFieldFormatter.summarize(
                      item.module, item.clientPayload),
                  emphasize: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // 二选一操作(v1 无 merged 编辑器;resolving 中禁用)。
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: resolving
                      ? null
                      : () => context.read<ConflictListBloc>().add(
                          ConflictResolveRequested(
                              item.conflictId!, 'server')),
                  child: const Text('保留服务端'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: resolving
                      ? null
                      : () => context.read<ConflictListBloc>().add(
                          ConflictResolveRequested(
                              item.conflictId!, 'client')),
                  child: const Text('保留我的'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 双栏对照的单栏:栏标题 + 摘要行集合。
class _PayloadColumn extends StatelessWidget {
  const _PayloadColumn({
    required this.title,
    required this.lines,
    required this.emphasize,
  });

  final String title;
  final List<String> lines;

  /// 「我的版本」侧强调(warn 描边;解决「保留我的」时落库的内容即此栏)。
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: emphasize ? Border.all(color: t.warn, width: 1.2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: emphasize ? t.warn : t.muted)),
          const SizedBox(height: 4),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(line,
                  style: TextStyle(fontSize: 12, color: t.fg)),
            ),
        ],
      ),
    );
  }
}
