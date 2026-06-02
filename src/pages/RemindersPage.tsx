import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { useState, useMemo } from 'react';
import { toast } from 'sonner';
import {
  Plus,
  Pencil,
  Trash2,
  CheckCircle2,
  Bell,
  AlertTriangle,
  Clock,
} from 'lucide-react';
import { Button } from '../components/ui/button';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from '../components/ui/sheet';
import { Badge } from '../components/ui/badge';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../components/ui/select';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '../components/ui/table';
import { Input } from '../components/ui/input';
import { Textarea } from '../components/ui/textarea';
import { Label } from '../components/ui/label';
import { getUserFriendlyError } from '../lib/error-handler';
import {
  listReminders,
  createReminder,
  updateReminder,
  deleteReminder,
  completeReminder,
  type ReminderDto,
  type CreateReminderDto,
  type UpdateReminderDto,
} from '../lib/tauri/reminder';

type FilterTab = 'all' | 'active' | 'completed';

const PRIORITY_COLORS: Record<string, string> = {
  LOW: 'bg-gray-100 text-gray-700',
  NORMAL: 'bg-blue-100 text-blue-700',
  HIGH: 'bg-orange-100 text-orange-700',
  URGENT: 'bg-red-100 text-red-700',
};

const TYPE_COLORS: Record<string, string> = {
  custom: 'bg-gray-100 text-gray-700',
  debt_payment: 'bg-purple-100 text-purple-700',
  bill_due: 'bg-amber-100 text-amber-700',
  prepaid_low_balance: 'bg-cyan-100 text-cyan-700',
};

