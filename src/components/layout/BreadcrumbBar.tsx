import { Link, useRouterState } from '@tanstack/react-router';
import { ChevronRight, Home } from 'lucide-react';
import { useTranslation } from 'react-i18next';

export interface BreadcrumbItem {
  label: string;
  to?: string;
}

interface BreadcrumbBarProps {
  items?: BreadcrumbItem[];
}

const routeLabelMap: Record<string, string> = {
  accounts: 'nav.accounts',
  transactions: 'nav.transactions',
  holdings: 'nav.holdings',
  debts: 'nav.debts',
  budget: 'nav.budget',
  goals: 'nav.goals',
  reports: 'nav.reports',
  settings: 'nav.settings',
  categories: 'nav.categories',
  'transaction-templates': 'nav.recurring',
  reminders: 'nav.reminders',
  new: 'common.new',
  edit: 'common.edit',
};

function generateBreadcrumbs(pathname: string, t: (key: string) => string): BreadcrumbItem[] {
  const segments = pathname.split('/').filter(Boolean);
  const items: BreadcrumbItem[] = [];
  let accumulatedPath = '';

  for (let i = 0; i < segments.length; i++) {
    const seg = segments[i];
    accumulatedPath += `/${seg}`;

    // Skip dynamic segments (UUIDs or long IDs)
    if (seg.match(/^[0-9a-f-]{20,}$/)) {
      continue;
    }

    const labelKey = routeLabelMap[seg];
    const isLast = i === segments.length - 1;

    items.push({
      label: labelKey ? t(labelKey) : seg,
      to: isLast ? undefined : accumulatedPath,
    });
  }

  return items;
}

export function BreadcrumbBar({ items }: BreadcrumbBarProps) {
  const { t } = useTranslation();
  const routerState = useRouterState();
  const pathname = routerState.location.pathname;
  const breadcrumbs: BreadcrumbItem[] = items ?? generateBreadcrumbs(pathname, t);

  if (breadcrumbs.length === 0) return null;

  return (
    <nav className="flex items-center gap-2 text-sm">
      <Link
        to="/"
        className="text-muted-foreground/60 transition-colors hover:text-primary"
      >
        <Home className="h-3.5 w-3.5" />
      </Link>
      {breadcrumbs.map((item, i) => (
        <span key={i} className="flex items-center gap-2">
          <ChevronRight className="h-3 w-3 text-border" />
          {item.to ? (
            <Link
              to={item.to}
              className="text-muted-foreground transition-colors hover:text-primary"
            >
              {item.label}
            </Link>
          ) : (
            <span className="font-medium text-foreground">{item.label}</span>
          )}
        </span>
      ))}
    </nav>
  );
}
