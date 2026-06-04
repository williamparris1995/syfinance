import { ReactNode, useState } from 'react';
import { Sidebar } from '@/components/sidebar';
import { Header } from './Header';
import { cn } from '@/lib/utils';

interface AppLayoutProps {
  children: ReactNode;
}

export function AppLayout({ children }: AppLayoutProps) {
  const [sidebarOpen, setSidebarOpen] = useState(false); // Mobile: show/hide
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false); // Desktop: expand/collapse

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      {/* Sidebar - Desktop: always visible (can be collapsed), Mobile: overlay */}
      <div
        className={cn(
          "fixed inset-y-0 left-0 z-50 transform transition-all duration-300 ease-in-out lg:relative lg:translate-x-0",
          sidebarOpen ? "translate-x-0" : "-translate-x-full",
          sidebarCollapsed ? "lg:w-16" : "lg:w-64",
          "w-64" // Mobile always full width when open
        )}
      >
        <Sidebar 
          collapsed={sidebarCollapsed}
          onNavigate={() => setSidebarOpen(false)} 
        />
      </div>

      {/* Overlay for mobile */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/50 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Main content area */}
      <div className="flex flex-1 flex-col overflow-hidden">
        {/* Header with configurable components */}
        <Header
          onSidebarToggle={() => {
            // Mobile: toggle open/close
            // Desktop: toggle collapse/expand
            if (window.innerWidth < 1024) {
              setSidebarOpen(!sidebarOpen);
            } else {
              setSidebarCollapsed(!sidebarCollapsed);
            }
          }}
          user={{
            name: 'User',
            email: 'user@example.com',
            initials: 'U',
          }}
        />

        {/* Content area */}
        <main className="flex-1 overflow-y-auto">
          {children}
        </main>
      </div>
    </div>
  );
}
