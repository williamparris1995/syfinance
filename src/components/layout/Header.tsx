import { SyncStatus } from '../SyncStatus';

export function Header() {
  return (
    <header className="border-b bg-card">
      <div className="flex h-16 items-center justify-between px-6">
        <h1 className="text-xl font-semibold">Finance App</h1>
        <SyncStatus />
      </div>
    </header>
  );
}
