import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
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
import {
  addCurrency,
  listCurrencies,
  updateCurrencyRate,
  type AddCurrencyDto,
  type CurrencyDto,
  type UpdateCurrencyRateDto,
} from '../lib/tauri/currency';

const updateRateSchema = z.object({
  exchange_rate: z
    .string()
    .min(1, 'Exchange rate is required')
    .refine((val) => !isNaN(parseFloat(val)) && parseFloat(val) > 0, {
      message: 'Exchange rate must be greater than 0',
    }),
});

type UpdateRateFormValues = z.infer<typeof updateRateSchema>;

export function SettingsPage() {
  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
  const [updateRateDialogData, setUpdateRateDialogData] = useState<CurrencyDto | null>(null);
  const queryClient = useQueryClient();

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

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">Currency Settings</h1>
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
                <TableHead className="text-right">Exchange Rate</TableHead>
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
                    {parseFloat(currency.exchange_rate).toFixed(6)}
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
    </div>
  );
}
