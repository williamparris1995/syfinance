import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import {
  listNewCurrencies,
  fetchNewLatestRates,
  convertNewCurrency,
  type NewCurrencyDto,
} from '../lib/tauri/new_currency';

export function useNewCurrencies() {
  return useQuery<NewCurrencyDto[]>({
    queryKey: ['new-currencies'],
    queryFn: listNewCurrencies,
    staleTime: 1000 * 60 * 60, // 1 hour
  });
}

export function useFetchNewLatestRates() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: fetchNewLatestRates,
    onSuccess: (currencies) => {
      queryClient.setQueryData(['new-currencies'], currencies);
      toast.success('汇率已更新');
    },
    onError: (error) => {
      toast.error(`更新汇率失败: ${error}`);
    },
  });
}

export function useConvertNewCurrency() {
  return useMutation({
    mutationFn: ({
      amount,
      fromCode,
      toCode,
    }: {
      amount: number;
      fromCode: string;
      toCode: string;
    }) => convertNewCurrency(amount, fromCode, toCode),
  });
}
