import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Copy, CheckCircle2, Link as LinkIcon, RefreshCw } from 'lucide-react';
import { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { z } from 'zod';
import { listen } from '@tauri-apps/api/event';
import { CurrencyForm } from '../components/CurrencyForm';
import { Badge } from '../components/ui/badge';
import { Button } from '../components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '../components/ui/dialog';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from '../components/ui/sheet';
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '../components/ui/form';
import { Input } from '../components/ui/input';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '../components/ui/table';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../components/ui/card';
import { Label } from '../components/ui/label';
import { Switch } from '../components/ui/switch';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../components/ui/select';
import {
  addCurrency,
  listCurrencies,
  updateCurrencyRate,
  type CreateCurrencyDto,
  type CurrencyDto,
} from '../lib/tauri/currency';
import { getAccountId, linkDevice } from '../lib/auth';
import { updateSyncSettings, getSyncSettings } from '../lib/tauri/sync';
import { useEncryption } from '../hooks/useEncryption';
import { useFetchExchangeRates } from '../hooks/useCurrency';
import { useCloudSyncStatus, useCloudSyncNow, useUpdateCloudSyncSettings, useCloudSyncSettings, useResolveSyncConflict } from '@/hooks/useCloudSync';
import { exportCsv } from '@/lib/tauri/export';
import { TagsSection } from '@/components/TagsSection';
import { SyncConflictDialog } from '@/components/SyncConflictDialog';
import { getSyncStatusWithConflicts, type SyncConflictItem } from '@/lib/tauri/cloudSync';

interface SyncEvent {
  status: 'started' | 'completed' | 'failed';
  message: string;
  error?: string;
}

export function SettingsPage() {
  const { t, i18n } = useTranslation();
  
  const updateRateSchema = z.object({
    exchange_rate: z
      .string()
      .min(1, t('settings.exchangeRateRequired'))
      .refine((val) => !isNaN(parseFloat(val)) && parseFloat(val) > 0, {
        message: t('settings.exchangeRatePositive'),
      }),
  });

  type UpdateRateFormValues = z.infer<typeof updateRateSchema>;

  const linkDeviceSchema = z.object({
    account_id: z.string().min(1, t('settings.accountIdRequired')),
  });

  type LinkDeviceFormValues = z.infer<typeof linkDeviceSchema>;

  const [isCurrencySheetOpen, setIsCurrencySheetOpen] = useState(false);
  const [updateRateDialogData, setUpdateRateDialogData] = useState<CurrencyDto | null>(null);
  const [isLinkDeviceDialogOpen, setIsLinkDeviceDialogOpen] = useState(false);
  const [accountId, setAccountId] = useState<string | null>(null);
  const [copiedAccountId, setCopiedAccountId] = useState(false);
  const [syncEnabled, setSyncEnabled] = useState(true);
  const [syncInterval, setSyncInterval] = useState('15');
  const [lastSyncEvent, setLastSyncEvent] = useState<SyncEvent | null>(null);
  const queryClient = useQueryClient();

  // Cloud sync
  const { data: cloudSyncStatus } = useCloudSyncStatus();
  const { data: cloudSyncSettings } = useCloudSyncSettings();
  const cloudSyncNowMutation = useCloudSyncNow();
  const updateCloudSyncSettingsMutation = useUpdateCloudSyncSettings();
  const [cloudSyncInterval, setCloudSyncInterval] = useState('30');

  // Conflict resolution
  const [isConflictDialogOpen, setIsConflictDialogOpen] = useState(false);
  const [conflicts, setConflicts] = useState<SyncConflictItem[]>([]);
  const resolveConflictMutation = useResolveSyncConflict();

  const [lastCloudSyncEvent, setLastCloudSyncEvent] = useState<{
    status: string;
    message: string;
    error?: string;
  } | null>(null);

  useEffect(() => {
    const unlisten = listen<{
      status: string;
      message: string;
      error?: string;
    }>('sync:cloud-status', (event) => {
      setLastCloudSyncEvent(event.payload);
      if (event.payload.status === 'completed' || event.payload.status === 'failed') {
        queryClient.invalidateQueries({ queryKey: ['cloudSyncStatus'] });
        // Check for conflicts after sync completes
        if (event.payload.status === 'completed') {
          queryClient.invalidateQueries({ queryKey: ['syncConflicts'] });
          getSyncStatusWithConflicts().then((result) => {
            if (result.conflicts && result.conflicts.length > 0) {
              setConflicts(result.conflicts);
              setIsConflictDialogOpen(true);
            }
          }).catch(() => {
            // Silently ignore conflict detection errors
          });
        }
      }
    });
    return () => {
      unlisten.then((fn) => fn());
    };
  }, [queryClient]);

  useEffect(() => {
    if (cloudSyncSettings?.interval_minutes) {
      setCloudSyncInterval(String(cloudSyncSettings.interval_minutes));
    }
  }, [cloudSyncSettings?.interval_minutes]);

  const handleCloudSyncEnabledChange = (enabled: boolean) => {
    updateCloudSyncSettingsMutation.mutate({
      auto_sync_enabled: enabled,
      interval_minutes: parseInt(cloudSyncInterval, 10),
      last_sync_at: null,
      last_sync_status: null,
      last_error: null,
    });
  };

  const handleCloudSyncIntervalChange = (interval: string | null) => {
    if (interval) {
      setCloudSyncInterval(interval);
      updateCloudSyncSettingsMutation.mutate({
        auto_sync_enabled: cloudSyncSettings?.auto_sync_enabled ?? false,
        interval_minutes: parseInt(interval, 10),
        last_sync_at: null,
        last_sync_status: null,
        last_error: null,
      });
    }
  };

  useEffect(() => {
    getAccountId().then(setAccountId);

    // Load sync settings from backend
    getSyncSettings().then((settings) => {
      setSyncEnabled(settings.enabled);
      setSyncInterval(String(settings.interval_minutes));
    }).catch(() => {
      // Fallback to defaults if backend not ready
      setSyncEnabled(true);
      setSyncInterval('15');
    });

    // Listen for sync events
    const unlisten = listen<SyncEvent>('sync:status', (event) => {
      setLastSyncEvent(event.payload);
    });

    return () => {
      unlisten.then((fn) => fn());
    };
  }, []);

  const handleSyncEnabledChange = async (enabled: boolean) => {
    setSyncEnabled(enabled);
    try {
      await updateSyncSettings(enabled, parseInt(syncInterval, 10));
    } catch (error) {
      console.error('Failed to update sync settings:', error);
    }
  };

  const handleSyncIntervalChange = async (interval: string | null) => {
    if (interval) {
      setSyncInterval(interval);
      try {
        await updateSyncSettings(syncEnabled, parseInt(interval, 10));
      } catch (error) {
        console.error('Failed to update sync settings:', error);
      }
    }
  };

  const { data: currencies = [], isLoading } = useQuery({
    queryKey: ['currencies'],
    queryFn: listCurrencies,
  });

  const fetchRatesMutation = useFetchExchangeRates();

  const addMutation = useMutation({
    mutationFn: addCurrency,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['currencies'] });
      setIsCurrencySheetOpen(false);
    },
  });

  const updateRateMutation = useMutation({
    mutationFn: ({ code, exchangeRate }: { code: string; exchangeRate: string }) =>
      updateCurrencyRate(code, exchangeRate),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['currencies'] });
      setUpdateRateDialogData(null);
    },
  });

  const handleAddCurrency = (data: CreateCurrencyDto) => {
    addMutation.mutate(data);
  };

  const updateRateForm = useForm<UpdateRateFormValues>({
    resolver: zodResolver(updateRateSchema),
    defaultValues: {
      exchange_rate: '',
    },
  });

  const linkDeviceForm = useForm<LinkDeviceFormValues>({
    resolver: zodResolver(linkDeviceSchema),
    defaultValues: {
      account_id: '',
    },
  });

  const linkDeviceMutation = useMutation({
    mutationFn: (accountId: string) => linkDevice(accountId),
    onSuccess: async () => {
      const newAccountId = await getAccountId();
      setAccountId(newAccountId);
      setIsLinkDeviceDialogOpen(false);
      linkDeviceForm.reset();
    },
  });

  const handleUpdateRate = (values: UpdateRateFormValues) => {
    if (updateRateDialogData) {
      updateRateMutation.mutate({
        code: updateRateDialogData.code,
        exchangeRate: values.exchange_rate,
      });
    }
  };

  const openUpdateRateDialog = (currency: CurrencyDto) => {
    setUpdateRateDialogData(currency);
    updateRateForm.reset({ exchange_rate: currency.exchange_rate });
  };

  const handleLinkDevice = (values: LinkDeviceFormValues) => {
    linkDeviceMutation.mutate(values.account_id);
  };

  const handleCopyAccountId = async () => {
    if (accountId) {
      await navigator.clipboard.writeText(accountId);
      setCopiedAccountId(true);
      setTimeout(() => setCopiedAccountId(false), 2000);
    }
  };

  const handleExportCsv = async () => {
    try {
      const result = await exportCsv();
      toast.success(t('settings.exportSuccess', { rows: result.rows_exported }));
    } catch (err) {
      if (String(err).includes('cancelled')) return;
      toast.error(t('settings.exportError'));
    }
  };

  return (
    <div className="p-4 sm:p-6">
      <div className="flex items-center justify-between mb-4 sm:mb-6">
        <h1 className="text-2xl font-bold sm:text-3xl">{t('settings.title')}</h1>
      </div>

      {/* Language Settings */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>{t('settings.language')}</CardTitle>
          <CardDescription>{t('settings.languageDesc')}</CardDescription>
        </CardHeader>
        <CardContent>
          <Select value={i18n.language || 'en'} onValueChange={(value) => value && i18n.changeLanguage(value)}>
            <SelectTrigger className="w-full">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="en">{t('settings.english')}</SelectItem>
              <SelectItem value="zh">{t('settings.chinese')}</SelectItem>
            </SelectContent>
          </Select>
        </CardContent>
      </Card>

      {/* Account & Device Section */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>{t('settings.accountDevice')}</CardTitle>
          <CardDescription>
            {t('settings.accountDeviceDesc')}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="current-account-id">{t('settings.yourAccountId')}</Label>
            <div className="flex gap-2">
              <Input
                id="current-account-id"
                value={accountId || t('settings.loading')}
                readOnly
                className="font-mono text-sm"
              />
              <Button
                variant="outline"
                size="icon"
                onClick={handleCopyAccountId}
                disabled={!accountId}
                className="flex-shrink-0"
              >
                {copiedAccountId ? (
                  <CheckCircle2 className="h-4 w-4 text-green-600" />
                ) : (
                  <Copy className="h-4 w-4" />
                )}
              </Button>
            </div>
            <p className="text-xs text-muted-foreground">
              {t('settings.useIdToLink')}
            </p>
          </div>

          <Button
            onClick={() => setIsLinkDeviceDialogOpen(true)}
            variant="outline"
            className="w-full gap-2"
          >
            <LinkIcon className="h-4 w-4" />
            {t('settings.linkAnotherDevice')}
          </Button>
        </CardContent>
      </Card>

      {/* Sync Settings Section */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>{t('settings.autoSync')}</CardTitle>
          <CardDescription>
            {t('settings.autoSyncDesc')}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center justify-between">
            <div className="space-y-0.5">
              <Label htmlFor="sync-enabled">{t('settings.enableAutoSync')}</Label>
              <p className="text-xs text-muted-foreground">
                {t('settings.autoSyncData')}
              </p>
            </div>
            <Switch
              id="sync-enabled"
              checked={syncEnabled}
              onCheckedChange={handleSyncEnabledChange}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="sync-interval">{t('settings.syncInterval')}</Label>
            <Select
              value={syncInterval}
              onValueChange={handleSyncIntervalChange}
              disabled={!syncEnabled}
            >
              <SelectTrigger id="sync-interval">
                <SelectValue placeholder={t('settings.selectInterval')} />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="5">{t('settings.every5Minutes')}</SelectItem>
                <SelectItem value="15">{t('settings.every15Minutes')}</SelectItem>
                <SelectItem value="30">{t('settings.every30Minutes')}</SelectItem>
                <SelectItem value="60">{t('settings.everyHour')}</SelectItem>
              </SelectContent>
            </Select>
            <p className="text-xs text-muted-foreground">
              {t('settings.howOftenSync')}
            </p>
          </div>

          {lastSyncEvent && (
            <div className="pt-2 border-t">
              <div className="flex items-center gap-2">
                <span className="text-sm font-medium">{t('settings.lastSync')}</span>
                {lastSyncEvent.status === 'started' && (
                  <Badge variant="secondary">{t('settings.syncing')}</Badge>
                )}
                {lastSyncEvent.status === 'completed' && (
                  <Badge variant="outline" className="gap-1.5">
                    <span className="h-2 w-2 rounded-full bg-green-500" />
                    {t('settings.success')}
                  </Badge>
                )}
                {lastSyncEvent.status === 'failed' && (
                  <Badge variant="destructive">{t('settings.failed')}</Badge>
                )}
              </div>
              <p className="text-xs text-muted-foreground mt-1">
                {lastSyncEvent.message}
              </p>
              {lastSyncEvent.error && (
                <p className="text-xs text-destructive mt-1">
                  {lastSyncEvent.error}
                </p>
              )}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Cloud Sync Section */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>{t('cloudSync.title')}</CardTitle>
          <CardDescription>
            {t('cloudSync.description')}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {!cloudSyncStatus?.cloud_configured ? (
            <p className="text-sm text-muted-foreground">
              {t('cloudSync.notConfigured')}
            </p>
          ) : (
            <>
              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <Label>{t('cloudSync.enableAutoSync')}</Label>
                  <p className="text-xs text-muted-foreground">
                    {t('cloudSync.autoSyncDesc')}
                  </p>
                </div>
                <Switch
                  checked={cloudSyncSettings?.auto_sync_enabled ?? false}
                  onCheckedChange={handleCloudSyncEnabledChange}
                />
              </div>

              <div className="space-y-2">
                <Label>{t('cloudSync.interval')}</Label>
                <Select
                  value={cloudSyncInterval}
                  onValueChange={handleCloudSyncIntervalChange}
                  disabled={!(cloudSyncSettings?.auto_sync_enabled ?? false)}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="30">{t('cloudSync.every30Minutes')}</SelectItem>
                    <SelectItem value="60">{t('cloudSync.everyHour')}</SelectItem>
                    <SelectItem value="120">{t('cloudSync.every2Hours')}</SelectItem>
                    <SelectItem value="360">{t('cloudSync.every6Hours')}</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="flex items-center gap-3">
                <Button
                  onClick={() => cloudSyncNowMutation.mutate()}
                  disabled={cloudSyncStatus?.is_syncing}
                >
                  {cloudSyncStatus?.is_syncing
                    ? t('cloudSync.syncing')
                    : t('cloudSync.syncNow')}
                </Button>
                {conflicts.length > 0 && (
                  <Button
                    variant="outline"
                    onClick={() => setIsConflictDialogOpen(true)}
                    className="gap-1.5"
                  >
                    {t('cloudSync.resolveConflicts')}
                    <Badge variant="destructive" className="ml-1">{conflicts.length}</Badge>
                  </Button>
                )}
                {cloudSyncStatus?.last_sync_at && (
                  <span className="text-xs text-muted-foreground">
                    {t('cloudSync.lastSynced')}: {cloudSyncStatus.last_sync_at}
                  </span>
                )}
              </div>

              {lastCloudSyncEvent && (
                <div className="pt-2 border-t">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-medium">{t('cloudSync.statusLabel')}</span>
                    {lastCloudSyncEvent.status === 'started' && (
                      <Badge variant="secondary">{t('cloudSync.syncing')}</Badge>
                    )}
                    {lastCloudSyncEvent.status === 'completed' && (
                      <Badge variant="outline" className="gap-1.5">
                        <span className="h-2 w-2 rounded-full bg-green-500" />
                        {t('cloudSync.success')}
                      </Badge>
                    )}
                    {lastCloudSyncEvent.status === 'failed' && (
                      <Badge variant="destructive">{t('cloudSync.failed')}</Badge>
                    )}
                  </div>
                  <p className="text-xs text-muted-foreground mt-1">
                    {lastCloudSyncEvent.message}
                  </p>
                  {lastCloudSyncEvent.error && (
                    <p className="text-xs text-destructive mt-1">
                      {lastCloudSyncEvent.error}
                    </p>
                  )}
                </div>
              )}
            </>
          )}
        </CardContent>
      </Card>

      {/* Sync Conflict Resolution Dialog */}
      <SyncConflictDialog
        open={isConflictDialogOpen}
        onOpenChange={(open) => {
          setIsConflictDialogOpen(open);
          if (!open) {
            getSyncStatusWithConflicts().then((result) => {
              setConflicts(result.conflicts ?? []);
            }).catch(() => {
              setConflicts([]);
            });
          }
        }}
        conflicts={conflicts}
        onResolve={(tableName, recordId, resolution) => {
          resolveConflictMutation.mutate(
            { tableName, recordId, resolution },
            {
              onSuccess: () => {
                setConflicts((prev) =>
                  prev.filter(
                    (c) => !(c.table_name === tableName && c.record_id === recordId),
                  ),
                );
                if (conflicts.length <= 1) {
                  setIsConflictDialogOpen(false);
                }
              },
            },
          );
        }}
        isResolving={resolveConflictMutation.isPending}
      />

      {/* Encryption Settings Section */}
      <EncryptionSection />

      {/* Tags Management Section */}
      <TagsSection />

      {/* Data Export Section */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>{t('settings.dataExport')}</CardTitle>
          <CardDescription>
            {t('settings.dataExportDesc')}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button onClick={handleExportCsv} variant="outline">
            {t('settings.exportCsv')}
          </Button>
        </CardContent>
      </Card>

      {/* Currency Settings Section */}
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-2xl font-bold">{t('settings.currencySettings')}</h2>
        <div className="flex gap-2">
          <Button
            variant="outline"
            onClick={() => fetchRatesMutation.mutate()}
            disabled={fetchRatesMutation.isPending}
          >
            <RefreshCw className={`h-4 w-4 mr-2 ${fetchRatesMutation.isPending ? 'animate-spin' : ''}`} />
            {t('settings.fetchRates')}
          </Button>
          <Button onClick={() => setIsCurrencySheetOpen(true)}>{t('settings.addCurrency')}</Button>
        </div>
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">{t('settings.loadingCurrencies')}</div>
        </div>
      ) : currencies.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <p className="text-neutral-500 mb-4">{t('settings.noCurrencies')}</p>
          <Button onClick={() => setIsCurrencySheetOpen(true)}>{t('settings.addFirstCurrency')}</Button>
        </div>
      ) : (
        <div className="border rounded-lg">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('settings.code')}</TableHead>
                <TableHead>{t('settings.symbol')}</TableHead>
                <TableHead className="text-right">{t('settings.exchangeRate')}</TableHead>
                <TableHead>{t('settings.lastUpdated')}</TableHead>
                <TableHead className="w-[150px]">{t('common.actions')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {currencies.map((currency: CurrencyDto) => (
                <TableRow key={currency.code}>
                  <TableCell className="font-medium">
                    <div className="flex items-center gap-2">
                      {currency.code}
                      {currency.code === 'CNY' && (
                        <Badge variant="secondary">{t('settings.baseCurrency')}</Badge>
                      )}
                    </div>
                  </TableCell>
                  <TableCell>{currency.symbol}</TableCell>
                  <TableCell className="text-right">
                    <div className="flex flex-col items-end">
                      <span className="font-mono">
                        {parseFloat(currency.exchange_rate).toFixed(6)}
                      </span>
                      <span className="text-xs text-muted-foreground">
                        1 {currency.code} = {parseFloat(currency.exchange_rate).toFixed(2)} CNY
                      </span>
                    </div>
                  </TableCell>
                  <TableCell className="text-sm text-muted-foreground">
                    {new Date(currency.updated_at).toLocaleString('en-US', {
                      year: 'numeric',
                      month: 'short',
                      day: 'numeric',
                      hour: '2-digit',
                      minute: '2-digit',
                    })}
                  </TableCell>
                  <TableCell>
                    {currency.code !== 'CNY' && (
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => openUpdateRateDialog(currency)}
                      >
                        {t('settings.updateRate')}
                      </Button>
                    )}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}

      {addMutation.isError && (
        <div className="mt-4 p-4 bg-red-50 border border-red-200 rounded-lg text-red-700">
          {t('settings.errorAddingCurrency')}: {(addMutation.error as Error).message}
        </div>
      )}

      {updateRateMutation.isError && (
        <div className="mt-4 p-4 bg-red-50 border border-red-200 rounded-lg text-red-700">
          {t('settings.errorUpdatingRate')}: {(updateRateMutation.error as Error).message}
        </div>
      )}

      <Sheet open={isCurrencySheetOpen} onOpenChange={setIsCurrencySheetOpen}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{t('settings.addCurrency')}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            <CurrencyForm
              onSubmit={handleAddCurrency}
              onCancel={() => setIsCurrencySheetOpen(false)}
              isLoading={addMutation.isPending}
            />
          </div>
        </SheetContent>
      </Sheet>

      <Dialog
        open={!!updateRateDialogData}
        onOpenChange={() => setUpdateRateDialogData(null)}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('settings.updateExchangeRate')}</DialogTitle>
            <DialogDescription>
              {t('settings.updateRateDesc', { code: updateRateDialogData?.code })}
            </DialogDescription>
          </DialogHeader>
          <Form {...updateRateForm}>
            <form
              onSubmit={updateRateForm.handleSubmit(handleUpdateRate)}
              className="space-y-4"
            >
              <FormField
                control={updateRateForm.control}
                name="exchange_rate"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>{t('common.amount')}</FormLabel>
                    <FormControl>
                      <Input type="text" placeholder={t('settings.exchangeRatePlaceholder')} {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <div className="flex justify-end gap-2 pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setUpdateRateDialogData(null)}
                  disabled={updateRateMutation.isPending}
                >
                  {t('common.cancel')}
                </Button>
                <Button type="submit" disabled={updateRateMutation.isPending}>
                  {updateRateMutation.isPending ? t('settings.updating') : t('settings.updateRateButton')}
                </Button>
              </div>
            </form>
          </Form>
        </DialogContent>
      </Dialog>

      <Dialog
        open={isLinkDeviceDialogOpen}
        onOpenChange={setIsLinkDeviceDialogOpen}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('settings.linkDeviceTitle')}</DialogTitle>
            <DialogDescription>
              {t('settings.linkDeviceDesc')}
            </DialogDescription>
          </DialogHeader>
          <Form {...linkDeviceForm}>
            <form
              onSubmit={linkDeviceForm.handleSubmit(handleLinkDevice)}
              className="space-y-4"
            >
              <FormField
                control={linkDeviceForm.control}
                name="account_id"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>{t('settings.accountId')}</FormLabel>
                    <FormControl>
                      <Input
                        type="text"
                        placeholder={t('settings.accountIdPlaceholder')}
                        className="font-mono text-sm"
                        {...field}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              {linkDeviceMutation.isError && (
                <div className="bg-red-50 border border-red-200 rounded-lg p-3 text-sm text-red-700">
                  {t('settings.errorLinkingDevice')}: {(linkDeviceMutation.error as Error).message}
                </div>
              )}

              <div className="flex justify-end gap-2 pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setIsLinkDeviceDialogOpen(false)}
                  disabled={linkDeviceMutation.isPending}
                >
                  {t('common.cancel')}
                </Button>
                <Button type="submit" disabled={linkDeviceMutation.isPending}>
                  {linkDeviceMutation.isPending ? t('settings.linking') : t('settings.linkDevice')}
                </Button>
              </div>
            </form>
          </Form>
        </DialogContent>
      </Dialog>
    </div>
  );
}

function EncryptionSection() {
  const { t } = useTranslation();
  const {
    enabled, unlocked, isLoading,
    password, setPassword,
    confirmPassword, setConfirmPassword,
    disablePassword, setDisablePassword,
    handleSetup, handleUnlock, handleUnlockKeychain,
    handleLock, handleDisable,
  } = useEncryption();
  const [setupMode, setSetupMode] = useState<'idle' | 'setup' | 'unlock' | 'disable'>('idle');
  const [error, setError] = useState('');

  if (isLoading) return null;

  return (
    <Card className="mb-6">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <span>🔒</span>
          {t('settings.encryption')}
        </CardTitle>
        <CardDescription>{t('settings.encryptionDesc')}</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {enabled && unlocked && (
          <div className="flex items-center justify-between">
            <div className="space-y-0.5">
              <p className="text-sm font-medium text-green-600">{t('settings.encryptionEnabled')}</p>
              <p className="text-xs text-muted-foreground">{t('settings.encryptionUnlocked')}</p>
            </div>
            <div className="flex gap-2">
              <Button variant="outline" size="sm" onClick={handleLock}>
                {t('settings.lockEncryption')}
              </Button>
              <Button variant="outline" size="sm" onClick={() => { setSetupMode('disable'); setError(''); }}>
                {t('settings.disableEncryption')}
              </Button>
            </div>
          </div>
        )}

        {enabled && !unlocked && (
          <div className="space-y-3">
            <div className="flex items-center gap-2">
              <p className="text-sm font-medium text-yellow-600">{t('settings.encryptionLocked')}</p>
            </div>
            {setupMode === 'unlock' ? (
              <div className="space-y-3">
                <Input
                  type="password"
                  placeholder={t('settings.enterPassword')}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
                {error && <p className="text-xs text-destructive">{error}</p>}
                <div className="flex gap-2">
                  <Button size="sm" onClick={async () => {
                    try { setError(''); await handleUnlock(); setSetupMode('idle');
                    } catch (e: unknown) { setError(e instanceof Error ? e.message : String(e) || 'Failed'); }
                  }}>
                    {t('settings.unlockEncryption')}
                  </Button>
                  <Button size="sm" variant="outline" onClick={async () => {
                    try { setError(''); await handleUnlockKeychain(); setSetupMode('idle');
                    } catch (e: unknown) { setError(e instanceof Error ? e.message : String(e) || 'Failed'); }
                  }}>
                    {t('settings.unlockWithKeychain')}
                  </Button>
                  <Button size="sm" variant="ghost" onClick={() => setSetupMode('idle')}>{t('common.cancel')}</Button>
                </div>
              </div>
            ) : (
              <Button size="sm" onClick={() => { setSetupMode('unlock'); setPassword(''); setError(''); }}>
                {t('settings.unlockEncryption')}
              </Button>
            )}
          </div>
        )}

        {!enabled && (
          <div className="space-y-3">
            {setupMode === 'setup' ? (
              <div className="space-y-3">
                <Input
                  type="password"
                  placeholder={t('settings.enterPassword')}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
                <Input
                  type="password"
                  placeholder={t('settings.confirmPassword')}
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                />
                {error && <p className="text-xs text-destructive">{error}</p>}
                <div className="flex gap-2">
                  <Button size="sm" onClick={async () => {
                    try { setError(''); await handleSetup(); setSetupMode('idle');
                    } catch (e: unknown) { setError(e instanceof Error ? e.message : String(e) || 'Failed'); }
                  }}>
                    {t('settings.setupEncryption')}
                  </Button>
                  <Button size="sm" variant="ghost" onClick={() => setSetupMode('idle')}>{t('common.cancel')}</Button>
                </div>
              </div>
            ) : (
              <Button size="sm" onClick={() => { setSetupMode('setup'); setPassword(''); setConfirmPassword(''); setError(''); }}>
                {t('settings.setupEncryption')}
              </Button>
            )}
          </div>
        )}

        {setupMode === 'disable' && (
          <div className="space-y-3 pt-2 border-t">
            <p className="text-sm text-destructive">{t('settings.disableEncryptionWarning')}</p>
            <Input
              type="password"
              placeholder={t('settings.enterPassword')}
              value={disablePassword}
              onChange={(e) => setDisablePassword(e.target.value)}
            />
            {error && <p className="text-xs text-destructive">{error}</p>}
            <div className="flex gap-2">
              <Button size="sm" variant="destructive" onClick={async () => {
                try { setError(''); await handleDisable(); setSetupMode('idle');
                } catch (e: unknown) { setError(e instanceof Error ? e.message : String(e) || 'Failed'); }
              }}>
                {t('settings.disableEncryption')}
              </Button>
              <Button size="sm" variant="ghost" onClick={() => setSetupMode('idle')}>{t('common.cancel')}</Button>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
