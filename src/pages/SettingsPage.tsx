import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Copy, CheckCircle2, Link as LinkIcon } from 'lucide-react';
import { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
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
  type AddCurrencyDto,
  type CurrencyDto,
  type UpdateCurrencyRateDto,
} from '../lib/tauri/currency';
import { getAccountId, linkDevice } from '../lib/auth';
import { updateSyncSettings, getSyncSettings, type SyncSettings } from '../lib/tauri/sync';

const updateRateSchema = z.object({
  exchange_rate: z
    .string()
    .min(1, 'Exchange rate is required')
    .refine((val) => !isNaN(parseFloat(val)) && parseFloat(val) > 0, {
      message: 'Exchange rate must be greater than 0',
    }),
});

type UpdateRateFormValues = z.infer<typeof updateRateSchema>;

const linkDeviceSchema = z.object({
  account_id: z.string().min(1, 'Account ID is required'),
});

type LinkDeviceFormValues = z.infer<typeof linkDeviceSchema>;

interface SyncEvent {
  status: 'started' | 'completed' | 'failed';
  message: string;
  error?: string;
}

export function SettingsPage() {
  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
  const [updateRateDialogData, setUpdateRateDialogData] = useState<CurrencyDto | null>(null);
  const [isLinkDeviceDialogOpen, setIsLinkDeviceDialogOpen] = useState(false);
  const [accountId, setAccountId] = useState<string | null>(null);
  const [copiedAccountId, setCopiedAccountId] = useState(false);
  const [syncEnabled, setSyncEnabled] = useState(true);
  const [syncInterval, setSyncInterval] = useState('15');
  const [lastSyncEvent, setLastSyncEvent] = useState<SyncEvent | null>(null);
  const queryClient = useQueryClient();

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

  const addMutation = useMutation({
    mutationFn: addCurrency,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['currencies'] });
      setIsAddDialogOpen(false);
    },
  });

  const updateRateMutation = useMutation({
    mutationFn: ({ code, dto }: { code: string; dto: UpdateCurrencyRateDto }) =>
      updateCurrencyRate(code, dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['currencies'] });
      setUpdateRateDialogData(null);
    },
  });

  const handleAddCurrency = (data: AddCurrencyDto) => {
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
        dto: { exchange_rate: values.exchange_rate },
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

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">Settings</h1>
      </div>

      {/* Account & Device Section */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>Account & Device</CardTitle>
          <CardDescription>
            Manage your account and link additional devices
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="current-account-id">Your Account ID</Label>
            <div className="flex gap-2">
              <Input
                id="current-account-id"
                value={accountId || 'Loading...'}
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
              Use this ID to link other devices to your account
            </p>
          </div>

          <Button
            onClick={() => setIsLinkDeviceDialogOpen(true)}
            variant="outline"
            className="w-full gap-2"
          >
            <LinkIcon className="h-4 w-4" />
            Link Another Device
          </Button>
        </CardContent>
      </Card>

      {/* Sync Settings Section */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>Automatic Sync</CardTitle>
          <CardDescription>
            Configure automatic background synchronization
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center justify-between">
            <div className="space-y-0.5">
              <Label htmlFor="sync-enabled">Enable Auto-Sync</Label>
              <p className="text-xs text-muted-foreground">
                Automatically sync data in the background
              </p>
            </div>
            <Switch
              id="sync-enabled"
              checked={syncEnabled}
              onCheckedChange={handleSyncEnabledChange}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="sync-interval">Sync Interval</Label>
            <Select
              value={syncInterval}
              onValueChange={handleSyncIntervalChange}
              disabled={!syncEnabled}
            >
              <SelectTrigger id="sync-interval">
                <SelectValue placeholder="Select interval" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="5">Every 5 minutes</SelectItem>
                <SelectItem value="15">Every 15 minutes</SelectItem>
                <SelectItem value="30">Every 30 minutes</SelectItem>
                <SelectItem value="60">Every hour</SelectItem>
              </SelectContent>
            </Select>
            <p className="text-xs text-muted-foreground">
              How often to sync data automatically
            </p>
          </div>

          {lastSyncEvent && (
            <div className="pt-2 border-t">
              <div className="flex items-center gap-2">
                <span className="text-sm font-medium">Last Sync:</span>
                {lastSyncEvent.status === 'started' && (
                  <Badge variant="secondary">Syncing...</Badge>
                )}
                {lastSyncEvent.status === 'completed' && (
                  <Badge variant="outline" className="gap-1.5">
                    <span className="h-2 w-2 rounded-full bg-green-500" />
                    Success
                  </Badge>
                )}
                {lastSyncEvent.status === 'failed' && (
                  <Badge variant="destructive">Failed</Badge>
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

      {/* Currency Settings Section */}
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-2xl font-bold">Currency Settings</h2>
        <Button onClick={() => setIsAddDialogOpen(true)}>Add Currency</Button>
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">Loading currencies...</div>
        </div>
      ) : currencies.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <p className="text-neutral-500 mb-4">No currencies configured</p>
          <Button onClick={() => setIsAddDialogOpen(true)}>Add your first currency</Button>
        </div>
      ) : (
        <div className="border rounded-lg">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Code</TableHead>
                <TableHead>Symbol</TableHead>
                <TableHead className="text-right">Exchange Rate (to CNY)</TableHead>
                <TableHead>Last Updated</TableHead>
                <TableHead className="w-[150px]">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {currencies.map((currency: CurrencyDto) => (
                <TableRow key={currency.code}>
                  <TableCell className="font-medium">
                    <div className="flex items-center gap-2">
                      {currency.code}
                      {currency.code === 'CNY' && (
                        <Badge variant="secondary">Base Currency</Badge>
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
                        Update Rate
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
          Error adding currency: {(addMutation.error as Error).message}
        </div>
      )}

      {updateRateMutation.isError && (
        <div className="mt-4 p-4 bg-red-50 border border-red-200 rounded-lg text-red-700">
          Error updating exchange rate: {(updateRateMutation.error as Error).message}
        </div>
      )}

      <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Add Currency</DialogTitle>
            <DialogDescription>
              Add a new currency with its exchange rate relative to CNY.
            </DialogDescription>
          </DialogHeader>
          <CurrencyForm
            onSubmit={handleAddCurrency}
            onCancel={() => setIsAddDialogOpen(false)}
            isLoading={addMutation.isPending}
          />
        </DialogContent>
      </Dialog>

      <Dialog
        open={!!updateRateDialogData}
        onOpenChange={() => setUpdateRateDialogData(null)}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Update Exchange Rate</DialogTitle>
            <DialogDescription>
              Update the exchange rate for {updateRateDialogData?.code} relative to CNY.
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
                    <FormLabel>Exchange Rate</FormLabel>
                    <FormControl>
                      <Input type="text" placeholder="e.g., 0.14" {...field} />
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
                  Cancel
                </Button>
                <Button type="submit" disabled={updateRateMutation.isPending}>
                  {updateRateMutation.isPending ? 'Updating...' : 'Update Rate'}
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
            <DialogTitle>Link Another Device</DialogTitle>
            <DialogDescription>
              Enter the Account ID from another device to link them together
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
                    <FormLabel>Account ID</FormLabel>
                    <FormControl>
                      <Input
                        type="text"
                        placeholder="Enter Account ID"
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
                  Error linking device: {(linkDeviceMutation.error as Error).message}
                </div>
              )}

              <div className="flex justify-end gap-2 pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setIsLinkDeviceDialogOpen(false)}
                  disabled={linkDeviceMutation.isPending}
                >
                  Cancel
                </Button>
                <Button type="submit" disabled={linkDeviceMutation.isPending}>
                  {linkDeviceMutation.isPending ? 'Linking...' : 'Link Device'}
                </Button>
              </div>
            </form>
          </Form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
