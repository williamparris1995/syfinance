import { useTranslation } from 'react-i18next';
import { PageShell } from '@/components/patterns/layout/PageShell';
import { PageHeader } from '@/components/patterns/layout/PageHeader';

export function AccountDetailPage() {
  const { t } = useTranslation();
  return (
    <PageShell>
      <PageHeader title={t('accounts.detailTitle')} subtitle={t('common.routeShell')} />
    </PageShell>
  );
}
