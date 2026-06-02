import { useQuery } from '@tanstack/react-query';
import { getAccountBalanceHistory } from '@/lib/tauri/account';

export function useAccountBalanceHistory(accountId: string | undefined, days = 30) {
  return useQuery({
    queryKey: ['accountBalanceHistory', accountId, days],
    queryFn: () => getAccountBalanceHistory(accountId!, days),
    enabled: !!accountId,
    staleTime: 5 * 60 * 1000,
  });
}
