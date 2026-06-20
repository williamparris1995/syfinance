import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/category_event.dart';
import 'package:yucai_client/transaction/presentation/bloc/category_state.dart';

/// 分类管理 Bloc。
///
/// 分类 = 账户（account-as-category）：支出/收入分类即 accountType 为
/// expense/income 的账户。本 Bloc 复用账户 use-cases（list/create/update/delete）
/// 并按 [CategoryType] 在客户端过滤（FindByAccountType 尚未生成 client stub，
/// 见 task-4.2 报告 workaround）。
///
/// is_system 标记从名称匹配 10 个预置分类派生（account DTO 暂未暴露该字段）。
/// 系统分类的删除在 bloc 内拦截 —— 服务端也会拒，但客户端先拒以避免无效 RPC
/// 并给出友好错误。
@injectable
class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  CategoryBloc(
    this._list,
    this._create,
    this._delete,
    this._update,
  ) : super(CategoryInitial()) {
    on<LoadCategoriesRequested>(_onLoad);
    on<SaveCategoryRequested>(_onSave);
    on<DeleteCategoryRequested>(_onDelete);
    on<ReorderCategoriesRequested>(_onReorder);
  }

  final ListAccountsUseCase _list;
  final CreateAccountUseCase _create;
  final DeleteAccountUseCase _delete;
  final UpdateAccountUseCase _update;

  CategoryType _currentType = CategoryType.expense;

  /// Reads the cached list from the current state. Tests seed a CategoryLoaded
  /// directly; deriving from state (rather than a private field) keeps the two
  /// in sync.
  List<CategoryItem> get _last {
    final s = state;
    if (s is CategoryLoaded) return s.categories;
    if (s is CategoryLoading) return s.categories;
    if (s is CategorySubmitting) return s.categories;
    if (s is CategoryError) return s.categories;
    return const [];
  }

  Future<void> _onLoad(LoadCategoriesRequested event, Emitter<CategoryState> emit) async {
    _currentType = event.type;
    emit(CategoryLoading(event.type, categories: _last));
    final result = await _list.call();
    result.fold(
      (failure) => emit(CategoryError(failure.displayMessage,
          type: event.type, categories: _last)),
      (accounts) {
        final items = _filterAndMap(accounts, event.type);
        emit(CategoryLoaded(type: event.type, categories: items));
      },
    );
  }

  Future<void> _onSave(SaveCategoryRequested event, Emitter<CategoryState> emit) async {
    emit(CategorySubmitting(type: _currentType, categories: _last));
    if (event.id.isEmpty) {
      final params = CreateAccountParams(
        name: event.name,
        accountType: event.type.accountType,
        // expense/income 分类账户走 NewCategoryAccount（服务端 CreateAccount
        // 按 accountType=Expense/Income 分流），category 字段对分类账户无意义、
        // 服务端忽略。见 server/service.go CreateAccount。
        category: AccountCategory.otherAsset,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        ownership: Ownership.personal,
        icon: event.icon,
        color: event.color,
        parentId: event.parentId,
      );
      final result = await _create.call(params);
      result.fold(
        (failure) => emit(CategoryError(failure.displayMessage,
            type: _currentType, categories: _last)),
        (_) => add(LoadCategoriesRequested(_currentType)),
      );
    } else {
      final params = UpdateAccountParams(
        id: event.id,
        version: event.version,
        name: event.name,
        icon: event.icon,
        color: event.color,
        // parentId flows into the proto only on Create; UpdateAccountRequest
        // has no parentId field (see account_remote_ds.dart).
        parentId: event.parentId,
      );
      final result = await _update.call(params);
      result.fold(
        (failure) => emit(CategoryError(failure.displayMessage,
            type: _currentType, categories: _last)),
        (_) => add(LoadCategoriesRequested(_currentType)),
      );
    }
  }

  Future<void> _onDelete(DeleteCategoryRequested event, Emitter<CategoryState> emit) async {
    // 系统分类删除拦截：name 命中预置 10 分类 → 拒。
    final target = _last.where((c) => c.id == event.id).firstOrNull;
    if (target != null && target.isSystem) {
      emit(CategoryError('系统预置分类不可删除',
          type: _currentType, categories: _last));
      return;
    }
    final result = await _delete.call(event.id);
    result.fold(
      (failure) => emit(CategoryError(failure.displayMessage,
          type: _currentType, categories: _last)),
      (_) => add(LoadCategoriesRequested(_currentType)),
    );
  }

  Future<void> _onReorder(ReorderCategoriesRequested event, Emitter<CategoryState> emit) async {
    await Future<void>.value();
    // ReorderableListView 语义：newIndex > oldIndex 时目标下移，需 -1 校正。
    final items = List<CategoryItem>.from(_last);
    final from = event.oldIndex;
    final to = event.newIndex > event.oldIndex ? event.newIndex - 1 : event.newIndex;
    if (from < 0 || from >= items.length || to < 0) return;
    final moved = items.removeAt(from);
    if (to > items.length) return;
    items.insert(to, moved);
    emit(CategoryLoaded(type: _currentType, categories: items));
  }

  List<CategoryItem> _filterAndMap(List<Account> accounts, CategoryType type) {
    return accounts
        .where((a) => _matchesType(a.accountType, type))
        .map(CategoryItem.fromAccount)
        .toList();
  }

  bool _matchesType(AccountType t, CategoryType type) {
    switch (type) {
      case CategoryType.expense:
        return t == AccountType.expense;
      case CategoryType.income:
        return t == AccountType.income;
    }
  }
}
