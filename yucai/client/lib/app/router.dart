import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:yucai_client/app/route_observer.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/pages/account_detail_page.dart';
import 'package:yucai_client/account/presentation/pages/accounts_page.dart';
import 'package:yucai_client/app/widgets/app_shell.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/auth/presentation/pages/home_page.dart';
import 'package:yucai_client/auth/presentation/pages/login_page.dart';
import 'package:yucai_client/auth/presentation/pages/register_page.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/pages/debt_detail_page.dart';
import 'package:yucai_client/debt/presentation/pages/debt_form_page.dart';
import 'package:yucai_client/debt/presentation/pages/debts_page.dart';
import 'package:yucai_client/debt/presentation/pages/receivable_detail_page.dart';
import 'package:yucai_client/debt/presentation/pages/receivable_form_page.dart';
import 'package:yucai_client/debt/presentation/pages/receivables_page.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_event.dart';
import 'package:yucai_client/holding/presentation/bloc/performance_bloc.dart';
import 'package:yucai_client/holding/presentation/pages/goal_link_page.dart';
import 'package:yucai_client/holding/presentation/pages/holding_detail_page.dart';
import 'package:yucai_client/holding/presentation/pages/holdings_page.dart';
import 'package:yucai_client/holding/presentation/pages/performance_page.dart';
import 'package:yucai_client/holding/presentation/pages/security_page.dart';
import 'package:yucai_client/holding/presentation/pages/trade_sheet_page.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_event.dart';
import 'package:yucai_client/settings/presentation/settings_page.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/presentation/bloc/category_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/pages/category_management_page.dart';
import 'package:yucai_client/transaction/presentation/pages/transaction_detail_page.dart';
import 'package:yucai_client/transaction/presentation/pages/transaction_form_page.dart';
import 'package:yucai_client/transaction/presentation/pages/transactions_page.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

