import { useState, useEffect, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from './ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from './ui/dialog';
import { Input } from './ui/input';
import { Label } from './ui/label';
import { Badge } from './ui/badge';
import { useBackup } from '@/hooks/useBackup';
import type { CloudSettings } from '@/lib/tauri/backup';

const PROVIDER_ICONS: Record<string, string> = {
  webdav: '☁️',
  nextcloud: '🏦',
  synology: '💾',
  jianguoyun: '🥜',
  box: '📦',
  dropbox: '📦',
  google_drive: '🔺',
  onedrive: '🔷',
};

const WEBDAV_PROVIDERS = new Set(['webdav', 'nextcloud', 'synology', 'jianguoyun', 'box']);
const OAUTH_PROVIDERS = new Set(['dropbox', 'google_drive', 'onedrive']);

interface CloudConfigDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function CloudConfigDialog({ open, onOpenChange }: CloudConfigDialogProps) {
  const { t } = useTranslation();
  const {
    cloudPresets,
    cloudSettings,
    saveCloudSettings,
    isSavingCloudSettings,
    testConnection,
    isTestingConnection,
  } = useBackup();

  const [selectedProvider, setSelectedProvider] = useState('');
  const [serverUrl, setServerUrl] = useState('');
  const [port, setPort] = useState('');
  const [useHttps, setUseHttps] = useState(true);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [remotePath, setRemotePath] = useState('/finance-app/backups/');
  const [autoUpload, setAutoUpload] = useState('after_each');
  const [connectionStatus, setConnectionStatus] = useState<'idle' | 'success' | 'error'>('idle');

  const isWebDav = WEBDAV_PROVIDERS.has(selectedProvider);
  const isOAuth = OAUTH_PROVIDERS.has(selectedProvider);

  const resetForm = useCallback(() => {
    setSelectedProvider('');
    setServerUrl('');
    setPort('');
    setUseHttps(true);
    setUsername('');
    setPassword('');
    setRemotePath('/finance-app/backups/');
    setAutoUpload('after_each');
    setConnectionStatus('idle');
  }, []);

  // Populate form from existing cloud settings when dialog opens
  useEffect(() => {
    if (open && cloudSettings) {
      setSelectedProvider(cloudSettings.provider || '');
      setServerUrl(cloudSettings.server_url || '');
      setPort(cloudSettings.port?.toString() || '');
      setUseHttps(cloudSettings.server_url?.startsWith('https') ?? true);
      setUsername(cloudSettings.username || '');
      setPassword(cloudSettings.password || '');
      setRemotePath(cloudSettings.remote_path || '/finance-app/backups/');
      setAutoUpload(cloudSettings.auto_upload || 'after_each');
      setConnectionStatus('idle');
    } else if (open && !cloudSettings) {
      resetForm();
    }
  }, [open, cloudSettings, resetForm]);

  // Auto-fill from preset when provider changes
  useEffect(() => {
    if (!selectedProvider) return;
    const preset = cloudPresets.find((p) => p.id === selectedProvider);
    if (preset) {
      setServerUrl(preset.default_server || '');
      setPort(preset.default_port?.toString() || '');
      setUseHttps(preset.use_https);
    }
  }, [selectedProvider, cloudPresets]);

  const buildSettings = (): CloudSettings => ({
    provider: selectedProvider,
    server_url: serverUrl,
    port: port ? parseInt(port, 10) : undefined,
    username,
    password,
    remote_path: remotePath,
    auto_upload: autoUpload,
    enabled: true,
  });

  const handleTestConnection = async () => {
    setConnectionStatus('idle');
    try {
      await testConnection(buildSettings());
      setConnectionStatus('success');
      toast.success(t('backup.connectionSuccess'));
    } catch (error) {
      setConnectionStatus('error');
      toast.error(t('backup.connectionError'), {
        description: error instanceof Error ? error.message : undefined,
      });
    }
  };

  const handleSave = async () => {
    try {
      await saveCloudSettings(buildSettings());
      toast.success(t('backup.saveSuccess'));
      onOpenChange(false);
    } catch (error) {
      toast.error(t('backup.saveError'), {
        description: error instanceof Error ? error.message : undefined,
      });
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-2xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{t('backup.cloudDialogTitle')}</DialogTitle>
          <DialogDescription>{t('backup.cloudDialogDesc')}</DialogDescription>
        </DialogHeader>

        <div className="space-y-6">
          {/* Provider Selector */}
          <div className="space-y-2">
            <Label className="text-xs uppercase tracking-wider text-muted-foreground">
              {t('backup.selectProvider')}
            </Label>
            <div className="grid grid-cols-4 gap-2">
              {cloudPresets.map((preset) => (
                <button
                  key={preset.id}
                  type="button"
                  onClick={() => setSelectedProvider(preset.id)}
                  className={`flex flex-col items-center gap-1 rounded-lg border p-3 text-center transition-colors hover:bg-accent ${
                    selectedProvider === preset.id
                      ? 'border-blue-500 bg-blue-50 ring-2 ring-blue-500/20 dark:bg-blue-950/30'
                      : 'border-border'
                  }`}
                >
                  <span className="text-2xl">{PROVIDER_ICONS[preset.id] ?? '📦'}</span>
                  <span className="text-xs font-medium truncate w-full">{preset.name}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Configuration Form */}
          {selectedProvider && (
            <div className="space-y-4">
              {isWebDav && (
                <>
                  {/* Server URL */}
                  <div className="space-y-1.5">
                    <Label className="text-xs uppercase tracking-wider text-muted-foreground">
                      {t('backup.serverUrl')}
                    </Label>
                    <Input
                      value={serverUrl}
                      onChange={(e) => setServerUrl(e.target.value)}
                      placeholder={t('backup.serverUrlPlaceholder')}
                    />
                  </div>

                  {/* Port + HTTPS toggle */}
                  <div className="grid grid-cols-2 gap-3">
                    <div className="space-y-1.5">
                      <Label className="text-xs uppercase tracking-wider text-muted-foreground">
                        {t('backup.port')}
                      </Label>
                      <Input
                        value={port}
                        onChange={(e) => setPort(e.target.value)}
                        placeholder="443"
                        type="number"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <Label className="text-xs uppercase tracking-wider text-muted-foreground">
                        {t('backup.useHttps')}
                      </Label>
                      <div className="flex items-center h-8">
                        <Button
                          type="button"
                          variant={useHttps ? 'default' : 'outline'}
                          size="sm"
                          onClick={() => setUseHttps(true)}
                        >
                          HTTPS
                        </Button>
                        <Button
                          type="button"
                          variant={!useHttps ? 'default' : 'outline'}
                          size="sm"
                          onClick={() => setUseHttps(false)}
                          className="ml-1"
                        >
                          HTTP
                        </Button>
                      </div>
                    </div>
                  </div>

                  {/* Username */}
                  <div className="space-y-1.5">
                    <Label className="text-xs uppercase tracking-wider text-muted-foreground">
                      {t('backup.username')}
                    </Label>
                    <Input
                      value={username}
                      onChange={(e) => setUsername(e.target.value)}
                      placeholder={t('backup.usernamePlaceholder')}
                    />
                  </div>

                  {/* Password */}
                  <div className="space-y-1.5">
                    <Label className="text-xs uppercase tracking-wider text-muted-foreground">
                      {t('backup.password')}
                    </Label>
                    <Input
                      type="password"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder={t('backup.passwordPlaceholder')}
                    />
                  </div>
                </>
              )}

              {isOAuth && (
                <div className="rounded-lg border bg-muted/30 p-4 space-y-3">
                  <p className="text-sm text-muted-foreground">{t('backup.oauthInfo')}</p>
                  <Button type="button" variant="outline" className="w-full">
                    {t('backup.authorize')}
                  </Button>
                  <p className="text-xs text-muted-foreground">{t('backup.authorizeDesc')}</p>
                </div>
              )}

              {/* Remote Path */}
              <div className="space-y-1.5">
                <Label className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('backup.remotePath')}
                </Label>
                <Input
                  value={remotePath}
                  onChange={(e) => setRemotePath(e.target.value)}
                  placeholder={t('backup.remotePathPlaceholder')}
                />
              </div>

              {/* Upload Frequency */}
              <div className="space-y-2">
                <Label className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('backup.uploadFrequency')}
                </Label>
                <div className="flex gap-2">
                  {(['after_each', 'daily', 'manual'] as const).map((option) => (
                    <Button
                      key={option}
                      type="button"
                      variant={autoUpload === option ? 'default' : 'outline'}
                      size="sm"
                      onClick={() => setAutoUpload(option)}
                    >
                      {t(`backup.${option === 'after_each' ? 'afterEachBackup' : option === 'daily' ? 'daily' : 'manualOnly'}`)}
                    </Button>
                  ))}
                </div>
              </div>

              {/* Connection Status */}
              {connectionStatus !== 'idle' && (
                <div className="flex items-center gap-2">
                  <Badge variant={connectionStatus === 'success' ? 'default' : 'destructive'}>
                    {connectionStatus === 'success'
                      ? t('backup.connectionSuccess')
                      : t('backup.connectionError')}
                  </Badge>
                </div>
              )}
            </div>
          )}
        </div>

        <DialogFooter>
          {selectedProvider && (
            <Button
              type="button"
              variant="outline"
              onClick={handleTestConnection}
              disabled={isTestingConnection}
            >
              {isTestingConnection ? t('backup.testing') : t('backup.testConnection')}
            </Button>
          )}
          <Button
            type="button"
            variant="outline"
            onClick={() => onOpenChange(false)}
          >
            {t('common.cancel')}
          </Button>
          <Button
            type="button"
            onClick={handleSave}
            disabled={!selectedProvider || isSavingCloudSettings}
          >
            {isSavingCloudSettings ? t('backup.saving') : t('common.save')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
