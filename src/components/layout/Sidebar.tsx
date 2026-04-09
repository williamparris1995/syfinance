import { Link } from '@tanstack/react-router';

export function Sidebar() {
  return (
    <aside className="w-64 border-r bg-card">
      <nav className="flex flex-col gap-2 p-4">
        <Link
          to="/"
          className="rounded-lg px-3 py-2 text-sm font-medium hover:bg-accent"
        >
          Dashboard
        </Link>
        <Link
          to="/transactions"
          className="rounded-lg px-3 py-2 text-sm font-medium hover:bg-accent"
        >
          Transactions
        </Link>
        <Link
          to="/accounts"
          className="rounded-lg px-3 py-2 text-sm font-medium hover:bg-accent"
        >
          Accounts
        </Link>
      </nav>
    </aside>
  );
}
