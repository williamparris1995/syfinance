import { useTranslation } from 'react-i18next';
import { ArrowRight } from 'lucide-react';

import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';

export interface ChangeItem {
  field: string; // i18n key for the field name
  oldValue: string; // formatted old value
  newValue: string; // formatted new value
  significant?: boolean; // true for destructive/high-impact changes like balance
}

interface AccountChangesDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  changes: ChangeItem[];
  onConfirm: () => void;
  isLoading?: boolean;
}

export function AccountChangesDialog({
  open,
  onOpenChange,
  changes,
  onConfirm,
  isLoading,
}: AccountChangesDialogProps) {
  const { t } = useTranslation();

  if (changes.length === 0) return null;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent showCloseButton={false} className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t('accounts.confirmChanges')}</DialogTitle>
          <DialogDescription>{t('accounts.confirmChangesDesc')}</DialogDescription>
        </DialogHeader>

        <div className="space-y-2 max-h-60 overflow-y-auto py-2">
          {changes.map((change) => (
            <div
              key={change.field}
              className={`rounded-lg border p-3 text-sm ${
                change.significant
                  ? 'border-amber-300 bg-amber-50 dark:border-amber-700 dark:bg-amber-950/30'
                  : 'border-border'
              }`}
            >
              <div className="text-xs font-medium text-muted-foreground mb-1">
                {t(change.field)}
              </div>
              <div className="flex items-center gap-2">
                <span
                  className={`flex-1 truncate ${
                    change.significant
                      ? 'text-amber-700 dark:text-amber-400 line-through'
                      : 'text-muted-foreground line-through'
                  }`}
                >
                  {change.oldValue != null && change.oldValue !== '' ? change.oldValue : '—'}
                </span>
                <ArrowRight className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
                <span
                  className={`flex-1 truncate font-medium ${
                    change.significant
                      ? 'text-amber-700 dark:text-amber-400'
                      : 'text-foreground'
                  }`}
                >
                  {change.newValue != null && change.newValue !== '' ? change.newValue : '—'}
                </span>
              </div>
            </div>
          ))}
        </div>

        <DialogFooter>
          <DialogClose render={<Button variant="outline" />} disabled={isLoading}>
            {t('common.cancel')}
          </DialogClose>
          <Button onClick={onConfirm} disabled={isLoading}>
            {isLoading ? t('common.saving') : t('common.save')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
