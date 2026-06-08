import { useTranslation } from 'react-i18next';
import { PageShell } from '@/components/patterns/layout/PageShell';
import { PageHeader } from '@/components/patterns/layout/PageHeader';

export function GoalDetailPage() {
  const { t } = useTranslation();
  return (
    <PageShell>
      <PageHeader title={t('goals.detailTitle')} subtitle={t('common.routeShell')} />
    </PageShell>
  );
}