/// Builds the app router. Reads auth state to guard routes.
///
/// 受保护区域用 [StatefulShellRoute.indexedStack] 承载，侧边栏/顶栏
/// ([AppShell]) 在整个会话期间保持挂载，分支切换不重建外壳。
GoRouter buildRouter(AuthBloc authBloc) {
  return GoRouter(
    observers: [routeObserver],
    refreshListenable: _AuthBlocListenable(authBloc),
    redirect: (context, state) {
      final auth = authBloc.state;
      final isLoggedIn = auth is Authenticated;
      final isLoading = auth is AuthInitial || auth is AuthLoading;
      final goingToAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final goingProtected = state.matchedLocation == '/home' ||
          state.matchedLocation.startsWith('/accounts') ||
          state.matchedLocation.startsWith('/transactions') ||
          state.matchedLocation.startsWith('/categories') ||
          state.matchedLocation.startsWith('/debts') ||
          state.matchedLocation.startsWith('/receivables') ||
          state.matchedLocation.startsWith('/holdings') ||
          state.matchedLocation.startsWith('/settings');

      if (isLoading) return null;

      if (!isLoggedIn && goingProtected) return '/login';
      if (isLoggedIn && goingToAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => BlocProvider<AccountBloc>(
                  // 仪表盘需要账户聚合（净资产 / 资产分解），独立 bloc 实例。
                  create: (_) => getIt<AccountBloc>(),
                  child: const HomePage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/accounts',
                // 在路由层 provide AccountBloc + CurrencyBloc：
                //  - AccountBloc：Factory 注册，每次进入分支全新实例，离开释放。
                //  - CurrencyBloc：列表页总计/小计换算依赖 rates/preferred，
                //    create 时立即发起 LoadCurrencies + LoadPreferences 拉取汇率
                //    与用户偏好（与详情页一致）。
                builder: (_, __) => MultiBlocProvider(
                  providers: [
                    BlocProvider<AccountBloc>(
                      create: (_) => getIt<AccountBloc>(),
                    ),
                    BlocProvider<CurrencyBloc>(
                      create: (_) {
                        final b = getIt<CurrencyBloc>();
                        b.add(const LoadCurrenciesRequested());
                        b.add(const LoadPreferencesRequested());
                        return b;
                      },
                    ),
                  ],
                  child: const AccountsPage(),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    // 详情页用独立 bloc 实例：列表页 bloc 在跳转时被释放，
                    // 详情页需要自己的 AccountBloc 发起 GetAccountRequested。
                    //
                    // 同时在这里 provide 一个 account-scoped TransactionBloc
                    //（list accountId + summary accountId），因为详情页的
                    // _body() 用 State.context.watch<TransactionBloc>() ——
                    // State.context 在路由 BlocProvider 下才能被 watch 找到。
                    // 若只在 build 里自建 BlocProvider，其 child 是 Builder
                    // 的 context，而非 AccountDetailPage 自己的 State.context，
                    // 会触发 ProviderNotFoundException（runtime 崩）。
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      final now = DateTime.now();
                      return MultiBlocProvider(
                        providers: [
                          BlocProvider<AccountBloc>(
                            create: (_) => getIt<AccountBloc>(),
                          ),
                          BlocProvider<TransactionBloc>(
                            create: (_) {
                              final b = TransactionBloc(
                                  getIt<TransactionRepository>());
                              b.add(LoadTransactionsRequested(
                                  filter: TxnFilterState(accountId: id)));
                              b.add(LoadSummaryRequested(
                                  year: now.year,
                                  month: now.month,
                                  accountId: id));
                              return b;
                            },
                          ),
                        ],
                        child: AccountDetailPage(id: id),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                // 在路由层 provide TransactionBloc（与 /accounts/:id 详情页一致）。
                // TransactionsPage.build 之前在内部 try BlocProvider.of + 自建
                // 两段式回退，但 debug 模式下 BlocProvider.of 缺失时抛的是
                // AssertionError（非 ProviderNotFoundException），try/catch 漏接
                // → 运行时崩。把 provide 提到路由层后，页面 build 直接返回
                // _TransactionsView，State.context 一定在 Provider 下。
                builder: (_, __) => BlocProvider<TransactionBloc>(
                  create: (_) {
                    final b = TransactionBloc(
                        getIt<TransactionRepository>());
                    b.add(const LoadTransactionsRequested());
                    return b;
                  },
                  child: const TransactionsPage(),
                ),
                routes: [
                  GoRoute(
                    path: 'new',
                    // TransactionFormPage 内部自建 BlocProvider<TransactionFormBloc>。
                    builder: (_, __) => const TransactionFormPage(),
                  ),
                  GoRoute(
                    path: ':id',
                    // TransactionDetailPage 在 initState 里
                    // context.read<TransactionBloc>() 触发 LoadTransactionDetail，
                    // 故这里必须 provide TransactionBloc（否则 ProviderNotFoundException）。
                    builder: (context, state) =>
                        BlocProvider<TransactionBloc>(
                      create: (_) => TransactionBloc(
                          getIt<TransactionRepository>()),
                      child: TransactionDetailPage(
                          id: state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/categories',
                // CategoryManagementPage 从树里读 CategoryBloc（无 getIt 工厂），
                // 故这里 provide。四个 use case 均经 injectable 注册。
                builder: (_, __) => BlocProvider<CategoryBloc>(
                  create: (_) => CategoryBloc(
                    getIt<ListAccountsUseCase>(),
                    getIt<CreateAccountUseCase>(),
                    getIt<DeleteAccountUseCase>(),
                    getIt<UpdateAccountUseCase>(),
                  ),
                  child: const CategoryManagementPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/debts',
                // 列表页：路由层 provide DebtBloc，进入即拉 borrowedIn 过滤的
                // LoadDebtsRequested（仅借入/负债；债权/借出归 /receivables，
                // 对齐 receivables 分支的 borrowedOut 过滤）。
                builder: (_, __) => MultiBlocProvider(
                  providers: [
                    BlocProvider<DebtBloc>(
                      create: (_) {
                        final b = DebtBloc(getIt<DebtRepository>());
                        b.add(const LoadDebtsRequested(
                            typeFilter: DebtType.borrowedIn));
                        return b;
                      },
                    ),
                    // DebtsPage._content 用 CurrencyBloc 做总计换算(toPreferred),
                    // 需 provide(对齐 /accounts MultiBlocProvider)。
                    BlocProvider<CurrencyBloc>(
                      create: (_) {
                        final b = getIt<CurrencyBloc>();
                        b.add(const LoadCurrenciesRequested());
                        b.add(const LoadPreferencesRequested());
                        return b;
                      },
                    ),
                  ],
                  child: const DebtsPage(),
                ),
                routes: [
                  GoRoute(
                    path: 'new',
                    // 表单页 context.read<DebtBloc>() 触发 CreateDebtRequested，
                    // 嵌套路由是 /debts 的兄弟子树（非 DebtsPage 子节点），
                    // 不能继承 /debts builder 的 BlocProvider，故这里独立 provide。
                    builder: (_, __) => BlocProvider<DebtBloc>(
                      create: (_) => DebtBloc(getIt<DebtRepository>()),
                      child: const DebtFormPage(),
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    // 详情页用独立 DebtBloc（列表页 bloc 在跳转时被释放），
                    // 进入即 LoadDebtRequested(id)，对齐 /accounts/:id 独立 AccountBloc。
                    builder: (_, state) => MultiBlocProvider(
                      providers: [
                        BlocProvider<DebtBloc>(
                          create: (_) {
                            final id = state.pathParameters['id']!;
                            final b = DebtBloc(getIt<DebtRepository>());
                            b.add(LoadDebtRequested(id));
                            return b;
                          },
                        ),
                        // DebtDetailPage 用 CurrencyBloc 换算(_fmtSymbol)。
                        BlocProvider<CurrencyBloc>(
                          create: (_) {
                            final b = getIt<CurrencyBloc>();
                            b.add(const LoadCurrenciesRequested());
                            b.add(const LoadPreferencesRequested());
                            return b;
                          },
                        ),
                      ],
                      child: DebtDetailPage(id: state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/receivables',
                // 债权列表（branch 4）：与 /debts 同构，但 DebtBloc 以
                // LoadDebtsRequested(typeFilter: borrowedOut) 仅取借出方向。
                // CurrencyBloc 提供总计/小计换算（对齐 /debts /accounts）。
                builder: (_, __) => MultiBlocProvider(
                  providers: [
                    BlocProvider<DebtBloc>(
                      create: (_) {
                        final b = DebtBloc(getIt<DebtRepository>());
                        b.add(const LoadDebtsRequested(
                            typeFilter: DebtType.borrowedOut));
                        return b;
                      },
                    ),
                    BlocProvider<CurrencyBloc>(
                      create: (_) {
                        final b = getIt<CurrencyBloc>();
                        b.add(const LoadCurrenciesRequested());
                        b.add(const LoadPreferencesRequested());
                        return b;
                      },
                    ),
                  ],
                  child: const ReceivablesPage(),
                ),
                routes: [
                  GoRoute(
                    path: 'new',
                    // 表单页：嵌套路由是 /receivables 的兄弟子树，不继承
                    // /receivables builder 的 BlocProvider，故独立 provide。
                    // type 在表单内部固定 borrowedOut（Task 9）。
                    builder: (_, __) => BlocProvider<DebtBloc>(
                      create: (_) => DebtBloc(getIt<DebtRepository>()),
                      child: const ReceivableFormPage(),
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    // 详情页用独立 DebtBloc，进入即 LoadDebtRequested(id)，
                    // 对齐 /debts/:id。
                    builder: (_, state) => MultiBlocProvider(
                      providers: [
                        BlocProvider<DebtBloc>(
                          create: (_) {
                            final b = DebtBloc(getIt<DebtRepository>());
                            b.add(LoadDebtRequested(state.pathParameters['id']!));
                            return b;
                          },
                        ),
                        // ReceivableDetailPage 用 CurrencyBloc 换算。
                        BlocProvider<CurrencyBloc>(
                          create: (_) {
                            final b = getIt<CurrencyBloc>();
                            b.add(const LoadCurrenciesRequested());
                            b.add(const LoadPreferencesRequested());
                            return b;
                          },
                        ),
                      ],
                      child: ReceivableDetailPage(id: state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // 持仓管理（branch 5）：对齐 /debts /receivables 模板。
          // 列表页 provide HoldingBloc（factory 注册）+ CurrencyBloc（多币种换算）。
          // ⚠️ 子路由顺序：静态路径(security/performance/goals/trade/new)必须在
          //    :id 之前(GoRouter 匹配优先级,否则被 :id 捕获)。
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/holdings',
                builder: (_, __) => MultiBlocProvider(
                  providers: [
                    BlocProvider<HoldingBloc>(
                      create: (_) {
                        final b = HoldingBloc(getIt<HoldingRepository>());
                        b.add(const LoadHoldingsRequested());
                        return b;
                      },
                    ),
                    BlocProvider<CurrencyBloc>(
                      create: (_) {
                        final b = getIt<CurrencyBloc>();
                        b.add(const LoadCurrenciesRequested());
                        b.add(const LoadPreferencesRequested());
                        return b;
                      },
                    ),
                  ],
                  child: const HoldingsPage(),
                ),
                routes: [
                  // 静态子路由(必须在 :id 前)。
                  GoRoute(
                    path: 'security',
                    // Security 管理(Task 7):独立 HoldingBloc,进入即拉证券主数据。
                    builder: (_, __) => BlocProvider<HoldingBloc>(
                      create: (_) {
                        final b = HoldingBloc(getIt<HoldingRepository>());
                        b.add(const LoadSecuritiesRequested());
                        return b;
                      },
                      child: const SecurityPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'performance',
                    // 收益统计(Task 9 列表数据 + Task 13 收益曲线 PerformanceBloc)。
                    // PerformanceBloc 进入即拉组合曲线/盈亏明细(initState dispatch)。
                    builder: (_, __) => MultiBlocProvider(
                      providers: [
                        BlocProvider<HoldingBloc>(
                          create: (_) {
                            final b = HoldingBloc(getIt<HoldingRepository>());
                            b.add(const LoadHoldingsRequested());
                            return b;
                          },
                        ),
                        BlocProvider<PerformanceBloc>(
                          create: (_) => getIt<PerformanceBloc>(),
                        ),
                        BlocProvider<CurrencyBloc>(
                          create: (_) {
                            final b = getIt<CurrencyBloc>();
                            b.add(const LoadCurrenciesRequested());
                            b.add(const LoadPreferencesRequested());
                            return b;
                          },
                        ),
                      ],
                      child: const PerformancePage(),
                    ),
                  ),
                  GoRoute(
                    path: 'goals',
                    // 目标关联(Task 10):holding.proto 无 goal RPC,整页 ⏳D 空态,
                    // 仅关联 holding 选择可从已加载 holdings 渲染。
                    builder: (_, __) => MultiBlocProvider(
                      providers: [
                        BlocProvider<HoldingBloc>(
                          create: (_) {
                            final b = HoldingBloc(getIt<HoldingRepository>());
                            b.add(const LoadHoldingsRequested());
                            return b;
                          },
                        ),
                        BlocProvider<CurrencyBloc>(
                          create: (_) {
                            final b = getIt<CurrencyBloc>();
                            b.add(const LoadCurrenciesRequested());
                            b.add(const LoadPreferencesRequested());
                            return b;
                          },
                        ),
                      ],
                      child: const GoalLinkPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'trade',
                    // 交易 Sheet(Task 6,modal/sheet):接收 extra:{type}
                    // (TradeType.name 预选 buy/sell/dividend/split)。
                    builder: (_, state) {
                      final typeArg = state.extra is Map
                          ? (state.extra as Map)['type'] as String?
                          : null;
                      final initialType = TradeType.values.firstWhere(
                        (t) => t.name == typeArg,
                        orElse: () => TradeType.buy,
                      );
                      return BlocProvider<HoldingBloc>(
                        create: (_) {
                          final b = HoldingBloc(getIt<HoldingRepository>());
                          b.add(const LoadSecuritiesRequested());
                          return b;
                        },
                        child: TradeSheetPage(initialType: initialType),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'new',
                    // FAB「+」(holdings_page)→ trade sheet 默认 buy(对齐 Task 5
                    // 用的 /holdings/new 路径,映射到创建/买入流程)。
                    builder: (_, __) => BlocProvider<HoldingBloc>(
                      create: (_) {
                        final b = HoldingBloc(getIt<HoldingRepository>());
                        b.add(const LoadSecuritiesRequested());
                        return b;
                      },
                      child: const TradeSheetPage(),
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    // 详情(Task 8):独立 HoldingBloc,进入即 LoadDetailRequested(id)。
                    builder: (_, state) => MultiBlocProvider(
                      providers: [
                        BlocProvider<HoldingBloc>(
                          create: (_) {
                            final id = state.pathParameters['id']!;
                            final b = HoldingBloc(getIt<HoldingRepository>());
                            b.add(LoadDetailRequested(id));
                            return b;
                          },
                        ),
                        BlocProvider<CurrencyBloc>(
                          create: (_) {
                            final b = getIt<CurrencyBloc>();
                            b.add(const LoadCurrenciesRequested());
                            b.add(const LoadPreferencesRequested());
                            return b;
                          },
                        ),
                      ],
                      child: HoldingDetailPage(id: state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // 设置页：顶层路由（非 shell 分支），从侧栏「设置」直接进入。
      // 独立 CurrencyBloc 实例，进入即拉取 currencies + preferences 渲染 dropdown。
      GoRoute(
        path: '/settings',
        builder: (_, __) => MultiBlocProvider(
          providers: [
            BlocProvider<CurrencyBloc>(
              create: (_) {
                final b = getIt<CurrencyBloc>();
                b.add(const LoadCurrenciesRequested());
                b.add(const LoadPreferencesRequested());
                return b;
              },
            ),
          ],
          child: const SettingsPage(),
        ),
      ),
    ],
    initialLocation: '/home',
  );
}

/// Bridges Bloc stream → ChangeNotifier so GoRouter re-evaluates redirect on auth changes.
class _AuthBlocListenable extends ChangeNotifier {
  _AuthBlocListenable(AuthBloc bloc) {
    _sub = bloc.stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
