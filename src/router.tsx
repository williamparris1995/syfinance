import { Outlet, createRootRoute, createRoute, createRouter, redirect } from '@tanstack/react-router';
import { z } from 'zod';
import { AppLayout } from './components/layout/AppLayout';
import { isRegistered } from './lib/auth';
import { AccountsPage } from './pages/AccountsPage';
import { BackupPage } from './pages/BackupPage';
import { BudgetPage } from './pages/BudgetPage';
import { DebtsPage } from './pages/DebtsPage';
import { GoalsPage } from './pages/GoalsPage';
import { HoldingsPage } from './pages/HoldingsPage';
import { HomePage } from './pages/HomePage';
import { RemindersPage } from './pages/RemindersPage';
import { TransactionTemplatesPage } from './pages/TransactionTemplatesPage';
import { NewAccountPage } from './pages/NewAccountPage';
import { NewDebtPage } from './pages/NewDebtPage';
import { NewTransactionPage } from './pages/NewTransactionPage';
import { OnboardingPage } from './pages/OnboardingPage';
import { ReportsPage } from './pages/ReportsPage';
import { SettingsPage } from './pages/SettingsPage';
import { TransactionsPage } from './pages/TransactionsPage';

function RootLayout() {
  return (
    <AppLayout>
      <Outlet />
    </AppLayout>
  );
}

const rootRoute = createRootRoute({
  component: RootLayout,
  beforeLoad: async ({ location }) => {
    const registered = await isRegistered();
    if (!registered && location.pathname !== '/onboarding') {
      throw redirect({ to: '/onboarding' });
    }
    if (registered && location.pathname === '/onboarding') {
      throw redirect({ to: '/' });
    }
  },
});

const homeRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/',
  component: HomePage,
});

const accountsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'accounts',
  component: AccountsPage,
});

const transactionsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'transactions',
  component: TransactionsPage,
  validateSearch: z.object({
    accountId: z.string().optional(),
    startDate: z.string().optional(),
    endDate: z.string().optional(),
  }),
});

const debtsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'debts',
  component: DebtsPage,
});

const holdingsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'holdings',
  component: HoldingsPage,
});

const remindersRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'reminders',
  component: RemindersPage,
});

const transactionTemplatesRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'transaction-templates',
  component: TransactionTemplatesPage,
});

const budgetRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'budget',
  component: BudgetPage,
});

const goalsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'goals',
  component: GoalsPage,
});

const reportsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'reports',
  component: ReportsPage,
});

const backupRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'backup',
  component: BackupPage,
});

const settingsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'settings',
  component: SettingsPage,
});

const newTransactionRoute = createRoute({
  getParentRoute: () => transactionsRoute,
  path: 'new',
  component: NewTransactionPage,
});

const newAccountRoute = createRoute({
  getParentRoute: () => accountsRoute,
  path: 'new',
  component: NewAccountPage,
});

const newDebtRoute = createRoute({
  getParentRoute: () => debtsRoute,
  path: 'new',
  component: NewDebtPage,
});

const onboardingRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'onboarding',
  component: OnboardingPage,
});

const routeTree = rootRoute.addChildren([
  homeRoute,
  accountsRoute.addChildren([newAccountRoute]),
  transactionsRoute.addChildren([newTransactionRoute]),
  debtsRoute.addChildren([newDebtRoute]),
  holdingsRoute,
  remindersRoute,
  transactionTemplatesRoute,
  budgetRoute,
  goalsRoute,
  reportsRoute,
  backupRoute,
  settingsRoute,
  onboardingRoute,
]);

export const router = createRouter({
  routeTree,
});

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router;
  }
}
