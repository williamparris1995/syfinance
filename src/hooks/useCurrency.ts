import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  listCurrencies,
  getCurrency,
  addCurrency,
  updateCurrencyRate,
  deleteCurrency,
  convertCurrency,
  fetchExchangeRates,
  CreateCurrencyDto,
} from '../lib/tauri/currency';
import { toast } from 'sonner';
import { useTranslation } from 'react-i18next';

export function useCurrencies() {
  return useQuery({
    queryKey: ['currencies'],
    queryFn: listCurrencies,
    staleTime: 1000 * 60 * 60,
  });
}

export function useCurrency(code: string) {
  return useQuery({
    queryKey: ['currency', code],
    queryFn: () => getCurrency(code),
    enabled: !!code,
  });
}

export function useAddCurrency() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: (dto: CreateCurrencyDto) => addCurrency(dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['currencies'] });
      toast.success(t('settings.currencyAdded'));
    },
    onError: (error) => {
      toast.error(t('settings.currencyAddFailed', { error: String(error) }));
    },
  });
}

export function useUpdateCurrencyRate() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: ({ code, exchangeRate }: { code: string; exchangeRate: string }) =>
      updateCurrencyRate(code, exchangeRate),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['currencies'] });
      toast.success(t('settings.rateUpdated'));
    },
    onError: (error) => {
      toast.error(t('settings.rateUpdateFailed', { error: String(error) }));
    },
  });
}

export function useDeleteCurrency() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: (code: string) => deleteCurrency(code),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['currencies'] });
      toast.success(t('settings.currencyDeleted'));
    },
    onError: (error) => {
      toast.error(t('settings.currencyDeleteFailed', { error: String(error) }));
    },
  });
}

export function useConvertCurrency() {
  return useMutation({
    mutationFn: ({
      amount,
      fromCode,
      toCode,
    }: {
      amount: number;
      fromCode: string;
      toCode: string;
    }) => convertCurrency(amount, fromCode, toCode),
  });
}

export function useFetchExchangeRates() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: fetchExchangeRates,
    onSuccess: (updated) => {
      queryClient.invalidateQueries({ queryKey: ['currencies'] });
      toast.success(t('settings.fetchSuccess', { count: updated }));
    },
    onError: () => {
      toast.error(t('settings.fetchError'));
    },
  });
}
