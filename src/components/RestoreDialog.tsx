import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { AlertTriangle, ArrowDown, ArrowRight, ArrowUp, RotateCcw, ShieldCheck } from 'lucide-react';
import { Button } from './ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from './ui/dialog';
import { Badge } from './ui/badge';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from './ui/table';
import { getBackupDiff } from '@/lib/tauri/backup';
import type { DiffSummary, TableDiff } from '@/lib/tauri/backup';
import { Separator } from './ui/separator';

type ConflictStrategy = 'keep_newer' | 'use_backup' | 'keep_local';

const TABLE_KEYS = [
  { key: 'accounts', labelKey: 'backup.tableAccounts' },
  { key: 'transactions', labelKey: 'backup.tableTransactions' },
  { key: 'debts', labelKey: 'backup.tableDebts' },
  { key: 'goals', labelKey: 'backup.tableGoals' },
  { key: 'budgets', labelKey: 'backup.tableBudgets' },
  { key: 'tags', labelKey: 'backup.tableTags' },
] as const;

interface RestoreDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  filename: string;
}

export function RestoreDialog({ open, onOpenChange, filename }: RestoreDialogProps) {
  const { t } = useTranslation();
  const [diff, setDiff] = useState<DiffSummary | null>(null);
  const [isLoadingDiff, setIsLoadingDiff] = useState(false);
  const [strategy, setStrategy] = useState<ConflictStrategy>('keep_newer');
  const [isRestoring, setIsRestoring] = useState(false);

  const loadDiff = async () => {
    if (diff) return;
    setIsLoadingDiff(true);
    try {
      const result = await getBackupDiff(filename);
      setDiff(result);
    } catch (error) {
      toast.error(t('backup.diffError'), {
        description: error instanceof Error ? error.message : undefined,
      });
    } finally {
      setIsLoadingDiff(false);
    }
  };

  const handleOpenChange = (nextOpen: boolean) => {
    if (!nextOpen) {
      setDiff(null);
      setStrategy('keep_newer');
    }
    onOpenChange(nextOpen);
  };

  const handleRestore = async () => {
    setIsRestoring(true);
    try {
      // Restore not yet implemented on backend — placeholder
      toast.info(t('backup.restoreNotImplemented'));
    } finally {
      setIsRestoring(false);
      handleOpenChange(false);
    }
  };

  const totalChanges = diff
    ? TABLE_KEYS.reduce(
        (sum, { key }) => {
          const td = diff[key];
          return {
            added: sum.added + td.added,
            removed: sum.removed + td.removed,
            modified: sum.modified + td.modified,
          };
        },
        { added: 0, removed: 0, modified: 0 },
      )
    : null;

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="sm:max-w-2xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{t('backup.restoreDialogTitle')}</DialogTitle>
          <DialogDescription>
            {t('backup.restoreDialogDesc')}
          </DialogDescription>
        </DialogHeader>

        {/* Backup file info */}
        <div className="rounded-lg border bg-muted/30 p-3 space-y-1">
          <p className="text-sm font-medium font-mono">{filename}</p>
          <div className="flex items-center gap-2">
            <ShieldCheck className="h-4 w-4 text-green-600" />
            <span className="text-sm text-muted-foreground">
              {t('backup.decryptRequired')}
            </span>
          </div>
        </div>

        {/* Load diff or show results */}
        {!diff && !isLoadingDiff && (
          <div className="flex justify-center py-4">
            <Button variant="outline" onClick={loadDiff}>
              <ArrowRight className="h-4 w-4 mr-2" />
              {t('backup.loadDiff')}
            </Button>
          </div>
        )}

        {isLoadingDiff && (
          <div className="flex items-center justify-center py-8">
            <RotateCcw className="h-5 w-5 animate-spin text-muted-foreground" />
            <span className="ml-2 text-muted-foreground">{t('backup.comparingData')}</span>
          </div>
        )}

        {diff && totalChanges && (
          <div className="space-y-4">
            {/* Diff summary */}
            <div className="grid grid-cols-3 gap-3">
              <div className="rounded-lg border p-3 text-center">
                <ArrowUp className="h-4 w-4 mx-auto mb-1 text-green-600" />
                <p className="text-2xl font-bold">{totalChanges.added}</p>
                <p className="text-xs text-muted-foreground">{t('backup.added')}</p>
              </div>
              <div className="rounded-lg border p-3 text-center">
                <ArrowDown className="h-4 w-4 mx-auto mb-1 text-red-600" />
                <p className="text-2xl font-bold">{totalChanges.removed}</p>
                <p className="text-xs text-muted-foreground">{t('backup.removed')}</p>
              </div>
              <div className="rounded-lg border p-3 text-center">
                <ArrowRight className="h-4 w-4 mx-auto mb-1 text-amber-600" />
                <p className="text-2xl font-bold">{totalChanges.modified}</p>
                <p className="text-xs text-muted-foreground">{t('backup.modified')}</p>
              </div>
            </div>

            {/* Per-table details */}
            <div className="border rounded-lg">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>{t('backup.table')}</TableHead>
                    <TableHead className="text-center">{t('backup.local')}</TableHead>
                    <TableHead className="text-center">{t('backup.backup')}</TableHead>
                    <TableHead className="text-center">
                      <span className="inline-flex items-center gap-1">
                        <ArrowUp className="h-3 w-3 text-green-600" />
                        {t('backup.added')}
                      </span>
                    </TableHead>
                    <TableHead className="text-center">
                      <span className="inline-flex items-center gap-1">
                        <ArrowDown className="h-3 w-3 text-red-600" />
                        {t('backup.removed')}
                      </span>
                    </TableHead>
                    <TableHead className="text-center">
                      <span className="inline-flex items-center gap-1">
                        <ArrowRight className="h-3 w-3 text-amber-600" />
                        {t('backup.modified')}
                      </span>
                    </TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {TABLE_KEYS.map(({ key, labelKey }) => {
                    const td: TableDiff = diff[key];
                    return (
                      <TableRow key={key}>
                        <TableCell className="font-medium">{t(labelKey)}</TableCell>
                        <TableCell className="text-center">{td.local_count}</TableCell>
                        <TableCell className="text-center">{td.backup_count}</TableCell>
                        <TableCell className="text-center">
                          {td.added > 0 ? (
                            <Badge variant="outline" className="text-green-600">
                              {td.added}
                            </Badge>
                          ) : (
                            <span className="text-muted-foreground">0</span>
                          )}
                        </TableCell>
                        <TableCell className="text-center">
                          {td.removed > 0 ? (
                            <Badge variant="outline" className="text-red-600">
                              {td.removed}
                            </Badge>
                          ) : (
                            <span className="text-muted-foreground">0</span>
                          )}
                        </TableCell>
                        <TableCell className="text-center">
                          {td.modified > 0 ? (
                            <Badge variant="outline" className="text-amber-600">
                              {td.modified}
                            </Badge>
                          ) : (
                            <span className="text-muted-foreground">0</span>
                          )}
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </div>

            {/* No changes case */}
            {totalChanges.added === 0 &&
              totalChanges.removed === 0 &&
              totalChanges.modified === 0 && (
                <div className="flex items-center justify-center py-4">
                  <ShieldCheck className="h-5 w-5 text-green-600 mr-2" />
                  <span className="text-muted-foreground">{t('backup.noChanges')}</span>
                </div>
              )}

            <Separator />

            {/* Conflict resolution */}
            <div className="space-y-3">
              <p className="text-sm font-medium">{t('backup.conflictResolution')}</p>
              <div className="space-y-2">
                {([
                  ['keep_newer', 'backup.conflictKeepNewer'],
                  ['use_backup', 'backup.conflictUseBackup'],
                  ['keep_local', 'backup.conflictKeepLocal'],
                ] as const).map(([value, labelKey]) => (
                  <Button
                    key={value}
                    type="button"
                    variant={strategy === value ? 'default' : 'outline'}
                    size="sm"
                    onClick={() => setStrategy(value as ConflictStrategy)}
                    className="mr-2"
                  >
                    {t(labelKey)}
                  </Button>
                ))}
              </div>
              <p className="text-xs text-muted-foreground">
                {t('backup.conflictDesc')}
              </p>
            </div>

            {/* Safety warning */}
            <div className="flex items-start gap-3 rounded-lg border border-amber-200 bg-amber-50 dark:bg-amber-950/20 p-3">
              <AlertTriangle className="h-5 w-5 text-amber-600 mt-0.5 shrink-0" />
              <div className="space-y-1">
                <p className="text-sm font-medium text-amber-800 dark:text-amber-200">
                  {t('backup.restoreWarning')}
                </p>
                <p className="text-xs text-amber-700 dark:text-amber-300">
                  {t('backup.restoreWarningDesc')}
                </p>
              </div>
            </div>
          </div>
        )}

        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => handleOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          {diff && (
            <Button type="button" onClick={handleRestore} disabled={isRestoring}>
              <RotateCcw className="h-4 w-4 mr-2" />
              {isRestoring ? t('backup.restoring') : t('backup.startRestore')}
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
