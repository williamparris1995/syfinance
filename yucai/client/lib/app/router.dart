import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/app/route_observer.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/pages/account_detail_page.dart';
import 'package:yucai_client/account/presentation/pages/accounts_page.dart';
import 'package:yucai_client/app/widgets/app_shell.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_bloc.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_event.dart'
    as budget_event;
import 'package:yucai_client/budget/presentation/pages/budget_detail_page.dart';
import 'package:yucai_client/budget/presentation/pages/budget_form_page.dart';
import 'package:yucai_client/budget/presentation/pages/budget_list_page.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/auth/presentation/pages/home_page.dart';
import 'package:yucai_client/auth/presentation/pages/login_page.dart';
import 'package:yucai_client/auth/presentation/pages/register_page.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_state.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/pages/debt_detail_page.dart';
import 'package:yucai_client/debt/presentation/pages/debt_form_page.dart';
import 'package:yucai_client/debt/presentation/pages/debts_page.dart';
import 'package:yucai_client/debt/presentation/pages/receivable_detail_page.dart';
import 'package:yucai_client/debt/presentation/pages/receivable_form_page.dart';
import 'package:yucai_client/debt/presentation/pages/receivables_page.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_bloc.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_event.dart' as goal_event;
import 'package:yucai_client/goal/presentation/pages/goal_detail_page.dart';
import 'package:yucai_client/goal/presentation/pages/goal_form_page.dart';
import 'package:yucai_client/goal/presentation/pages/goal_list_page.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
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
import 'package:yucai_client/backup/presentation/bloc/backup_bloc.dart';
import 'package:yucai_client/backup/presentation/pages/backup_page.dart';
import 'package:yucai_client/tag/presentation/bloc/tag_bloc.dart';
import 'package:yucai_client/tag/presentation/pages/tag_page.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/presentation/bloc/category_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_state.dart';
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
          state.matchedLocation.startsWith('/budgets') ||
          state.matchedLocation.startsWith('/goals') ||
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
                    routes: [
                      GoRoute(
                        path: 'edit',
                        // 编辑：独立 TransactionBloc 加载该交易，Loaded 后用
                        // TransactionFormPage(existing:) edit 模式渲染（提交走
                        // UpdateTransactionRequested → repo.update）。复合多分录
                        //（>2 / 不平衡）三栏表单无法表达 → 提示页，避免 update 丢分录。
                        builder: (context, state) =>
                            BlocProvider<TransactionBloc>(
                          create: (_) {
                            final b = TransactionBloc(
                                getIt<TransactionRepository>());
                            b.add(LoadTransactionDetail(
                                state.pathParameters['id']!));
                            return b;
                          },
                          child: BlocBuilder<TransactionBloc,
                              TransactionState>(
                            buildWhen: (p, c) =>
                                c is TransactionDetailLoading ||
                                c is TransactionDetailLoaded ||
                                c is TransactionDetailError,
                            builder: (ctx, st) {
                              if (st is TransactionDetailLoaded) {
                                final txn = st.transaction;
                                if (txn.entries.length != 2 ||
                                    !txn.isBalanced) {
                                  return _compoundTxnEditNotice(ctx);
                                }
                                return TransactionFormPage(existing: txn);
                              }
                              if (st is TransactionDetailError) {
                                return Scaffold(
                                  backgroundColor: AppColors.bg,
                                  body: Center(
                                      child: Text('加载失败：${st.message}')),
                                );
                              }
                              return const Scaffold(
                                body: Center(
                                    child: CircularProgressIndicator()),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
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
                    routes: [
                      GoRoute(
                        path: 'edit',
                        // 编辑表单:DebtFormPage(existing: debt) edit mode,
                        // 对齐 /receivables/:id/edit 模式。DebtBloc 由本 route provide,
                        // 表单提交走 UpdateDebtRequested。
                        builder: (_, state) => MultiBlocProvider(
                          providers: [
                            BlocProvider<DebtBloc>(
                              create: (_) {
                                final b = DebtBloc(getIt<DebtRepository>());
                                b.add(LoadDebtRequested(
                                    state.pathParameters['id']!));
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
                          child: BlocBuilder<DebtBloc, DebtState>(
                            builder: (ctx, st) {
                              if (st is DebtDetailLoaded) {
                                return DebtFormPage(existing: st.detail.debt);
                              }
                              return const Center(
                                  child: CircularProgressIndicator());
                            },
                          ),
                        ),
                      ),
                    ],
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
                    routes: [
                      GoRoute(
                        path: 'edit',
                        // 编辑表单:ReceivableFormPage(existing: debt) edit mode。
                        // LoadDebtRequested 后 DebtDetailLoaded 时构造 FormPage 预填,
                        // 对齐 /budgets/:id/edit 模式。DebtBloc 由本 route provide,
                        // 表单提交走 UpdateDebtRequested。
                        builder: (_, state) => MultiBlocProvider(
                          providers: [
                            BlocProvider<DebtBloc>(
                              create: (_) {
                                final b = DebtBloc(getIt<DebtRepository>());
                                b.add(LoadDebtRequested(
                                    state.pathParameters['id']!));
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
                          child: BlocBuilder<DebtBloc, DebtState>(
                            builder: (ctx, st) {
                              if (st is DebtDetailLoaded) {
                                return ReceivableFormPage(
                                    existing: st.detail.debt);
                              }
                              if (st is DebtError) {
                                return Scaffold(
                                  body: Center(
                                      child: Text('加载失败：${st.message}')),
                                );
                              }
                              return const Scaffold(
                                body: Center(
                                    child: CircularProgressIndicator()),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // 持仓管理(branch 5):页内 tab 导航(各页自带 HoldingModuleTabs)。
          // 回退二级侧栏(SubMenuShell);子路由:/holdings + children。
          // ⚠️ 静态(trade/new/security/performance/goals)在 :id 前(GoRouter 匹配优先级,
          // 否则 trade/new 等被 :id 捕获渲染成 HoldingDetailPage)。
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
                  GoRoute(
                    path: 'trade',
                    // 操作 sheet:extra 可带 type(buy/sell)决定初始 TradeType,
                    // 默认 buy。HoldingBloc 进入即拉证券主数据(证券选择器)。
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
                    // 录入入口(默认 buy):与 trade 同构造,无 extra。
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
                    path: 'security',
                    // Security 管理:独立 HoldingBloc,进入即拉证券主数据。
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
                    // 收益统计:PerformanceBloc 进入即拉组合曲线/盈亏明细。
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
                    // 目标关联:extra 传 holding(含 accountId + marketValueCents)。
                    builder: (_, state) {
                      final holding = state.extra is Map
                          ? (state.extra as Map)['holding'] as Holding?
                          : null;
                      return MultiBlocProvider(
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
                        child: GoalLinkPage(
                          holding: holding ??
                              const Holding(
                                id: '',
                                accountId: '',
                                securityId: '',
                                securityName: '',
                                securitySymbol: '',
                                quantity: 0,
                                avgCostCents: 0,
                                marketValueCents: 0,
                                unrealizedPnlCents: 0,
                                version: 0,
                              ),
                          goalRepo: getIt<HoldingRepository>(),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    // 详情(Task 8):HoldingBloc 进入即 LoadDetailRequested(id)。
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
          // 预算管理（branch 6）：对齐 /holdings /debts 模板。列表/详情页
          // provide BudgetBloc（factory 注册，Task 7）。子路由顺序：静态 `/new`
          // 必须在 `/:id` 前（GoRouter 匹配优先级，否则被 :id 捕获；与 holdings
          // branch 一致）。
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/budgets',
                // 列表页：路由层 provide BudgetBloc，进入即拉 LoadListRequested
                //（BudgetListPage.initState 也会 dispatch 同样事件，双重保险：
                // 路由层先发，页面 initState 再发一次幂等）。
                builder: (_, __) => BlocProvider<BudgetBloc>(
                  create: (_) {
                    final b = getIt<BudgetBloc>();
                    b.add(const budget_event.LoadListRequested());
                    return b;
                  },
                  child: const BudgetListPage(),
                ),
                routes: [
                  // 静态子路由（必须在 :id 前）。
                  GoRoute(
                    path: 'new',
                    // 创建表单：BudgetFormPage(budgetId: null) = 创建模式。
                    // 表单 _loadAccounts 读 GetIt<AccountRepository>（已注册），
                    // 创建模式不读 BudgetBloc（_isEdit == false），但 BlocConsumer
                    // 在树里需要 BlocProvider 祖先 → provide 一个独立实例。
                    builder: (_, __) => BlocProvider<BudgetBloc>(
                      create: (_) => getIt<BudgetBloc>(),
                      child: const BudgetFormPage(),
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    // 详情页：独立 BudgetBloc，进入即 LoadDetailRequested(id)。
                    builder: (_, state) => BlocProvider<BudgetBloc>(
                      create: (_) {
                        final id = state.pathParameters['id']!;
                        final b = getIt<BudgetBloc>();
                        b.add(budget_event.LoadDetailRequested(id));
                        return b;
                      },
                      child: BudgetDetailPage(id: state.pathParameters['id']!),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        // 编辑表单：BudgetFormPage(budgetId: id) = 编辑模式，
                        // _loadExisting 会 context.read<BudgetBloc>() → provide。
                        builder: (_, state) => BlocProvider<BudgetBloc>(
                          create: (_) {
                            final id = state.pathParameters['id']!;
                            final b = getIt<BudgetBloc>();
                            b.add(budget_event.LoadDetailRequested(id));
                            return b;
                          },
                          child: BudgetFormPage(
                            budgetId: state.pathParameters['id'],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // 目标管理（branch 7）：对齐 /budgets 模板。列表/详情/表单页
          // provide GoalBloc（factory 注册，Task 11）。子路由顺序：静态 `/new`
          // 必须在 `/:id` 前（GoRouter 匹配优先级，否则被 :id 捕获；与 budgets
          // branch 一致）。
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/goals',
                // 列表页：路由层 provide GoalBloc，进入即拉 LoadListRequested
                //（GoalListPage.initState 也会 dispatch 同样事件，双重保险：
                // 路由层先发，页面 initState 再发一次幂等）。
                builder: (_, __) => BlocProvider<GoalBloc>(
                  create: (_) {
                    final b = GoalBloc(getIt<GoalRepository>());
                    b.add(const goal_event.LoadListRequested());
                    return b;
                  },
                  child: const GoalListPage(),
                ),
                routes: [
                  // 静态子路由（必须在 :id 前）。
                  GoRoute(
                    path: 'new',
                    // 创建表单：GoalFormPage(goalId: null) = 创建模式。
                    // 表单 _loadAccounts 读 GetIt<AccountRepository>，_loadDebts
                    // 读 GetIt<DebtRepository>（均注册）。创建模式不读 GoalBloc，
                    // 但 BlocConsumer 在树里需要 BlocProvider 祖先 → provide 独立实例。
                    builder: (_, __) => BlocProvider<GoalBloc>(
                      create: (_) => GoalBloc(getIt<GoalRepository>()),
                      child: const GoalFormPage(),
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    // 详情页：独立 GoalBloc，进入即 LoadDetailRequested(id)。
                    builder: (_, state) => BlocProvider<GoalBloc>(
                      create: (_) {
                        final id = state.pathParameters['id']!;
                        final b = GoalBloc(getIt<GoalRepository>());
                        b.add(goal_event.LoadDetailRequested(id));
                        return b;
                      },
                      child: GoalDetailPage(id: state.pathParameters['id']!),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        // 编辑表单：GoalFormPage(goalId: id) = 编辑模式，
                        // _loadExisting 会 context.read<GoalBloc>() → provide。
                        builder: (_, state) => BlocProvider<GoalBloc>(
                          create: (_) {
                            final id = state.pathParameters['id']!;
                            final b = GoalBloc(getIt<GoalRepository>());
                            b.add(goal_event.LoadDetailRequested(id));
                            return b;
                          },
                          child: GoalFormPage(
                            goalId: state.pathParameters['id'],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // 设置作为 shell branch 8(集成 sidebar/topbar 体系;独立 CurrencyBloc
          // 进入即拉 currencies + preferences 渲染 dropdown)。
          StatefulShellBranch(
            routes: [
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
                // 本地备份子页：静态路径「backup」，无 :id 冲突；BackupBloc
                // 在路由 builder 层 provide（对齐 budgets branch 模式）。
                routes: [
                  GoRoute(
                    path: 'backup',
                    builder: (_, __) => BlocProvider<BackupBloc>(
                      create: (_) => getIt<BackupBloc>(),
                      child: const BackupPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'tags',
                    // 标签管理子页：静态路径「tags」，无 :id 冲突；TagBloc
                    // 在路由 builder 层 provide（对齐 backup 子路由模式）。
                    builder: (_, __) => BlocProvider<TagBloc>(
                      create: (_) => getIt<TagBloc>(),
                      child: const TagPage(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    initialLocation: '/home',
  );
}

/// 复合多分录交易（>2 entry 或不平衡）编辑提示页 —— 三栏表单（SimpleExpense/
/// Income/Transfer）只能表达 2-entry 形态，对复合分录强行 update 会丢分录。
/// 在 form-page 支持任意分录编辑前，路由层拦截并提示用户。
Scaffold _compoundTxnEditNotice(BuildContext context) {
  return Scaffold(
    backgroundColor: AppColors.bg,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.info, size: 32, color: AppColors.accent),
              const SizedBox(height: AppSpacing.sm),
              const Text('该交易为复合分录',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.fg)),
              const SizedBox(height: 6),
              const Text(
                '多分录交易暂不支持在表单中编辑，以免修改时丢失分录行。可在详情页删除后重新记一笔。',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      ),
    ),
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
