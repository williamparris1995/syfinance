import { Link } from '@tanstack/react-router';

type NavItem = {
  to: '/' | '/accounts' | '/transactions' | '/debts' | '/reports' | '/settings';
  label: string;
  exact?: boolean;
};

const navItems: NavItem[] = [
  { to: '/', label: 'Overview', exact: true },
  { to: '/accounts', label: 'Accounts' },
  { to: '/transactions', label: 'Transactions' },
  { to: '/debts', label: 'Debts' },
  { to: '/reports', label: 'Reports' },
  { to: '/settings', label: 'Settings' },
] as const;

export function Sidebar() {
  return (
    <aside className="w-64 border-r border-slate-800 bg-slate-900/80 px-4 py-6">
      <div className="mb-6">
        <p className="text-xs uppercase tracking-[0.3em] text-emerald-400">Finance App</p>
        <h1 className="mt-2 text-xl font-semibold text-slate-50">Navigation</h1>
      </div>
      <nav className="space-y-2">
        {navItems.map((item) => (
          <Link
            key={item.to}
            to={item.to}
            activeOptions={item.exact ? { exact: true } : undefined}
            activeProps={{
              className: 'bg-emerald-400 text-slate-950 shadow-sm shadow-emerald-500/20',
            }}
            className="block rounded-lg px-3 py-2 text-sm font-medium text-slate-300 transition hover:bg-slate-800 hover:text-slate-50"
          >
            {item.label}
          </Link>
        ))}
      </nav>
    </aside>
  );
}
