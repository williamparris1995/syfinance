import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { AlertTriangle } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import type { SyncConflictItem } from '@/lib/tauri/cloudSync';

interface SyncConflictDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  conflicts: SyncConflictItem[];
  onResolve: (tableName: string, recordId: string, resolution: string) => void;
  isResolving: boolean;
}

function ConflictValuePreview({ data }: { data: Record<string, unknown> }) {
  const name = String(data.name ?? data.description ?? data.counterparty ?? '');
  const amount = data.amount != null ? String(data.amount) : '';
  const balance = data.balance != null ? String(data.balance) : '';

  const parts = [name, amount, balance].filter(Boolean);
  if (parts.length === 0) {
    return <span className="text-muted-foreground text-xs">—</span>;
  }

  return (
    <span className="text-xs font-mono truncate block max-w-[200px]" title={parts.join(' | ')}>
      {parts.join(' | ')}
    </span>
  );
}

function formatTimestamp(ts: string | null | undefined): string {
  if (!ts) return '—';
  return ts;
}

function TableNameBadge({ tableName }: { tableName: string }) {
  const { t } = useTranslation();
  const label = t(`cloudSync.table_${tableName}`, tableName);
  return <Badge variant="secondary">{label}</Badge>;
}

export function SyncConflictDialog({
  open,
  onOpenChange,
  conflicts,
  onResolve,
  isResolving,
}: SyncConflictDialogProps) {
  const { t } = useTranslation();
  const [resolutions, setResolutions] = useState<Record<string, string>>({});

  const getResolutionKey = (c: SyncConflictItem) =>
    `${c.table_name}::${c.record_id}`;

  const handleResolutionChange = (
    conflict: SyncConflictItem,
    resolution: string,
  ) => {
    setResolutions((prev) => ({
      ...prev,
      [getResolutionKey(conflict)]: resolution,
    }));
  };

  const handleResolveAll = () => {
    for (const conflict of conflicts) {
      const key = getResolutionKey(conflict);
      const resolution = resolutions[key] ?? 'keep_newer';
      onResolve(conflict.table_name, conflict.record_id, resolution);
    }
  };

  const handleOpenChange = (nextOpen: boolean) => {
    if (!nextOpen) {
      setResolutions({});
    }
    onOpenChange(nextOpen);
  };

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="max-w-4xl max-h-[80vh]">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <AlertTriangle className="h-5 w-5 text-yellow-500" />
            {t('cloudSync.conflictTitle')}
          </DialogTitle>
          <DialogDescription>
            {t('cloudSync.conflictDescription', { count: conflicts.length })}
          </DialogDescription>
        </DialogHeader>

        <div className="max-h-[50vh] overflow-y-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('cloudSync.conflictTable')}</TableHead>
                <TableHead>{t('cloudSync.conflictLocal')}</TableHead>
                <TableHead>{t('cloudSync.conflictRemote')}</TableHead>
                <TableHead>{t('cloudSync.conflictResolution')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {conflicts.map((conflict) => {
                const key = getResolutionKey(conflict);
                return (
                  <TableRow key={key}>
                    <TableCell>
                      <div className="space-y-1">
                        <TableNameBadge tableName={conflict.table_name} />
                        <p className="text-xs text-muted-foreground font-mono">
                          {conflict.record_id.slice(0, 8)}...
                        </p>
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="space-y-1">
                        <ConflictValuePreview data={conflict.local_data} />
                        <p className="text-xs text-muted-foreground">
                          {formatTimestamp(conflict.local_updated_at)}
                        </p>
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="space-y-1">
                        <ConflictValuePreview data={conflict.remote_data} />
                        <p className="text-xs text-muted-foreground">
                          {formatTimestamp(conflict.remote_updated_at)}
                        </p>
                      </div>
                    </TableCell>
                    <TableCell>
                      <Select
                        value={resolutions[key] ?? 'keep_newer'}
                        onValueChange={(value) => {
                          if (value) handleResolutionChange(conflict, value);
                        }}
                      >
                        <SelectTrigger className="w-[160px]">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="keep_newer">
                            {t('cloudSync.keepNewer')}
                          </SelectItem>
                          <SelectItem value="keep_local">
                            {t('cloudSync.keepLocal')}
                          </SelectItem>
                          <SelectItem value="use_remote">
                            {t('cloudSync.useRemote')}
                          </SelectItem>
                        </SelectContent>
                      </Select>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </div>

        <DialogFooter className="gap-2">
          <Button
            variant="outline"
            onClick={() => handleOpenChange(false)}
            disabled={isResolving}
          >
            {t('common.cancel')}
          </Button>
          <Button onClick={handleResolveAll} disabled={isResolving}>
            {isResolving
              ? t('cloudSync.resolving')
              : t('cloudSync.resolveAll')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
