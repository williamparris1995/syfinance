/// F18-T3(spec FR-5,design ADR-5):冲突面板数据面 bloc —— ListConflicts 的
/// 拉取/翻页/解决编排,`ConflictPanelPage` 的唯一数据源。
///
/// 与协调器的分工(offline_sync_port.dart [ConflictPage] doc 钉死):协调器
/// push 后不重拉,**权威计数 = ListConflicts 的 totalCount**,由本 bloc 自取
/// —— Load(首页/刷新,进面板/解决后)/ LoadMore(pageToken 续页)。
///
/// 事件(命名照库内 ...Requested 惯例):
/// - [ConflictListLoadRequested]:首页/刷新 —— loading → loaded / error;
/// - [ConflictListLoadMoreRequested]:续页追加(非 loaded 或无余页时忽略,
///   幂等防抖);
/// - [ConflictResolveRequested]:解决一条(resolution 值域 "server"|"client",
///   v1 二选一)—— resolving 标记(按钮禁用面)→ port.resolveConflict →
///   成功后**重拉首页**(权威计数刷新,spec「解决后面板刷新」);失败收敛
///   error(port 透抛契约,面板自行收敛)。
///
/// 单飞防抖:resolving 中再来的解决请求直接丢弃(二选一操作,无并发语义)。
library;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yucai_client/binding/domain/offline_sync_port.dart';

/// 冲突面板列表事件。
sealed class ConflictListEvent {
  const ConflictListEvent();
}

/// 首页/刷新(进面板、解决成功后、错误重试)。
class ConflictListLoadRequested extends ConflictListEvent {
  const ConflictListLoadRequested();
}

/// 续页([ConflictListState.nextPageToken] 透传;非 loaded/无余页忽略)。
class ConflictListLoadMoreRequested extends ConflictListEvent {
  const ConflictListLoadMoreRequested(this.pageToken);

  /// 续页游标(上一页 ListConflicts 返回的 nextPageToken)。
  final String pageToken;
}

/// 解决一条冲突(FR-5 v1 二选一)。
class ConflictResolveRequested extends ConflictListEvent {
  const ConflictResolveRequested(this.conflictId, this.resolution);

  /// 冲突记录 id(server ConflictDTO.id;ResolveConflict 定位键)。
  final String conflictId;

  /// 解决方向:"server"(保留服务端)| "client"(保留我的)。
  final String resolution;
}

/// 面板列表状态形态。
enum ConflictListStatus {
  /// 加载中(首页;初始态同此 —— 进面板即拉)。
  loading,

  /// 已加载(items + totalCount + 分页游标;resolving 随解决流携带)。
  loaded,

  /// 加载/解决失败(errorMessage;面板展示 + 重试入口)。
  error,
}

/// 冲突面板对外状态流。
class ConflictListState extends Equatable {
  const ConflictListState({
    this.status = ConflictListStatus.loading,
    this.items = const [],
    this.totalCount = 0,
    this.nextPageToken,
    this.resolvingConflictId,
    this.errorMessage,
  });

  /// 面板状态(loading/loaded/error)。
  final ConflictListStatus status;

  /// 已加载的冲突条目(首页 + 已翻页累计;server created_at DESC 最新序)。
  final List<SyncConflictInfo> items;

  /// 待解决冲突总数(权威计数 = ListConflicts totalCount;标题「共 N 条」)。
  final int totalCount;

  /// 下一页游标(null = 末页)。
  final String? nextPageToken;

  /// 是否仍有余页(= nextPageToken 非空;「加载更多」按钮显隐)。
  bool get hasMore => nextPageToken != null;

  /// 解决中的条目 id(非空 = 该条按钮禁用 + 转圈;单飞,完成/失败复位)。
  final String? resolvingConflictId;

  /// error 态信息(加载失败原因 / 解决失败原因)。
  final String? errorMessage;

  @override
  List<Object?> get props => [
        status,
        items,
        totalCount,
        nextPageToken,
        resolvingConflictId,
        errorMessage,
      ];
}

/// 冲突面板列表 bloc(port 经构造注入;生命周期随面板路由)。
class ConflictListBloc extends Bloc<ConflictListEvent, ConflictListState> {
  ConflictListBloc(this._port) : super(const ConflictListState()) {
    on<ConflictListLoadRequested>(_onLoad);
    on<ConflictListLoadMoreRequested>(_onLoadMore);
    on<ConflictResolveRequested>(_onResolve);
  }

  final OfflineSyncPort _port;

  Future<void> _onLoad(
    ConflictListLoadRequested event,
    Emitter<ConflictListState> emit,
  ) async {
    // 首页/刷新:清列表回 loading(解决成功后的重拉由 [_onResolve] 直发
    // loaded,不走此闪烁路径)。
    emit(const ConflictListState());
    try {
      final page = await _port.listConflicts();
      emit(ConflictListState(
        status: ConflictListStatus.loaded,
        items: page.items,
        totalCount: page.totalCount,
        nextPageToken: page.nextPageToken,
      ));
    } catch (e) {
      emit(ConflictListState(
        status: ConflictListStatus.error,
        errorMessage: '加载冲突列表失败:$e',
      ));
    }
  }

  Future<void> _onLoadMore(
    ConflictListLoadMoreRequested event,
    Emitter<ConflictListState> emit,
  ) async {
    // 守卫:仅 loaded 且有余页才续(loading/error/重复点击忽略,幂等)。
    if (state.status != ConflictListStatus.loaded || !state.hasMore) return;
    try {
      final page = await _port.listConflicts(pageToken: event.pageToken);
      emit(ConflictListState(
        status: ConflictListStatus.loaded,
        items: [...state.items, ...page.items],
        totalCount: page.totalCount,
        nextPageToken: page.nextPageToken,
      ));
    } catch (e) {
      emit(ConflictListState(
        status: ConflictListStatus.error,
        items: state.items,
        errorMessage: '加载更多失败:$e',
      ));
    }
  }

  Future<void> _onResolve(
    ConflictResolveRequested event,
    Emitter<ConflictListState> emit,
  ) async {
    // 守卫:仅 loaded 且无在途解决(单飞防抖)。
    if (state.status != ConflictListStatus.loaded ||
        state.resolvingConflictId != null) {
      return;
    }
    // resolving 标记:该条按钮禁用(items 保留,双栏对照不闪)。
    emit(ConflictListState(
      status: ConflictListStatus.loaded,
      items: state.items,
      totalCount: state.totalCount,
      nextPageToken: state.nextPageToken,
      resolvingConflictId: event.conflictId,
    ));
    try {
      await _port.resolveConflict(event.conflictId, event.resolution);
      // 解决成功 → 重拉首页:权威计数 + 最新列表(FR-5「解决后面板刷新」;
      // 直接发 loaded 不经 loading 闪烁)。重拉失败按 error 收敛(解决本身
      // 已成功,刷新可经重试入口恢复)。
      final page = await _port.listConflicts();
      emit(ConflictListState(
        status: ConflictListStatus.loaded,
        items: page.items,
        totalCount: page.totalCount,
        nextPageToken: page.nextPageToken,
      ));
    } catch (e) {
      emit(ConflictListState(
        status: ConflictListStatus.error,
        items: state.items,
        errorMessage: '解决冲突失败:$e',
      ));
    }
  }
}
