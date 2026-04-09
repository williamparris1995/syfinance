import { Outlet, createRootRoute, createRoute, createRouter } from '@tanstack/react-router';
import { AppLayout } from './components/layout/AppLayout';
import { AccountsPage } from './pages/AccountsPage';
import { DebtsPage } from './pages/DebtsPage';
import { HomePage } from './pages/HomePage';
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
});

const debtsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'debts',
  component: DebtsPage,
});

const reportsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'reports',
  component: ReportsPage,
});

const settingsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'settings',
  component: SettingsPage,
});

const routeTree = rootRoute.addChildren([
  homeRoute,
  accountsRoute,
  transactionsRoute,
  debtsRoute,
  reportsRoute,
  settingsRoute,
]);

export const router = createRouter({
  routeTree,
});

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router;
  }
}
