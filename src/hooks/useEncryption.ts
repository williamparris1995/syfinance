import { useState, useCallback } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import {
  getEncryptionStatus,
  setupEncryption,
  unlockEncryption,
  unlockEncryptionKeychain,
  lockEncryption,
  disableEncryption,
  type EncryptionStatus,
} from '../lib/tauri/encryption';

export function useEncryption() {
  const queryClient = useQueryClient();
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [disablePassword, setDisablePassword] = useState('');

  const { data: status, isLoading } = useQuery<EncryptionStatus>({
    queryKey: ['encryption-status'],
    queryFn: getEncryptionStatus,
  });

  const handleSetup = useCallback(async () => {
    if (password.length < 8) throw new Error('Password must be at least 8 characters');
    if (password !== confirmPassword) throw new Error('Passwords do not match');
    await setupEncryption(password);
    setPassword('');
    setConfirmPassword('');
    queryClient.invalidateQueries({ queryKey: ['encryption-status'] });
  }, [password, confirmPassword, queryClient]);

  const handleUnlock = useCallback(async () => {
    if (!password) throw new Error('Password is required');
    await unlockEncryption(password);
    setPassword('');
    queryClient.invalidateQueries({ queryKey: ['encryption-status'] });
  }, [password, queryClient]);

  const handleUnlockKeychain = useCallback(async () => {
    await unlockEncryptionKeychain();
    queryClient.invalidateQueries({ queryKey: ['encryption-status'] });
  }, [queryClient]);

  const handleLock = useCallback(async () => {
    await lockEncryption();
    queryClient.invalidateQueries({ queryKey: ['encryption-status'] });
  }, [queryClient]);

  const handleDisable = useCallback(async () => {
    if (!disablePassword) throw new Error('Password is required');
    await disableEncryption(disablePassword);
    setDisablePassword('');
    queryClient.invalidateQueries({ queryKey: ['encryption-status'] });
  }, [disablePassword, queryClient]);

  return {
    enabled: status?.enabled ?? false,
    unlocked: status?.unlocked ?? false,
    isLoading,
    password,
    setPassword,
    confirmPassword,
    setConfirmPassword,
    disablePassword,
    setDisablePassword,
    handleSetup,
    handleUnlock,
    handleUnlockKeychain,
    handleLock,
    handleDisable,
  };
}
