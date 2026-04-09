import { Outlet, createRootRoute, createRoute, createRouter } from '@tanstack/react-router';
import { Sidebar } from './components/Sidebar';
import { AccountsPage } from './pages/AccountsPage';
import { DebtsPage } from './pages/DebtsPage';
import { HomePage } from './pages/HomePage';
import { ReportsPage } from './pages/ReportsPage';
import { SettingsPage } from './pages/SettingsPage';
import { TransactionsPage } from './pages/TransactionsPage';

function RootLayout() {
  return (
    <div className="flex min-h-screen bg-slate-950 text-slate-100">
      <Sidebar />
      <main className="flex-1 px-8 py-6">
        <Outlet />
      </main>
    </div>
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
