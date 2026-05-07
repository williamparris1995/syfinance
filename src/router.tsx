import { Outlet, createRootRoute, createRoute, createRouter, redirect } from '@tanstack/react-router';
import { AppLayout } from './components/layout/AppLayout';
import { isRegistered } from './lib/auth';
import { AccountsPage } from './pages/AccountsPage';
import { DebtsPage } from './pages/DebtsPage';
import { HomePage } from './pages/HomePage';
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

const onboardingRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'onboarding',
  component: OnboardingPage,
});

const routeTree = rootRoute.addChildren([
  homeRoute,
  accountsRoute,
  transactionsRoute,
  debtsRoute,
  reportsRoute,
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
