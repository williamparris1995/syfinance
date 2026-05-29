import { useTranslation } from 'react-i18next';

type RouteShellProps = {
  title: string;
};

export function RouteShell({ title }: RouteShellProps) {
  const { t } = useTranslation();
  return (
    <section className="space-y-3">
      <h1 className="text-3xl font-semibold text-slate-50">{title}</h1>
      <p className="text-sm text-slate-400">{t('common.routeShell')}</p>
    </section>
  );
}