export function RemindersPage() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();

  const [showSheet, setShowSheet] = useState(false);
  const [editingReminder, setEditingReminder] = useState<ReminderDto | null>(null);
  const [filterTab, setFilterTab] = useState<FilterTab>('all');
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);

  // Form state
  const [formTitle, setFormTitle] = useState('');
  const [formDescription, setFormDescription] = useState('');
  const [formType, setFormType] = useState('custom');
  const [formRemindAt, setFormRemindAt] = useState('');
  const [formRepeat, setFormRepeat] = useState('');
  const [formPriority, setFormPriority] = useState('NORMAL');

  const { data: reminders = [], isLoading } = useQuery({
    queryKey: ['reminders'],
    queryFn: listReminders,
    staleTime: 5 * 60 * 1000,
  });

  // Mutations
  const createMutation = useMutation({
    mutationFn: createReminder,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      setShowSheet(false);
      resetForm();
      toast.success(t('reminders.createSuccess'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, dto }: { id: string; dto: UpdateReminderDto }) =>
      updateReminder(id, dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      setShowSheet(false);
      setEditingReminder(null);
      resetForm();
      toast.success(t('reminders.updateSuccess'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  const deleteMutation = useMutation({
    mutationFn: deleteReminder,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      setDeleteConfirmId(null);
      toast.success(t('reminders.deleteSuccess'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  const completeMutation = useMutation({
    mutationFn: completeReminder,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      toast.success(t('reminders.completeSuccess'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  // Derived data
  const now = useMemo(() => new Date(), []);
  const activeReminders = useMemo(
    () => reminders.filter((r) => !r.notified),
    [reminders],
  );
  const completedReminders = useMemo(
    () => reminders.filter((r) => r.notified),
    [reminders],
  );
  const overdueReminders = useMemo(
    () =>
      reminders.filter(
        (r) => !r.notified && new Date(r.remind_at) < now,
      ),
    [reminders, now],
  );

  const filteredReminders = useMemo(() => {
    switch (filterTab) {
      case 'active':
        return activeReminders;
      case 'completed':
        return completedReminders;
      default:
        return reminders;
    }
  }, [filterTab, activeReminders, completedReminders, reminders]);

  // Handlers
  function resetForm() {
    setFormTitle('');
    setFormDescription('');
    setFormType('custom');
    setFormRemindAt('');
    setFormRepeat('');
    setFormPriority('NORMAL');
  }

  function handleNew() {
    resetForm();
    setEditingReminder(null);
    setShowSheet(true);
  }

  function handleEdit(reminder: ReminderDto) {
    setEditingReminder(reminder);
    setFormTitle(reminder.title);
    setFormDescription(reminder.description);
    setFormType(reminder.reminder_type);
    setFormRemindAt(reminder.remind_at.slice(0, 16));
    setFormRepeat(reminder.repeat_pattern || '');
    setFormPriority(reminder.priority);
    setShowSheet(true);
  }

  function handleFormSubmit() {
    if (!formTitle.trim()) {
      toast.error(t('reminders.titleRequired'));
      return;
    }
    if (!formRemindAt) {
      toast.error(t('reminders.remindAtRequired'));
      return;
    }

    const remindAtIso = new Date(formRemindAt).toISOString();

    if (editingReminder) {
      const dto: UpdateReminderDto = {
        title: formTitle.trim(),
        description: formDescription.trim(),
        remind_at: remindAtIso,
        repeat_pattern: formRepeat || undefined,
        priority: formPriority,
      };
      updateMutation.mutate({ id: editingReminder.id, dto });
    } else {
      const dto: CreateReminderDto = {
        title: formTitle.trim(),
        description: formDescription.trim() || null,
        reminder_type: formType,
        remind_at: remindAtIso,
        repeat_pattern: formRepeat || null,
        priority: formPriority,
      };
      createMutation.mutate(dto);
    }
  }

  function formatDateTime(isoStr: string): string {
    try {
      const d = new Date(isoStr);
      return d.toLocaleString();
    } catch {
      return isoStr;
    }
  }

  if (isLoading) {
    return (
      <div className="p-6 text-center text-muted-foreground">
        {t('common.loading')}
      </div>
    );
  }

  return (
    <div className="p-4 sm:p-6">
      {/* Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between mb-4 sm:mb-6">
        <h1 className="text-2xl font-bold sm:text-3xl">{t('reminders.title')}</h1>
        <Button variant="default-gradient" onClick={handleNew}>
          <Plus className="h-4 w-4 mr-1" />
          {t('reminders.create')}
        </Button>
      </div>

      {reminders.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <Bell className="h-12 w-12 text-muted-foreground/40 mb-4" />
          <p className="text-neutral-500 mb-4">{t('reminders.noReminders')}</p>
          <Button onClick={handleNew}>{t('reminders.createFirst')}</Button>
        </div>
      ) : (
        <>
          {/* Summary cards */}
          <div className="grid grid-cols-3 gap-4 mb-6">
            <div className="rounded-lg border p-4">
              <div className="flex items-center gap-2 text-xs text-muted-foreground">
                <Bell className="h-3.5 w-3.5" />
                {t('reminders.totalReminders')}
              </div>
              <div className="text-xl font-bold">{reminders.length}</div>
            </div>
            <div className="rounded-lg border p-4">
              <div className="flex items-center gap-2 text-xs text-muted-foreground">
                <Clock className="h-3.5 w-3.5" />
                {t('reminders.activeCount')}
              </div>
              <div className="text-xl font-bold text-blue-600">{activeReminders.length}</div>
            </div>
            <div className="rounded-lg border p-4">
              <div className="flex items-center gap-2 text-xs text-muted-foreground">
                <AlertTriangle className="h-3.5 w-3.5" />
                {t('reminders.overdueCount')}
              </div>
              <div className="text-xl font-bold text-red-600">{overdueReminders.length}</div>
            </div>
          </div>

          {/* Filter tabs */}
          <div className="flex items-center gap-1 mb-4">
            <Button
              variant={filterTab === 'all' ? 'default' : 'outline'}
              size="sm"
              className="h-7 text-xs"
              onClick={() => setFilterTab('all')}
            >
              {t('reminders.filterAll')}
            </Button>
            <Button
              variant={filterTab === 'active' ? 'default' : 'outline'}
              size="sm"
              className="h-7 text-xs"
              onClick={() => setFilterTab('active')}
            >
              {t('reminders.filterActive')}
            </Button>
            <Button
              variant={filterTab === 'completed' ? 'default' : 'outline'}
              size="sm"
              className="h-7 text-xs"
              onClick={() => setFilterTab('completed')}
            >
              {t('reminders.filterCompleted')}
            </Button>
          </div>

          {/* Table */}
          <div className="border rounded-lg">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('reminders.titleField')}</TableHead>
                  <TableHead>{t('reminders.type')}</TableHead>
                  <TableHead>{t('reminders.remindAt')}</TableHead>
                  <TableHead>{t('reminders.priority')}</TableHead>
                  <TableHead>{t('reminders.repeatPattern')}</TableHead>
                  <TableHead>{t('reminders.status')}</TableHead>
                  <TableHead className="text-right">{t('common.actions')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredReminders.length === 0 ? (
                  <TableRow>
                    <TableCell
                      colSpan={7}
                      className="text-center py-8 text-muted-foreground text-xs"
                    >
                      {t('reminders.noReminders')}
                    </TableCell>
                  </TableRow>
                ) : (
                  filteredReminders.map((reminder) => {
                    const isOverdue =
                      !reminder.notified && new Date(reminder.remind_at) < now;

                    return (
                      <TableRow key={reminder.id}>
                        {/* Title */}
                        <TableCell className="font-medium">
                          <div>
                            <div>{reminder.title}</div>
                            {reminder.description && (
                              <div className="text-xs text-muted-foreground mt-0.5 line-clamp-1">
                                {reminder.description}
                              </div>
                            )}
                          </div>
                        </TableCell>

                        {/* Type */}
                        <TableCell>
                          <Badge
                            variant="secondary"
                            className={`text-[10px] ${TYPE_COLORS[reminder.reminder_type] || ''}`}
                          >
                            {t(`reminders.type${reminder.reminder_type === 'custom' ? 'Custom' : reminder.reminder_type === 'debt_payment' ? 'DebtPayment' : reminder.reminder_type === 'bill_due' ? 'BillDue' : 'PrepaidLowBalance'}`)}
                          </Badge>
                        </TableCell>

                        {/* Remind At */}
                        <TableCell>
                          <div className="flex flex-col">
                            <span className="text-xs">
                              {formatDateTime(reminder.remind_at)}
                            </span>
                            {isOverdue && (
                              <span className="text-[10px] text-red-500">
                                {t('reminders.overdue')}
                              </span>
                            )}
                          </div>
                        </TableCell>

                        {/* Priority */}
                        <TableCell>
                          <Badge
                            variant="secondary"
                            className={`text-[10px] ${PRIORITY_COLORS[reminder.priority] || ''}`}
                          >
                            {t(`reminders.priority${reminder.priority === 'LOW' ? 'Low' : reminder.priority === 'NORMAL' ? 'Normal' : reminder.priority === 'HIGH' ? 'High' : 'Urgent'}`)}
                          </Badge>
                        </TableCell>

                        {/* Repeat */}
                        <TableCell>
                          <Badge variant="secondary" className="text-[10px]">
                            {reminder.repeat_pattern
                              ? t(`reminders.repeat${reminder.repeat_pattern.charAt(0).toUpperCase() + reminder.repeat_pattern.slice(1)}`)
                              : t('reminders.repeatNone')}
                          </Badge>
                        </TableCell>

                        {/* Status */}
                        <TableCell>
                          {reminder.notified ? (
                            <Badge
                              variant="secondary"
                              className="text-[10px] bg-gray-100 text-gray-600"
                            >
                              {t('reminders.completed')}
                            </Badge>
                          ) : (
                            <Badge
                              variant="secondary"
                              className="text-[10px] bg-emerald-100 text-emerald-700"
                            >
                              {t('reminders.active')}
                            </Badge>
                          )}
                        </TableCell>

                        {/* Actions */}
                        <TableCell className="text-right">
                          {deleteConfirmId === reminder.id ? (
                            <div className="flex justify-end items-center gap-1">
                              <span className="text-xs text-red-600 mr-1">
                                {t('common.confirmDelete')}
                              </span>
                              <Button
                                variant="ghost"
                                size="sm"
                                className="h-6 text-xs text-red-600"
                                onClick={() => deleteMutation.mutate(reminder.id)}
                                disabled={deleteMutation.isPending}
                              >
                                {t('common.confirm')}
                              </Button>
                              <Button
                                variant="ghost"
                                size="sm"
                                className="h-6 text-xs"
                                onClick={() => setDeleteConfirmId(null)}
                              >
                                {t('common.cancel')}
                              </Button>
                            </div>
                          ) : (
                            <div className="flex justify-end gap-1">
                              {!reminder.notified && (
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  className="h-7 text-xs text-emerald-600 hover:text-emerald-700 hover:bg-emerald-50"
                                  onClick={() => completeMutation.mutate(reminder.id)}
                                  disabled={completeMutation.isPending}
                                >
                                  <CheckCircle2 className="h-3 w-3 mr-1" />
                                  {t('reminders.complete')}
                                </Button>
                              )}
                              <Button
                                variant="ghost"
                                size="sm"
                                className="h-7 text-xs"
                                onClick={() => handleEdit(reminder)}
                              >
                                <Pencil className="h-3 w-3 mr-1" />
                                {t('reminders.edit')}
                              </Button>
                              <Button
                                variant="ghost"
                                size="sm"
                                className="h-7 text-xs text-red-600 hover:text-red-700 hover:bg-red-50"
                                onClick={() => setDeleteConfirmId(reminder.id)}
                              >
                                <Trash2 className="h-3 w-3 mr-1" />
                                {t('reminders.delete')}
                              </Button>
                            </div>
                          )}
                        </TableCell>
                      </TableRow>
                    );
                  })
                )}
              </TableBody>
            </Table>
          </div>
        </>
      )}

      {/* Create/Edit Sheet */}
      <Sheet open={showSheet} onOpenChange={setShowSheet}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>
              {editingReminder
                ? t('reminders.edit')
                : t('reminders.create')}
            </SheetTitle>
            <SheetDescription>
              {editingReminder
                ? t('reminders.edit')
                : t('reminders.create')}
            </SheetDescription>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4 py-4 space-y-4">
            {/* Title */}
            <div className="space-y-2">
              <Label>{t('reminders.titleField')}</Label>
              <Input
                value={formTitle}
                onChange={(e) => setFormTitle(e.target.value)}
                placeholder={t('reminders.titlePlaceholder')}
              />
            </div>

            {/* Description */}
            <div className="space-y-2">
              <Label>{t('reminders.description')}</Label>
              <Textarea
                value={formDescription}
                onChange={(e) => setFormDescription(e.target.value)}
                placeholder={t('reminders.descriptionPlaceholder')}
                rows={3}
              />
            </div>

            {/* Type (only when creating) */}
            {!editingReminder && (
              <div className="space-y-2">
                <Label>{t('reminders.type')}</Label>
                <Select value={formType} onValueChange={v => setFormType(v ?? 'custom')}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="custom">{t('reminders.typeCustom')}</SelectItem>
                    <SelectItem value="debt_payment">{t('reminders.typeDebtPayment')}</SelectItem>
                    <SelectItem value="bill_due">{t('reminders.typeBillDue')}</SelectItem>
                    <SelectItem value="prepaid_low_balance">{t('reminders.typePrepaidLowBalance')}</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            )}

            {/* Remind At */}
            <div className="space-y-2">
              <Label>{t('reminders.remindAt')}</Label>
              <Input
                type="datetime-local"
                value={formRemindAt}
                onChange={(e) => setFormRemindAt(e.target.value)}
              />
            </div>

            {/* Repeat Pattern */}
            <div className="space-y-2">
              <Label>{t('reminders.repeatPattern')}</Label>
              <Select value={formRepeat} onValueChange={v => setFormRepeat(v ?? '')}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="">{t('reminders.repeatNone')}</SelectItem>
                  <SelectItem value="daily">{t('reminders.repeatDaily')}</SelectItem>
                  <SelectItem value="weekly">{t('reminders.repeatWeekly')}</SelectItem>
                  <SelectItem value="monthly">{t('reminders.repeatMonthly')}</SelectItem>
                  <SelectItem value="yearly">{t('reminders.repeatYearly')}</SelectItem>
                </SelectContent>
              </Select>
            </div>

            {/* Priority */}
            <div className="space-y-2">
              <Label>{t('reminders.priority')}</Label>
              <Select value={formPriority} onValueChange={v => setFormPriority(v ?? 'NORMAL')}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="LOW">{t('reminders.priorityLow')}</SelectItem>
                  <SelectItem value="NORMAL">{t('reminders.priorityNormal')}</SelectItem>
                  <SelectItem value="HIGH">{t('reminders.priorityHigh')}</SelectItem>
                  <SelectItem value="URGENT">{t('reminders.priorityUrgent')}</SelectItem>
                </SelectContent>
              </Select>
            </div>

            {/* Actions */}
            <div className="flex gap-2 pt-4">
              <Button
                className="flex-1"
                onClick={handleFormSubmit}
                disabled={createMutation.isPending || updateMutation.isPending}
              >
                {createMutation.isPending || updateMutation.isPending
                  ? t('common.saving')
                  : editingReminder
                    ? t('common.save')
                    : t('common.create')}
              </Button>
              <Button
                variant="outline"
                onClick={() => {
                  setShowSheet(false);
                  setEditingReminder(null);
                  resetForm();
                }}
              >
                {t('common.cancel')}
              </Button>
            </div>
          </div>
        </SheetContent>
      </Sheet>
    </div>
  );
}
