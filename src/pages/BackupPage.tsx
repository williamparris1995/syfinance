import { HardDrive, Cloud, Lock, Plus, Trash2, RotateCcw } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Badge } from '../components/ui/badge';
import { Button } from '../components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../components/ui/card';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '../components/ui/table';
import { useBackup } from '../hooks/useBackup';
import { useEncryption } from '../hooks/useEncryption';

function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  const k = 1024;
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  const size = parseFloat((bytes / Math.pow(k, i)).toFixed(1));
  return `${size} ${units[i]}`;
}

export function BackupPage() {
  const { t } = useTranslation();
  const {
    backups,
    isLoadingBackups,
    cloudSettings,
    isLoadingCloudSettings,
    createBackup,
    isCreatingBackup,
    deleteBackup,
  } = useBackup();
  const { enabled: encryptionEnabled } = useEncryption();

  const handleCreateBackup = async () => {
    try {
      await createBackup();
      toast.success(t('backup.createSuccess'));
    } catch (error) {
      toast.error(t('backup.createError'), {
        description: error instanceof Error ? error.message : undefined,
      });
    }
  };

  const handleDeleteBackup = async (filename: string) => {
    try {
      await deleteBackup(filename);
      toast.success(t('backup.deleteSuccess'));
    } catch (error) {
      toast.error(t('backup.deleteError'), {
        description: error instanceof Error ? error.message : undefined,
      });
    }
  };

  const handleRestore = (_filename: string) => {
    // Restore will be implemented in a future task
    toast.info(t('backup.restoreNotImplemented'));
  };

  const handleConfigureCloud = () => {
    // CloudConfigDialog will be built in Task 8
    toast.info(t('backup.cloudConfigNotImplemented'));
  };

  const totalSize = backups.reduce((sum, b) => sum + b.file_size, 0);

  return (
    <div className="p-4 sm:p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-4 sm:mb-6">
        <h1 className="text-2xl font-bold sm:text-3xl">{t('backup.title')}</h1>
        <Button onClick={handleCreateBackup} disabled={isCreatingBackup} className="gap-2">
          <Plus className="h-4 w-4" />
          {t('backup.createBackup')}
        </Button>
      </div>

      {/* Status Overview Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-6">
        {/* Encryption Status */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">
              {t('backup.encryptionStatus')}
            </CardTitle>
            <Lock className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            {encryptionEnabled ? (
              <div className="flex items-center gap-2">
                <span className="text-2xl font-bold">{t('backup.aes256')}</span>
                <Badge variant="outline">{t('backup.encrypted')}</Badge>
              </div>
            ) : (
              <span className="text-2xl font-bold">{t('backup.notEncrypted')}</span>
            )}
          </CardContent>
        </Card>

        {/* Cloud Connection */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">
              {t('backup.cloudConnection')}
            </CardTitle>
            <Cloud className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            {isLoadingCloudSettings ? (
              <span className="text-muted-foreground">{t('backup.loading')}</span>
            ) : cloudSettings?.enabled ? (
              <div className="flex items-center gap-2">
                <span className="text-2xl font-bold">{t('backup.connected')}</span>
                <Badge variant="outline">{cloudSettings.provider}</Badge>
              </div>
            ) : (
              <span className="text-2xl font-bold">{t('backup.notConfigured')}</span>
            )}
          </CardContent>
        </Card>

        {/* Backup Count */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">
              {t('backup.backupCount')}
            </CardTitle>
            <HardDrive className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <span className="text-2xl font-bold">
              {t('backup.backupSummary', {
                count: backups.length,
                size: formatFileSize(totalSize),
              })}
            </span>
          </CardContent>
        </Card>
      </div>

      {/* Cloud Configuration Section */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>{t('backup.cloudConfig')}</CardTitle>
          <CardDescription>{t('backup.cloudConfigDesc')}</CardDescription>
        </CardHeader>
        <CardContent>
          {isLoadingCloudSettings ? (
            <div className="flex items-center justify-center py-4">
              <span className="text-muted-foreground">{t('backup.loading')}</span>
            </div>
          ) : cloudSettings?.enabled ? (
            <div className="flex items-center justify-between">
              <div>
                <p className="font-medium">{cloudSettings.provider}</p>
                {cloudSettings.server_url && (
                  <p className="text-sm text-muted-foreground">{cloudSettings.server_url}</p>
                )}
                {cloudSettings.remote_path && (
                  <p className="text-sm text-muted-foreground">{cloudSettings.remote_path}</p>
                )}
              </div>
              <Button variant="outline" onClick={handleConfigureCloud}>
                {t('backup.configure')}
              </Button>
            </div>
          ) : (
            <div className="flex items-center justify-between">
              <p className="text-muted-foreground">{t('backup.noCloudConfigured')}</p>
              <Button variant="outline" onClick={handleConfigureCloud}>
                {t('backup.configure')}
              </Button>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Backup History */}
      <Card>
        <CardHeader>
          <CardTitle>{t('backup.backupHistory')}</CardTitle>
          <CardDescription>{t('backup.backupHistoryDesc')}</CardDescription>
        </CardHeader>
        <CardContent>
          {isLoadingBackups ? (
            <div className="flex items-center justify-center py-12">
              <span className="text-muted-foreground">{t('backup.loadingBackups')}</span>
            </div>
          ) : backups.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-center">
              <HardDrive className="h-12 w-12 text-muted-foreground mb-4" />
              <p className="text-muted-foreground mb-2">{t('backup.noBackups')}</p>
              <p className="text-sm text-muted-foreground">{t('backup.noBackupsDesc')}</p>
            </div>
          ) : (
            <div className="border rounded-lg">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>{t('backup.filename')}</TableHead>
                    <TableHead>{t('backup.size')}</TableHead>
                    <TableHead>{t('backup.date')}</TableHead>
                    <TableHead>{t('backup.source')}</TableHead>
                    <TableHead className="w-[150px]">{t('common.actions')}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {backups.map((backup) => (
                    <TableRow key={backup.filename}>
                      <TableCell className="font-medium font-mono text-sm">
                        {backup.filename}
                      </TableCell>
                      <TableCell>{formatFileSize(backup.file_size)}</TableCell>
                      <TableCell className="text-sm text-muted-foreground">
                        {new Date(backup.created_at).toLocaleString('en-US', {
                          year: 'numeric',
                          month: 'short',
                          day: 'numeric',
                          hour: '2-digit',
                          minute: '2-digit',
                        })}
                      </TableCell>
                      <TableCell>
                        {backup.on_cloud ? (
                          <Badge variant="outline" className="gap-1">
                            <Cloud className="h-3 w-3" />
                            {t('backup.cloud')}
                          </Badge>
                        ) : (
                          <Badge variant="secondary" className="gap-1">
                            <HardDrive className="h-3 w-3" />
                            {t('backup.local')}
                          </Badge>
                        )}
                      </TableCell>
                      <TableCell>
                        <div className="flex gap-1">
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => handleRestore(backup.filename)}
                            className="gap-1"
                          >
                            <RotateCcw className="h-3 w-3" />
                            {t('backup.restore')}
                          </Button>
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => handleDeleteBackup(backup.filename)}
                            className="gap-1"
                          >
                            <Trash2 className="h-3 w-3" />
                            {t('backup.delete')}
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
